// Copyright 2019 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "chrome/common/media/component_widevine_cdm_hint_file_linux.h"

#include <memory>
#include <string>
#include <utility>

#include "base/check.h"
#include "base/files/file_path.h"
#include "base/files/file_util.h"
#include "base/files/important_file_writer.h"
#include "base/json/json_string_value_serializer.h"
#include "base/logging.h"
#include "base/path_service.h"
#include "base/values.h"
#include "base/version.h"
#include "chrome/common/chrome_paths.h"
#include "third_party/widevine/cdm/widevine_cdm_common.h"

namespace {

// Fields used inside the hint file.
const char kPath[] = "Path";
const char kLastBundledVersion[] = "LastBundledVersion";

// On Linux the Widevine CDM is loaded into the zygote at startup. When the
// component updater runs sometime later and finds a newer version of the
// Widevine CDM, don't register it as the newer version can't be used. Instead,
// save the path to the new Widevine CDM in this file. Next time at startup this
// file will be checked, and if it references a usable Widevine CDM, use this
// version instead of the old (potentially bundled) CDM.
// Add this method instead of using chrome::FILE_COMPONENT_WIDEVINE_CDM_HINT
// because only directories (not files) can be configured via
// base::PathService::Override.
bool GetHintFilePath(base::FilePath* hint_file_path) {
  base::FilePath user_data_dir;
  if (!base::PathService::Get(chrome::DIR_USER_DATA, &user_data_dir))
    return false;
  // Match the file name in chrome/common/chrome_paths.cc
  *hint_file_path = user_data_dir
      .AppendASCII(kWidevineCdmBaseDirectory)
      .Append(FILE_PATH_LITERAL("latest-component-updated-widevine-cdm"));
  return true;
}

// Returns the hint file contents as a Value::Dict. Returned result may be an
// empty dictionary if the hint file does not exist or is formatted incorrectly.
base::Value::Dict GetHintFileContents() {
  base::FilePath hint_file_path;
  CHECK(GetHintFilePath(&hint_file_path));
  DVLOG(1) << __func__ << " checking " << hint_file_path;

  if (!base::PathExists(hint_file_path)) {
    DVLOG(1) << "CDM hint file at " << hint_file_path << " does not exist.";
    return base::Value::Dict();
  }

  std::string json_string;
  if (!base::ReadFileToString(hint_file_path, &json_string)) {
    DLOG(ERROR) << "Could not read the CDM hint file at " << hint_file_path;
    return base::Value::Dict();
  }

  std::string error_message;
  JSONStringValueDeserializer deserializer(json_string);
  std::unique_ptr<base::Value> dict =
      deserializer.Deserialize(/*error_code=*/nullptr, &error_message);

  if (!dict || !dict->is_dict()) {
    DLOG(ERROR) << "Could not deserialize the CDM hint file. Error: "
                << error_message;
    return base::Value::Dict();
  }

  return std::move(*dict).TakeDict();
}

}  // namespace

bool UpdateWidevineCdmHintFile(const base::FilePath& cdm_base_path,
                               std::optional<base::Version> bundled_version) {
  DCHECK(!cdm_base_path.empty());

  base::FilePath hint_file_path;
  CHECK(GetHintFilePath(&hint_file_path));

  base::Value::Dict dict;
  dict.Set(kPath, cdm_base_path.value());
  if (bundled_version.has_value()) {
    dict.Set(kLastBundledVersion, bundled_version.value().GetString());
  }

  std::string json_string;
  JSONStringValueSerializer serializer(&json_string);
  if (!serializer.Serialize(dict)) {
    DLOG(ERROR) << "Could not serialize the CDM hint file.";
    return false;
  }

  DVLOG(1) << __func__ << " setting " << cdm_base_path << " to " << json_string;
  return base::ImportantFileWriter::WriteFileAtomically(hint_file_path,
                                                        json_string);
}

base::FilePath GetHintedWidevineCdmDirectory() {
  base::Value::Dict dict = GetHintFileContents();

  auto* path_str = dict.FindString(kPath);
  if (!path_str) {
    DVLOG(1) << "CDM hint file missing " << kPath;
    return base::FilePath();
  }

  const base::FilePath path(*path_str);
  DLOG_IF(ERROR, path.empty())
      << "CDM hint file path " << *path_str << " is invalid.";
  DVLOG(1) << __func__ << " returns " << path;
  return path;
}

std::optional<base::Version> GetBundledVersionDuringLastComponentUpdate() {
  base::Value::Dict dict = GetHintFileContents();

  auto* version_str = dict.FindString(kLastBundledVersion);
  if (!version_str) {
    DVLOG(1) << "CDM hint file missing " << kLastBundledVersion;
    return std::nullopt;
  }

  const base::Version version(*version_str);
  DLOG_IF(ERROR, !version.IsValid())
      << "CDM hint file version " << *version_str << " is invalid.";
  DVLOG(1) << __func__ << " returns " << version;
  return version;
}
