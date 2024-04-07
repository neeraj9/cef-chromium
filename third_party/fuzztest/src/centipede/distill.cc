// Copyright 2023 The Centipede Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "./centipede/distill.h"

#include <algorithm>
#include <cstdlib>
#include <functional>
#include <numeric>
#include <string>
#include <thread>  // NOLINT(build/c++11)
#include <utility>
#include <vector>

#include "absl/log/check.h"
#include "absl/log/log.h"
#include "absl/strings/str_cat.h"
#include "absl/time/time.h"
#include "./centipede/blob_file.h"
#include "./centipede/defs.h"
#include "./centipede/environment.h"
#include "./centipede/feature.h"
#include "./centipede/feature_set.h"
#include "./centipede/logging.h"
#include "./centipede/rusage_profiler.h"
#include "./centipede/shard_reader.h"
#include "./centipede/thread_pool.h"
#include "./centipede/util.h"
#include "./centipede/workdir.h"

namespace centipede {

using CorpusElt = std::pair<ByteArray, FeatureVec>;
using CorpusEltVec = std::vector<CorpusElt>;

namespace {

// The maximum number of threads reading input shards concurrently. This is
// mainly to prevent I/O congestion.
// TODO(ussuri): Bump up significantly when RSS-gated mutexing is in.
inline constexpr size_t kMaxReadingThreads = 1;

}  // namespace

void DistillTask(const Environment &env,
                 const std::vector<size_t> &shard_indices) {
  const std::string log_line =
      absl::StrCat("DISTILL[S.", env.my_shard_index, "]: ");

  const WorkDir wd{env};
  const auto corpus_path = wd.DistilledCorpusFiles().MyShardPath();
  const auto features_path = wd.DistilledFeaturesFiles().MyShardPath();
  LOG(INFO) << log_line << VV(env.total_shards) << VV(corpus_path)
            << VV(features_path);

  const auto corpus_writer = DefaultBlobFileWriterFactory(env.riegeli);
  const auto features_writer = DefaultBlobFileWriterFactory(env.riegeli);
  // NOTE: Overwrite distilled corpus and features files -- do not append.
  CHECK_OK(corpus_writer->Open(corpus_path, "w"));
  CHECK_OK(features_writer->Open(features_path, "w"));

  const size_t num_shards = shard_indices.size();
  size_t num_read_shards = 0;
  size_t num_read_elements = 0;
  size_t num_distilled_elements = 0;
  const auto corpus_files = wd.CorpusFiles();
  const auto features_files = wd.FeaturesFiles();

  std::vector<CorpusEltVec> elts_per_shard(num_shards);
  FeatureSet feature_set(/*frequency_threshold=*/1,
                         env.MakeDomainDiscardMask());

  // Read the shards in parallel.
  {
    ThreadPool threads{std::min<int>(kMaxReadingThreads, num_shards)};

    for (size_t shard_idx : shard_indices) {
      CHECK_LT(shard_idx, num_shards);
      threads.Schedule([corpus_path = corpus_files.ShardPath(shard_idx),
                        features_path = features_files.ShardPath(shard_idx),
                        &shard_elts = elts_per_shard[shard_idx], shard_idx,
                        &log_line] {
        VLOG(2) << log_line << "reading shard " << shard_idx << " from:\n"
                << VV(corpus_path) << "\n"
                << VV(features_path);
        // Read elements from the current shard.
        ReadShard(corpus_path, features_path,
                  [&shard_elts](const ByteArray &input, FeatureVec &features) {
                    shard_elts.emplace_back(input, std::move(features));
                  });
        // Reverse the order of inputs read from the current shard.
        // The intuition is as follows:
        // * If the shard is the result of fuzzing with Centipede, the inputs
        // that are closer to the end are more interesting, so we start there.
        // * If the shard resulted from somethening else, the reverse order is
        // not any better or worse than any other order.
        std::reverse(shard_elts.begin(), shard_elts.end());
      });
    }
  }  // The reading threads join here.

  for (size_t shard_idx : shard_indices) {
    // Iterate the elts, add those that have new features.
    // This is a simple linear greedy set cover algorithm.
    auto &shard_elts = elts_per_shard[shard_idx];
    VLOG(1) << log_line << "appending elements from input shard " << shard_idx
            << " to output shard";
    for (auto &[input, features] : shard_elts) {
      ++num_read_elements;
      feature_set.PruneDiscardedDomains(features);
      if (!feature_set.HasUnseenFeatures(features)) continue;
      feature_set.IncrementFrequencies(features);
      // Append to the distilled corpus and features files.
      CHECK_OK(corpus_writer->Write(input));
      CHECK_OK(features_writer->Write(PackFeaturesAndHash(input, features)));
      input.clear();
      features.clear();
      ++num_distilled_elements;
      VLOG_EVERY_N(10, 1000) << VV(num_distilled_elements);
    }
    shard_elts.clear();
    ++num_read_shards;
    LOG(INFO) << log_line << feature_set << " src_shards: " << num_read_shards
              << "/" << num_shards << " src_elts: " << num_read_elements
              << " dist_elts: " << num_distilled_elements;
  }
}

int Distill(const Environment &env) {
  RPROF_THIS_FUNCTION_WITH_TIMELAPSE(                                 //
      /*enable=*/VLOG_IS_ON(1),                                       //
      /*timelapse_interval=*/absl::Seconds(VLOG_IS_ON(2) ? 10 : 60),  //
      /*also_log_timelapses=*/VLOG_IS_ON(10));

  // Run `env.num_threads` independent distillation threads.
  std::vector<std::thread> threads(env.num_threads);
  std::vector<Environment> envs(env.num_threads, env);
  std::vector<std::vector<size_t>> shard_indices_per_thread(env.num_threads);
  // Start the threads.
  for (size_t thread_idx = 0; thread_idx < env.num_threads; ++thread_idx) {
    envs[thread_idx].my_shard_index += thread_idx;
    // Shuffle the shards, so that every thread produces different result.
    Rng rng(GetRandomSeed(env.seed + thread_idx));
    auto &shard_indices = shard_indices_per_thread[thread_idx];
    shard_indices.resize(env.total_shards);
    std::iota(shard_indices.begin(), shard_indices.end(), 0);
    std::shuffle(shard_indices.begin(), shard_indices.end(), rng);
    // Run the thread.
    threads[thread_idx] =
        std::thread(DistillTask, std::ref(envs[thread_idx]), shard_indices);
  }
  // Join threads.
  for (size_t thread_idx = 0; thread_idx < env.num_threads; thread_idx++) {
    threads[thread_idx].join();
  }
  return EXIT_SUCCESS;
}

}  // namespace centipede
