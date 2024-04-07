// Copyright 2017 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/shared/model/web_state_list/web_state_list.h"

#import "base/memory/raw_ptr.h"
#import "base/scoped_multi_source_observation.h"
#import "base/scoped_observation.h"
#import "base/supports_user_data.h"
#import "components/tab_groups/tab_group_color.h"
#import "ios/chrome/browser/shared/model/web_state_list/removing_indexes.h"
#import "ios/chrome/browser/shared/model/web_state_list/tab_group.h"
#import "ios/chrome/browser/shared/model/web_state_list/test/fake_web_state_list_delegate.h"
#import "ios/chrome/browser/shared/model/web_state_list/web_state_list_observer.h"
#import "ios/chrome/browser/shared/model/web_state_list/web_state_opener.h"
#import "ios/web/public/test/fakes/fake_navigation_manager.h"
#import "ios/web/public/test/fakes/fake_web_state.h"
#import "testing/gmock/include/gmock/gmock.h"
#import "testing/gtest/include/gtest/gtest.h"
#import "testing/platform_test.h"
#import "url/gurl.h"

using tab_groups::TabGroupVisualData;

namespace {
const char kURL0[] = "https://chromium.org/0";
const char kURL1[] = "https://chromium.org/1";
const char kURL2[] = "https://chromium.org/2";
const char kURL3[] = "https://chromium.org/3";
const char kURL4[] = "https://chromium.org/4";
const char kURL5[] = "https://chromium.org/5";
const char kURL6[] = "https://chromium.org/6";

// WebStateList observer that records which events have been called by the
// WebStateList.
class WebStateListTestObserver : public WebStateListObserver {
 public:
  WebStateListTestObserver() = default;

  WebStateListTestObserver(const WebStateListTestObserver&) = delete;
  WebStateListTestObserver& operator=(const WebStateListTestObserver&) = delete;

  void Observe(WebStateList* web_state_list) {
    observation_.AddObservation(web_state_list);
  }

  // Reset statistics whether events have been called.
  void ResetStatistics() {
    web_state_inserted_count_ = 0;
    web_state_moved_count_ = 0;
    web_state_replaced_count_ = 0;
    web_state_detached_count_ = 0;
    web_state_activated_count_ = 0;
    pinned_state_changed_count_ = 0;
    batch_operation_started_count_ = 0;
    batch_operation_ended_count_ = 0;
    web_state_list_destroyed_count_ = 0;
  }

  // Returns whether the insertion operation was invoked.
  bool web_state_inserted() const { return web_state_inserted_count_ != 0; }

  // Returns the number of insertion operations.
  int web_state_inserted_count() const { return web_state_moved_count_; }

  // Returns whether the move operation was invoked.
  bool web_state_moved() const { return web_state_moved_count_ != 0; }

  // Returns the number of move operations.
  int web_state_moved_count() const { return web_state_moved_count_; }

  // Returns whether the replacement operation was invoked.
  bool web_state_replaced() const { return web_state_replaced_count_ != 0; }

  // Returns the number of replacement operations.
  int web_state_replaced_count() const { return web_state_replaced_count_; }

  // Returns whether a WebState was detached.
  bool web_state_detached() const { return web_state_detached_count_ != 0; }

  // Returns the number of WebState detached.
  int web_state_detached_count() const { return web_state_detached_count_; }

  // Returns whether a WebState was activated.
  bool web_state_activated() const { return web_state_activated_count_ != 0; }

  // Returns the number of WebState activation.
  int web_state_activated_count() const { return web_state_activated_count_; }

  // Returns whether the pinned state was updated.
  bool pinned_state_changed() const { return pinned_state_changed_count_ != 0; }

  // Returns the number of WebState pin changes.
  int pinned_state_changed_count() const { return pinned_state_changed_count_; }

  // Returns whether WillBeginBatchOperation was invoked.
  bool batch_operation_started() const {
    return batch_operation_started_count_ != 0;
  }

  // Returns the number of times WillBeginBatchOperation was invoked.
  int batch_operation_started_count() const {
    return batch_operation_started_count_;
  }

  // Returns whether BatchOperationEnded was invoked.
  bool batch_operation_ended() const {
    return batch_operation_ended_count_ != 0;
  }

  // Returns the number of times BatchOperationEnded was invoked.
  int batch_operation_ended_count() const {
    return batch_operation_ended_count_;
  }

  // Returns whether WebStateListDestroyed was invoked.
  bool web_state_list_destroyed() const {
    return web_state_list_destroyed_count_ != 0;
  }

  // Returns the number of times WebStateListDestroyed was invoked.
  int web_state_list_destroyed_count() const {
    return web_state_list_destroyed_count_;
  }

  // WebStateListObserver implementation.
  void WebStateListDidChange(WebStateList* web_state_list,
                             const WebStateListChange& change,
                             const WebStateListStatus& status) override {
    switch (change.type()) {
      case WebStateListChange::Type::kStatusOnly: {
        const WebStateListChangeStatusOnly& statusOnlyChange =
            change.As<WebStateListChangeStatusOnly>();
        if (statusOnlyChange.pinned_state_changed()) {
          ++pinned_state_changed_count_;
        }
        // The activation is handled after this switch statement.
        break;
      }
      case WebStateListChange::Type::kDetach:
        EXPECT_TRUE(web_state_list->IsMutating());
        ++web_state_detached_count_;
        break;
      case WebStateListChange::Type::kMove:
        EXPECT_TRUE(web_state_list->IsMutating());
        ++web_state_moved_count_;
        break;
      case WebStateListChange::Type::kReplace:
        EXPECT_TRUE(web_state_list->IsMutating());
        ++web_state_replaced_count_;
        break;
      case WebStateListChange::Type::kInsert:
        EXPECT_TRUE(web_state_list->IsMutating());
        ++web_state_inserted_count_;
        break;
    }

    if (status.active_web_state_change()) {
      ++web_state_activated_count_;
    }
  }

  void WillBeginBatchOperation(WebStateList* web_state_list) override {
    ++batch_operation_started_count_;
  }

  void BatchOperationEnded(WebStateList* web_state_list) override {
    ++batch_operation_ended_count_;
  }

  void WebStateListDestroyed(WebStateList* web_state_list) override {
    ++web_state_list_destroyed_count_;
    observation_.RemoveObservation(web_state_list);
  }

 private:
  int web_state_inserted_count_ = 0;
  int web_state_moved_count_ = 0;
  int web_state_replaced_count_ = 0;
  int web_state_detached_count_ = 0;
  int web_state_activated_count_ = 0;
  int pinned_state_changed_count_ = 0;
  int batch_operation_started_count_ = 0;
  int batch_operation_ended_count_ = 0;
  int web_state_list_destroyed_count_ = 0;
  base::ScopedMultiSourceObservation<WebStateList, WebStateListObserver>
      observation_{this};
};

class MockWebStateObserver : public web::WebStateObserver {
 public:
  MockWebStateObserver() {}
  ~MockWebStateObserver() override {}

  MOCK_METHOD1(WebStateDestroyed, void(web::WebState*));
};

// A fake NavigationManager used to test opener-opened relationship in the
// WebStateList.
class FakeNavigationManager : public web::FakeNavigationManager {
 public:
  FakeNavigationManager() = default;

  FakeNavigationManager(const FakeNavigationManager&) = delete;
  FakeNavigationManager& operator=(const FakeNavigationManager&) = delete;

  // web::NavigationManager implementation.
  int GetLastCommittedItemIndex() const override {
    return last_committed_item_index;
  }

  bool CanGoBack() const override { return last_committed_item_index > 0; }

  bool CanGoForward() const override {
    return last_committed_item_index < INT_MAX;
  }

  void GoBack() override {
    DCHECK(CanGoBack());
    --last_committed_item_index;
  }

  void GoForward() override {
    DCHECK(CanGoForward());
    ++last_committed_item_index;
  }

  void GoToIndex(int index) override { last_committed_item_index = index; }

  int last_committed_item_index = 0;
};

// A WebStateListDelegate that records the last inserted/activated WebState.
class TestWebStateListDelegate final : public WebStateListDelegate {
 public:
  void ResetStatistics() {
    inserted_web_state_count_ = 0;
    activated_web_state_count_ = 0;

    last_inserted_web_state_ = nullptr;
    last_activated_web_state_ = nullptr;
  }

  int InsertedWebStateCount() const { return inserted_web_state_count_; }
  int ActivatedWebStateCount() const { return activated_web_state_count_; }

  web::WebState* LastInsertedWebState() { return last_inserted_web_state_; }
  web::WebState* LastActivatedWebState() { return last_activated_web_state_; }

  // WebStateListDelegate implementation.
  void WillAddWebState(web::WebState* web_state) final {
    ++inserted_web_state_count_;
    last_inserted_web_state_ = web_state;
  }
  void WillActivateWebState(web::WebState* web_state) final {
    ++activated_web_state_count_;
    last_activated_web_state_ = web_state;
  }

 private:
  int inserted_web_state_count_ = 0;
  int activated_web_state_count_ = 0;
  raw_ptr<web::WebState> last_inserted_web_state_;
  raw_ptr<web::WebState> last_activated_web_state_;
};

}  // namespace

using WebStateListRangeTest = PlatformTest;

TEST_F(WebStateListRangeTest, InvalidRange) {
  WebStateList::Range range = WebStateList::Range::InvalidRange();

  EXPECT_FALSE(range.IsValid());
}

TEST_F(WebStateListRangeTest, ZeroRange) {
  WebStateList::Range range(0, 0);

  EXPECT_TRUE(range.IsValid());
  EXPECT_EQ(0, range.start());
  EXPECT_EQ(0, range.count());
  EXPECT_EQ(0, range.end());

  EXPECT_FALSE(range.contains(-1));
  EXPECT_FALSE(range.contains(0));
  EXPECT_FALSE(range.contains(1));

  EXPECT_EQ(WebStateList::Range(0, 0), range);
  EXPECT_NE(WebStateList::Range(0, 1), range);
  EXPECT_NE(WebStateList::Range(1, 0), range);
  EXPECT_NE(WebStateList::Range(1, 1), range);
  EXPECT_NE(WebStateList::Range::InvalidRange(), range);
}

TEST_F(WebStateListRangeTest, SomeRange) {
  WebStateList::Range range(1, 2);

  EXPECT_TRUE(range.IsValid());
  EXPECT_EQ(1, range.start());
  EXPECT_EQ(2, range.count());
  EXPECT_EQ(3, range.end());

  EXPECT_FALSE(range.contains(-1));
  EXPECT_FALSE(range.contains(0));
  EXPECT_TRUE(range.contains(1));
  EXPECT_TRUE(range.contains(2));
  EXPECT_FALSE(range.contains(3));

  EXPECT_NE(WebStateList::Range(0, 0), range);
  EXPECT_NE(WebStateList::Range(0, 1), range);
  EXPECT_NE(WebStateList::Range(1, 0), range);
  EXPECT_NE(WebStateList::Range(1, 1), range);
  EXPECT_EQ(WebStateList::Range(1, 2), range);
  EXPECT_NE(WebStateList::Range::InvalidRange(), range);
}

class WebStateListTest : public PlatformTest {
 public:
  WebStateListTest() : web_state_list_(&delegate_) {
    observer_.Observe(&web_state_list_);
  }

  WebStateListTest(const WebStateListTest&) = delete;
  WebStateListTest& operator=(const WebStateListTest&) = delete;

 protected:
  TestWebStateListDelegate delegate_;
  WebStateList web_state_list_;
  WebStateListTestObserver observer_;

  std::unique_ptr<web::FakeWebState> CreateWebState(const char* url) {
    auto fake_web_state = std::make_unique<web::FakeWebState>();
    fake_web_state->SetCurrentURL(GURL(url));
    fake_web_state->SetNavigationManager(
        std::make_unique<FakeNavigationManager>());
    return fake_web_state;
  }

  void AppendNewWebState(const char* url) {
    AppendNewWebState(url, WebStateOpener());
  }

  void AppendNewWebState(const char* url, WebStateOpener opener) {
    web_state_list_.InsertWebState(
        CreateWebState(url),
        WebStateList::InsertionParams::Automatic().WithOpener(opener));
  }

  void AppendNewWebState(std::unique_ptr<web::FakeWebState> web_state) {
    web_state_list_.InsertWebState(std::move(web_state));
  }
};

// Tests that empty() matches count() != 0.
TEST_F(WebStateListTest, IsEmpty) {
  EXPECT_EQ(0, web_state_list_.count());
  EXPECT_TRUE(web_state_list_.empty());

  AppendNewWebState(kURL0);

  ASSERT_GE(web_state_list_.count(), 1);
  EXPECT_EQ(delegate_.LastInsertedWebState(), web_state_list_.GetWebStateAt(0));
  EXPECT_EQ(delegate_.LastActivatedWebState(), nullptr);

  EXPECT_TRUE(observer_.web_state_inserted());
  ASSERT_EQ(1, web_state_list_.count());
  EXPECT_FALSE(web_state_list_.empty());
}

// Tests that inserting a single webstate works.
TEST_F(WebStateListTest, InsertUrlSingle) {
  AppendNewWebState(kURL0);

  ASSERT_GE(web_state_list_.count(), 1);
  EXPECT_EQ(delegate_.LastInsertedWebState(), web_state_list_.GetWebStateAt(0));
  EXPECT_EQ(delegate_.LastActivatedWebState(), nullptr);

  EXPECT_TRUE(observer_.web_state_inserted());
  ASSERT_EQ(1, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
}

// Tests that inserting multiple webstates puts them in the expected places.
TEST_F(WebStateListTest, InsertUrlMultiple) {
  web_state_list_.InsertWebState(CreateWebState(kURL0),
                                 WebStateList::InsertionParams::AtIndex(0));

  ASSERT_GE(web_state_list_.count(), 1);
  EXPECT_EQ(delegate_.LastInsertedWebState(), web_state_list_.GetWebStateAt(0));
  EXPECT_EQ(delegate_.LastActivatedWebState(), nullptr);

  web_state_list_.InsertWebState(CreateWebState(kURL1),
                                 WebStateList::InsertionParams::AtIndex(0));

  ASSERT_GE(web_state_list_.count(), 1);
  EXPECT_EQ(delegate_.LastInsertedWebState(), web_state_list_.GetWebStateAt(0));
  EXPECT_EQ(delegate_.LastActivatedWebState(), nullptr);

  web_state_list_.InsertWebState(CreateWebState(kURL2),
                                 WebStateList::InsertionParams::AtIndex(1));

  ASSERT_GE(web_state_list_.count(), 1);
  EXPECT_EQ(delegate_.LastInsertedWebState(), web_state_list_.GetWebStateAt(1));
  EXPECT_EQ(delegate_.LastActivatedWebState(), nullptr);

  EXPECT_TRUE(observer_.web_state_inserted());
  ASSERT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
}

// Tests webstate activation.
TEST_F(WebStateListTest, ActivateWebState) {
  AppendNewWebState(kURL0);
  EXPECT_EQ(nullptr, web_state_list_.GetActiveWebState());

  ASSERT_GE(web_state_list_.count(), 1);
  EXPECT_EQ(delegate_.LastInsertedWebState(), web_state_list_.GetWebStateAt(0));
  EXPECT_EQ(delegate_.LastActivatedWebState(), nullptr);

  web_state_list_.ActivateWebStateAt(0);

  ASSERT_GE(web_state_list_.count(), 1);
  EXPECT_EQ(delegate_.LastInsertedWebState(), web_state_list_.GetWebStateAt(0));
  EXPECT_EQ(delegate_.LastActivatedWebState(),
            web_state_list_.GetWebStateAt(0));

  EXPECT_TRUE(observer_.web_state_activated());
  ASSERT_EQ(1, web_state_list_.count());
  EXPECT_EQ(web_state_list_.GetWebStateAt(0),
            web_state_list_.GetActiveWebState());
}

// Tests activating a webstate as it is inserted.
TEST_F(WebStateListTest, InsertActivate) {
  web_state_list_.InsertWebState(
      CreateWebState(kURL0),
      WebStateList::InsertionParams::AtIndex(0).Activate());

  ASSERT_GE(web_state_list_.count(), 1);
  EXPECT_EQ(delegate_.LastInsertedWebState(), web_state_list_.GetWebStateAt(0));
  EXPECT_EQ(delegate_.LastActivatedWebState(),
            web_state_list_.GetWebStateAt(0));

  EXPECT_TRUE(observer_.web_state_inserted());
  EXPECT_TRUE(observer_.web_state_activated());
  ASSERT_EQ(1, web_state_list_.count());
  EXPECT_EQ(web_state_list_.GetWebStateAt(0),
            web_state_list_.GetActiveWebState());
}

// Tests finding a known webstate.
TEST_F(WebStateListTest, GetIndexOfWebState) {
  auto web_state_0 = CreateWebState(kURL0);
  web::WebState* target_web_state = web_state_0.get();
  auto other_web_state = CreateWebState(kURL1);

  // Target not yet in list.
  EXPECT_EQ(WebStateList::kInvalidIndex,
            web_state_list_.GetIndexOfWebState(target_web_state));

  AppendNewWebState(kURL2);
  AppendNewWebState(std::move(web_state_0));
  // Target in list at index 1.
  EXPECT_EQ(1, web_state_list_.GetIndexOfWebState(target_web_state));
  EXPECT_EQ(WebStateList::kInvalidIndex,
            web_state_list_.GetIndexOfWebState(other_web_state.get()));

  // Another webstate with the same URL as the target also in list.
  AppendNewWebState(kURL0);
  EXPECT_EQ(1, web_state_list_.GetIndexOfWebState(target_web_state));

  // Another webstate inserted before target; target now at index 2.
  web_state_list_.InsertWebState(CreateWebState(kURL3),
                                 WebStateList::InsertionParams::AtIndex(0));
  EXPECT_EQ(2, web_state_list_.GetIndexOfWebState(target_web_state));
}

// Tests finding a webstate by URL.
TEST_F(WebStateListTest, GetIndexOfWebStateWithURL) {
  // Empty list.
  EXPECT_EQ(WebStateList::kInvalidIndex,
            web_state_list_.GetIndexOfWebStateWithURL(GURL(kURL0)));

  // One webstate with a different URL in list.
  AppendNewWebState(kURL1);
  EXPECT_EQ(WebStateList::kInvalidIndex,
            web_state_list_.GetIndexOfWebStateWithURL(GURL(kURL0)));

  // Target URL at index 1.
  AppendNewWebState(kURL0);
  EXPECT_EQ(1, web_state_list_.GetIndexOfWebStateWithURL(GURL(kURL0)));

  // Another webstate with the target URL also at index 3.
  AppendNewWebState(kURL2);
  AppendNewWebState(kURL0);
  EXPECT_EQ(1, web_state_list_.GetIndexOfWebStateWithURL(GURL(kURL0)));
}

// Tests finding a non-active webstate by URL.
TEST_F(WebStateListTest, GetIndexOfInactiveWebStateWithURL) {
  // Empty list.
  EXPECT_EQ(WebStateList::kInvalidIndex,
            web_state_list_.GetIndexOfInactiveWebStateWithURL(GURL(kURL0)));

  // One webstate with a different URL in list.
  AppendNewWebState(kURL1);
  EXPECT_EQ(WebStateList::kInvalidIndex,
            web_state_list_.GetIndexOfInactiveWebStateWithURL(GURL(kURL0)));

  // Target URL at index 1.
  AppendNewWebState(kURL0);
  EXPECT_EQ(1, web_state_list_.GetIndexOfInactiveWebStateWithURL(GURL(kURL0)));

  // Activate webstate at index 1.
  web_state_list_.ActivateWebStateAt(1);
  EXPECT_EQ(WebStateList::kInvalidIndex,
            web_state_list_.GetIndexOfInactiveWebStateWithURL(GURL(kURL0)));
  // GetIndexOfWebStateWithURL still finds it.
  EXPECT_EQ(1, web_state_list_.GetIndexOfWebStateWithURL(GURL(kURL0)));

  // Another webstate with the target URL also at index 3.
  AppendNewWebState(kURL2);
  AppendNewWebState(kURL0);
  EXPECT_EQ(3, web_state_list_.GetIndexOfInactiveWebStateWithURL(GURL(kURL0)));
  EXPECT_EQ(1, web_state_list_.GetIndexOfWebStateWithURL(GURL(kURL0)));

  // Activate the webstate at index 2, so there the target URL is both before
  // and after the active webstate.
  web_state_list_.ActivateWebStateAt(2);
  EXPECT_EQ(1, web_state_list_.GetIndexOfInactiveWebStateWithURL(GURL(kURL0)));

  // Remove the webstate at index 1, so the only webstate with the target URL
  // is after the active webstate.
  web_state_list_.DetachWebStateAt(1);

  // Active webstate is now index 1, target URL is at index 2.
  EXPECT_EQ(2, web_state_list_.GetIndexOfInactiveWebStateWithURL(GURL(kURL0)));
}

// Tests that inserted webstates correctly inherit openers.
TEST_F(WebStateListTest, InsertInheritOpener) {
  AppendNewWebState(kURL0);
  web_state_list_.ActivateWebStateAt(0);
  EXPECT_TRUE(observer_.web_state_activated());
  ASSERT_EQ(1, web_state_list_.count());
  ASSERT_EQ(web_state_list_.GetWebStateAt(0),
            web_state_list_.GetActiveWebState());

  web_state_list_.InsertWebState(
      CreateWebState(kURL1),
      WebStateList::InsertionParams::Automatic().InheritOpener());

  ASSERT_EQ(2, web_state_list_.count());
  ASSERT_EQ(web_state_list_.GetActiveWebState(),
            web_state_list_.GetOpenerOfWebStateAt(1).opener);
}

// Tests moving webstates one place to the "right" (to a higher index).
TEST_F(WebStateListTest, MoveWebStateAtRightByOne) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  // Coherence check before closing WebState.
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());

  observer_.ResetStatistics();
  web_state_list_.MoveWebStateAt(0, 1);

  EXPECT_TRUE(observer_.web_state_moved());
  EXPECT_FALSE(observer_.web_state_activated());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
}

// Tests moving webstates more than one place to the "right" (to a higher
// index).
TEST_F(WebStateListTest, MoveWebStateAtRightByMoreThanOne) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  // Sanity check before closing WebState.
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());

  observer_.ResetStatistics();
  web_state_list_.MoveWebStateAt(0, 2);

  EXPECT_TRUE(observer_.web_state_moved());
  EXPECT_FALSE(observer_.web_state_activated());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
}

// Tests moving webstates one place to the "left" (to a lower index).
TEST_F(WebStateListTest, MoveWebStateAtLeftByOne) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  // Sanity check before closing WebState.
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());

  observer_.ResetStatistics();
  web_state_list_.MoveWebStateAt(2, 1);

  EXPECT_TRUE(observer_.web_state_moved());
  EXPECT_FALSE(observer_.web_state_activated());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
}

// Tests moving webstates more than one place to the "left" (to a lower index).
TEST_F(WebStateListTest, MoveWebStateAtLeftByMoreThanOne) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  // Sanity check before closing WebState.
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());

  observer_.ResetStatistics();
  web_state_list_.MoveWebStateAt(2, 0);

  EXPECT_TRUE(observer_.web_state_moved());
  EXPECT_FALSE(observer_.web_state_activated());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
}

// Tests "moving" webstates (calling MoveWebStateAt with the same source and
// destination indexes.
TEST_F(WebStateListTest, MoveWebStateAtSameIndex) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  // Sanity check before closing WebState.
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());

  observer_.ResetStatistics();
  web_state_list_.MoveWebStateAt(2, 2);

  EXPECT_FALSE(observer_.web_state_moved());
  EXPECT_FALSE(observer_.web_state_activated());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
}

// Tests moving an active webstate.
TEST_F(WebStateListTest, MoveActiveWebState) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);
  web_state_list_.ActivateWebStateAt(1);

  // Sanity check before closing WebState.
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
  EXPECT_EQ(1, web_state_list_.active_index());

  observer_.ResetStatistics();
  web_state_list_.MoveWebStateAt(1, 2);

  EXPECT_TRUE(observer_.web_state_moved());
  EXPECT_FALSE(observer_.web_state_activated());
  EXPECT_EQ(2, web_state_list_.active_index());
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
}

// Tests replacing webstates.
TEST_F(WebStateListTest, ReplaceWebStateAt) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);

  // Sanity check before replacing WebState.
  EXPECT_EQ(2, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());

  observer_.ResetStatistics();
  std::unique_ptr<web::WebState> old_web_state(
      web_state_list_.ReplaceWebStateAt(1, CreateWebState(kURL2)));

  EXPECT_EQ(delegate_.LastActivatedWebState(), nullptr);

  EXPECT_TRUE(observer_.web_state_replaced());
  EXPECT_FALSE(observer_.web_state_activated());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());
  EXPECT_EQ(2, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, old_web_state->GetVisibleURL().spec());
}

// Tests replacing an active webstate.
TEST_F(WebStateListTest, ReplaceActiveWebStateAt) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  web_state_list_.ActivateWebStateAt(1);

  // Sanity check before replacing WebState.
  EXPECT_EQ(2, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(1, web_state_list_.active_index());

  observer_.ResetStatistics();
  std::unique_ptr<web::WebState> old_web_state(
      web_state_list_.ReplaceWebStateAt(1, CreateWebState(kURL2)));

  EXPECT_EQ(delegate_.LastActivatedWebState(),
            web_state_list_.GetWebStateAt(1));

  EXPECT_TRUE(observer_.web_state_replaced());
  EXPECT_TRUE(observer_.web_state_activated());
  EXPECT_EQ(1, web_state_list_.active_index());
  EXPECT_EQ(2, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, old_web_state->GetVisibleURL().spec());
}

// Tests detaching webstates at index 0.
TEST_F(WebStateListTest, DetachWebStateAtIndexBeginning) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  // Sanity check before closing WebState.
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());

  observer_.ResetStatistics();
  web_state_list_.DetachWebStateAt(0);

  EXPECT_EQ(delegate_.LastActivatedWebState(), nullptr);

  EXPECT_TRUE(observer_.web_state_detached());
  EXPECT_FALSE(observer_.web_state_activated());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());
  EXPECT_EQ(2, web_state_list_.count());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
}

// Tests detaching webstates at an index that isn't 0 or the last index.
TEST_F(WebStateListTest, DetachWebStateAtIndexMiddle) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  // Sanity check before closing WebState.
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());

  observer_.ResetStatistics();
  web_state_list_.DetachWebStateAt(1);

  EXPECT_EQ(delegate_.LastActivatedWebState(), nullptr);

  EXPECT_TRUE(observer_.web_state_detached());
  EXPECT_FALSE(observer_.web_state_activated());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());
  EXPECT_EQ(2, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
}

// Tests detaching webstates at the last index.
TEST_F(WebStateListTest, DetachWebStateAtIndexLast) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  // Sanity check before closing WebState.
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());

  observer_.ResetStatistics();
  web_state_list_.DetachWebStateAt(2);

  EXPECT_EQ(delegate_.LastActivatedWebState(), nullptr);

  EXPECT_TRUE(observer_.web_state_detached());
  EXPECT_FALSE(observer_.web_state_activated());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());
  EXPECT_EQ(2, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
}

// Tests detaching an active webstate.
TEST_F(WebStateListTest, DetachActiveWebState) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);
  web_state_list_.ActivateWebStateAt(0);

  EXPECT_EQ(delegate_.LastActivatedWebState(),
            web_state_list_.GetActiveWebState());

  // Sanity check before closing WebState.
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(kURL0, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec());
  EXPECT_EQ(0, web_state_list_.active_index());

  observer_.ResetStatistics();
  web_state_list_.DetachWebStateAt(0);

  // Note: this is a different WebState.
  EXPECT_EQ(delegate_.LastActivatedWebState(),
            web_state_list_.GetActiveWebState());

  EXPECT_TRUE(observer_.web_state_detached());
  EXPECT_TRUE(observer_.web_state_activated());
  EXPECT_EQ(0, web_state_list_.active_index());
  EXPECT_EQ(2, web_state_list_.count());
  EXPECT_EQ(kURL1, web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec());
  EXPECT_EQ(kURL2, web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec());
}

// Tests closing all non-pinned webstates (pinned WebStates present).
TEST_F(WebStateListTest, CloseAllNonPinnedWebStates_PinnedWebStatesPresent) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  web_state_list_.SetWebStatePinnedAt(0, true);

  // Sanity checks before closing WebStates.
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(0));
  EXPECT_TRUE(observer_.pinned_state_changed());

  observer_.ResetStatistics();
  CloseAllNonPinnedWebStates(web_state_list_, WebStateList::CLOSE_USER_ACTION);

  EXPECT_EQ(1, web_state_list_.count());
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(0));

  EXPECT_TRUE(observer_.web_state_detached());
  EXPECT_TRUE(observer_.batch_operation_started());
  EXPECT_TRUE(observer_.batch_operation_ended());
}

// Tests closing all non-pinned webstates (non-pinned WebStates not present).
TEST_F(WebStateListTest,
       CloseAllNonPinnedWebStates_NonPinnedWebStatesNotPresent) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  web_state_list_.SetWebStatePinnedAt(0, true);
  web_state_list_.SetWebStatePinnedAt(1, true);
  web_state_list_.SetWebStatePinnedAt(2, true);

  // Sanity checks before closing WebStates.
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(0));
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(1));
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(2));
  EXPECT_TRUE(observer_.pinned_state_changed());

  observer_.ResetStatistics();
  CloseAllNonPinnedWebStates(web_state_list_, WebStateList::CLOSE_USER_ACTION);

  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(0));
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(1));
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(2));

  EXPECT_FALSE(observer_.web_state_detached());
  EXPECT_TRUE(observer_.batch_operation_started());
  EXPECT_TRUE(observer_.batch_operation_ended());
}

// Tests closing all non-pinned webstates (pinned WebStates not present).
TEST_F(WebStateListTest, CloseAllNonPinnedWebStates_PinnedWebStatesNotPresent) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  // Sanity checks before closing WebStates.
  EXPECT_EQ(3, web_state_list_.count());

  observer_.ResetStatistics();
  CloseAllNonPinnedWebStates(web_state_list_, WebStateList::CLOSE_USER_ACTION);

  EXPECT_EQ(0, web_state_list_.count());

  EXPECT_TRUE(observer_.web_state_detached());
  EXPECT_TRUE(observer_.batch_operation_started());
  EXPECT_TRUE(observer_.batch_operation_ended());
}

// Tests closing all non-pinned webstates (pinned active WebState present).
TEST_F(WebStateListTest,
       CloseAllNonPinnedWebStates_PinnedActiveWebStatePresent) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  web_state_list_.SetWebStatePinnedAt(0, true);
  web_state_list_.ActivateWebStateAt(0);

  // Sanity checks before closing WebStates.
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(0, web_state_list_.active_index());
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(0));
  EXPECT_TRUE(observer_.pinned_state_changed());

  observer_.ResetStatistics();
  CloseAllNonPinnedWebStates(web_state_list_, WebStateList::CLOSE_USER_ACTION);

  EXPECT_EQ(1, web_state_list_.count());
  EXPECT_EQ(0, web_state_list_.active_index());
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(0));

  EXPECT_TRUE(observer_.web_state_detached());
  EXPECT_FALSE(observer_.web_state_activated());
  EXPECT_TRUE(observer_.batch_operation_started());
  EXPECT_TRUE(observer_.batch_operation_ended());
}

// Tests closing all non-pinned webstates (pinned WebState and active non-pinned
// WebState present independently).
TEST_F(WebStateListTest,
       CloseAllNonPinnedWebStates_PinnedWebStateAndActiveWebStatePresent) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  web_state_list_.SetWebStatePinnedAt(0, true);
  web_state_list_.ActivateWebStateAt(1);

  // Sanity checks before closing WebStates.
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(1, web_state_list_.active_index());
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(0));
  EXPECT_TRUE(observer_.pinned_state_changed());

  observer_.ResetStatistics();
  CloseAllNonPinnedWebStates(web_state_list_, WebStateList::CLOSE_USER_ACTION);

  EXPECT_EQ(1, web_state_list_.count());
  EXPECT_EQ(0, web_state_list_.active_index());
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(0));

  EXPECT_TRUE(observer_.web_state_detached());
  EXPECT_TRUE(observer_.web_state_activated());
  EXPECT_TRUE(observer_.batch_operation_started());
  EXPECT_TRUE(observer_.batch_operation_ended());
}

// Tests closing all webstates (pinned and non-pinned).
TEST_F(WebStateListTest, CloseAllWebStates_PinnedNonPinned) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  web_state_list_.SetWebStatePinnedAt(0, true);
  web_state_list_.SetWebStatePinnedAt(1, true);

  // Sanity check before closing WebStates.
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(0));
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(1));
  EXPECT_TRUE(observer_.pinned_state_changed());

  observer_.ResetStatistics();
  CloseAllWebStates(web_state_list_, WebStateList::CLOSE_USER_ACTION);

  EXPECT_EQ(0, web_state_list_.count());

  EXPECT_TRUE(observer_.web_state_detached());
  EXPECT_TRUE(observer_.batch_operation_started());
  EXPECT_TRUE(observer_.batch_operation_ended());
}

// Tests closing all webstates (non-pinned).
TEST_F(WebStateListTest, CloseAllWebStates_NonPinned) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  // Sanity check before closing WebStates.
  EXPECT_EQ(3, web_state_list_.count());

  observer_.ResetStatistics();
  CloseAllWebStates(web_state_list_, WebStateList::CLOSE_USER_ACTION);

  EXPECT_EQ(0, web_state_list_.count());

  EXPECT_TRUE(observer_.web_state_detached());
  EXPECT_TRUE(observer_.batch_operation_started());
  EXPECT_TRUE(observer_.batch_operation_ended());
}

// Tests closing all webstates (pinned, non-pinned and active WebStates).
TEST_F(WebStateListTest, CloseAllWebStates_PinnedNonPinnedWithActiveWebState) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  web_state_list_.SetWebStatePinnedAt(0, true);
  web_state_list_.ActivateWebStateAt(1);

  // Sanity checks before closing WebStates.
  EXPECT_EQ(3, web_state_list_.count());
  EXPECT_EQ(1, web_state_list_.active_index());
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(0));
  EXPECT_TRUE(observer_.pinned_state_changed());

  observer_.ResetStatistics();
  CloseAllWebStates(web_state_list_, WebStateList::CLOSE_USER_ACTION);

  EXPECT_EQ(0, web_state_list_.count());
  EXPECT_EQ(WebStateList::kInvalidIndex, web_state_list_.active_index());

  EXPECT_TRUE(observer_.web_state_detached());
  EXPECT_TRUE(observer_.web_state_activated());
  EXPECT_TRUE(observer_.batch_operation_started());
  EXPECT_TRUE(observer_.batch_operation_ended());
}

// Tests closing all webstates (non-pinned) to verify WebStateObserver function
// invocation ordering (which can have performance implications).
TEST_F(WebStateListTest, CloseAllWebStates_ObserverNotificationOrder) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);

  ASSERT_EQ(2, web_state_list_.count());

  web::WebState* web_state1 = web_state_list_.GetWebStateAt(0);
  web::WebState* web_state2 = web_state_list_.GetWebStateAt(1);

  MockWebStateObserver observer1;
  MockWebStateObserver observer2;

  base::ScopedObservation<web::WebState, web::WebStateObserver> observation1(
      &observer1);
  base::ScopedObservation<web::WebState, web::WebStateObserver> observation2(
      &observer2);

  observation1.Observe(web_state1);
  observation2.Observe(web_state2);

  EXPECT_CALL(observer1, WebStateDestroyed(web_state1))
      .WillOnce([&](web::WebState*) {
        // All webstates should be detached before invoking WebStateDestroyed
        // for any of them.
        EXPECT_EQ(0, web_state_list_.count());
        EXPECT_TRUE(observer_.web_state_detached());
        EXPECT_TRUE(observer_.batch_operation_started());
        EXPECT_FALSE(observer_.batch_operation_ended());
        observation1.Reset();
      });

  EXPECT_CALL(observer2, WebStateDestroyed(web_state2))
      .WillOnce([&](web::WebState*) {
        // All webstates should be detached before invoking WebStateDestroyed
        // for any of them.
        EXPECT_EQ(0, web_state_list_.count());
        EXPECT_TRUE(observer_.web_state_detached());
        EXPECT_TRUE(observer_.batch_operation_started());
        EXPECT_FALSE(observer_.batch_operation_ended());
        observation2.Reset();
      });

  CloseAllWebStates(web_state_list_, WebStateList::CLOSE_USER_ACTION);

  EXPECT_TRUE(observer_.batch_operation_ended());
}

// Tests closing a non-continuous range of WebStates.
TEST_F(WebStateListTest, CloseWebStatesAtIndices) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);
  AppendNewWebState(kURL3);
  AppendNewWebState(kURL4);
  AppendNewWebState(kURL5);
  AppendNewWebState(kURL6);

  web_state_list_.ActivateWebStateAt(3);

  // Sanity check before closing WebStates.
  EXPECT_EQ(7, web_state_list_.count());
  EXPECT_EQ(3, web_state_list_.active_index());

  delegate_.ResetStatistics();
  observer_.ResetStatistics();
  web_state_list_.CloseWebStatesAtIndices(WebStateList::CLOSE_USER_ACTION,
                                          RemovingIndexes{2, 3, 4, 6});

  // Check that the correct elements have been closed, and that the
  // active WebState is the expected one.
  ASSERT_EQ(3, web_state_list_.count());
  EXPECT_EQ(2, web_state_list_.active_index());
  EXPECT_EQ(web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec(), kURL0);
  EXPECT_EQ(web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec(), kURL1);
  EXPECT_EQ(web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec(), kURL5);

  // Check the delegate has only been called once, with the expected WebState
  // and that the observer has been called exactly once per removed WebState.
  EXPECT_EQ(delegate_.LastActivatedWebState(),
            web_state_list_.GetWebStateAt(2));
  EXPECT_EQ(1, delegate_.ActivatedWebStateCount());
  EXPECT_EQ(1, observer_.web_state_activated_count());
  EXPECT_EQ(4, observer_.web_state_detached_count());
}

// Tests closing one webstate.
TEST_F(WebStateListTest, CloseWebState) {
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);

  // Sanity check before closing WebState.
  EXPECT_EQ(3, web_state_list_.count());

  observer_.ResetStatistics();
  web_state_list_.CloseWebStateAt(0, WebStateList::CLOSE_USER_ACTION);

  EXPECT_EQ(2, web_state_list_.count());
  EXPECT_TRUE(observer_.web_state_detached());
  EXPECT_FALSE(observer_.batch_operation_started());
  EXPECT_FALSE(observer_.batch_operation_ended());
}

// Tests that batch operation can do nothing.
TEST_F(WebStateListTest, StartBatchOperation_DoNothing) {
  observer_.ResetStatistics();

  {
    WebStateList::ScopedBatchOperation lock =
        web_state_list_.StartBatchOperation();
  }

  EXPECT_TRUE(observer_.batch_operation_started());
  EXPECT_TRUE(observer_.batch_operation_ended());
}

// Tests that IsBatchInProgress() returns the correct value.
TEST_F(WebStateListTest, StartBatchOperation_IsBatchInProgress) {
  EXPECT_FALSE(web_state_list_.IsBatchInProgress());

  {
    WebStateList::ScopedBatchOperation lock =
        web_state_list_.StartBatchOperation();
    EXPECT_TRUE(web_state_list_.IsBatchInProgress());
  }

  EXPECT_FALSE(web_state_list_.IsBatchInProgress());
}

// Tests WebStates are pinned correctly while their order in the WebStateList
// doesn't change.
TEST_F(WebStateListTest, SetWebStatePinned_KeepingExistingOrder) {
  EXPECT_TRUE(web_state_list_.empty());

  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);
  AppendNewWebState(kURL3);

  // Pin kURL0 WebState.
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(0, true), 0);
  // Pin kURL1 WebState.
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(1, true), 1);
  // Pin kURL2 WebState.
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(2, true), 2);

  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(0));
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(1));
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(2));
  EXPECT_FALSE(web_state_list_.IsWebStatePinnedAt(3));

  EXPECT_EQ(web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec(), kURL0);
  EXPECT_EQ(web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec(), kURL1);
  EXPECT_EQ(web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec(), kURL2);
  EXPECT_EQ(web_state_list_.GetWebStateAt(3)->GetVisibleURL().spec(), kURL3);
}

// Tests WebStates are pinned correctly while their order in the WebStateList
// change.
TEST_F(WebStateListTest, SetWebStatePinned_InRandomOrder) {
  EXPECT_TRUE(web_state_list_.empty());

  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);
  AppendNewWebState(kURL3);

  // Pin kURL2 WebState.
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(2, true), 0);
  // Pin kURL3 WebState.
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(3, true), 1);
  // Pin kURL0 WebState.
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(2, true), 2);
  // Unpin kURL3 WebState.
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(1, false), 3);

  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(0));
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(1));
  EXPECT_FALSE(web_state_list_.IsWebStatePinnedAt(2));
  EXPECT_FALSE(web_state_list_.IsWebStatePinnedAt(3));

  EXPECT_EQ(web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec(), kURL2);
  EXPECT_EQ(web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec(), kURL0);
  EXPECT_EQ(web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec(), kURL1);
  EXPECT_EQ(web_state_list_.GetWebStateAt(3)->GetVisibleURL().spec(), kURL3);
}

// Tests pinned_tabs_count() and regular_tabs_count() return correct values.
TEST_F(WebStateListTest, PinnedAndRegularTabsCount) {
  EXPECT_TRUE(web_state_list_.empty());

  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);
  AppendNewWebState(kURL3);

  EXPECT_EQ(web_state_list_.pinned_tabs_count(), 0);
  EXPECT_EQ(web_state_list_.regular_tabs_count(), 4);

  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(0, true), 0);
  EXPECT_EQ(web_state_list_.pinned_tabs_count(), 1);
  EXPECT_EQ(web_state_list_.regular_tabs_count(), 3);

  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(3, true), 1);
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(3, true), 2);
  EXPECT_EQ(web_state_list_.pinned_tabs_count(), 3);
  EXPECT_EQ(web_state_list_.regular_tabs_count(), 1);

  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(3, true), 3);
  EXPECT_EQ(web_state_list_.pinned_tabs_count(), 4);
  EXPECT_EQ(web_state_list_.regular_tabs_count(), 0);

  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(0, false), 3);
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(0, false), 3);
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(0, false), 3);
  EXPECT_EQ(web_state_list_.pinned_tabs_count(), 1);
  EXPECT_EQ(web_state_list_.regular_tabs_count(), 3);

  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(0, false), 3);
  EXPECT_EQ(web_state_list_.pinned_tabs_count(), 0);
  EXPECT_EQ(web_state_list_.regular_tabs_count(), 4);
}

// Tests InsertWebState method correctly updates insertion index if it is in the
// pinned WebStates range.
TEST_F(WebStateListTest, InsertWebState_InsertionInPinnedRange) {
  const char testURL0[] = "https://chromium.org/test_0";
  const char testURL1[] = "https://chromium.org/test_1";
  const char testURL2[] = "https://chromium.org/test_2";

  EXPECT_TRUE(web_state_list_.empty());

  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);
  AppendNewWebState(kURL3);

  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(0, true), 0);
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(1, true), 1);
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(2, true), 2);

  // Insert a WebState into pinned WebStates range.
  web_state_list_.InsertWebState(CreateWebState(testURL0),
                                 WebStateList::InsertionParams::AtIndex(0));
  // Expect a WebState to be added at the end of the WebStateList.
  EXPECT_EQ(web_state_list_.GetWebStateAt(4)->GetVisibleURL().spec(), testURL0);

  // Insert a WebState into pinned WebStates range.
  web_state_list_.InsertWebState(CreateWebState(testURL1),
                                 WebStateList::InsertionParams::AtIndex(2));
  // Expect a WebState to be added at the end of the WebStateList.
  EXPECT_EQ(web_state_list_.GetWebStateAt(5)->GetVisibleURL().spec(), testURL1);

  // Insert a WebState into pinned WebStates range.
  web_state_list_.InsertWebState(CreateWebState(testURL2),
                                 WebStateList::InsertionParams::AtIndex(1));
  // Expect a WebState to be added at the end of the WebStateList.
  EXPECT_EQ(web_state_list_.GetWebStateAt(6)->GetVisibleURL().spec(), testURL2);
}

// Tests InsertWebState method correctly updates insertion index when the params
// specify it should be pinned.
TEST_F(WebStateListTest, InsertWebState_InsertWebStatePinned) {
  const char testURL0[] = "https://chromium.org/test_0";
  const char testURL1[] = "https://chromium.org/test_1";
  const char testURL2[] = "https://chromium.org/test_2";

  EXPECT_TRUE(web_state_list_.empty());

  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);
  AppendNewWebState(kURL3);

  // Insert a pinned WebState without specifying an index.
  web_state_list_.InsertWebState(
      CreateWebState(testURL0),
      WebStateList::InsertionParams::Automatic().Pinned());
  // Expect a WebState to be added into pinned WebStates range.
  EXPECT_EQ(web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec(), testURL0);
  // Expect a WebState to be pinned.
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(0));

  // Insert a pinned WebState to the non-pinned WebStates range.
  web_state_list_.InsertWebState(
      CreateWebState(testURL1),
      WebStateList::InsertionParams::AtIndex(2).Pinned());
  // Expect a WebState to be added at the end of the pinned WebStates range.
  EXPECT_EQ(web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec(), testURL1);
  // Expect a WebState to be pinned.
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(1));

  // Insert a pinned WebState to the pinned WebStates range.
  web_state_list_.InsertWebState(
      CreateWebState(testURL2),
      WebStateList::InsertionParams::AtIndex(0).Pinned());
  // Expect a WebState to be added at the end of the pinned WebStates range.
  EXPECT_EQ(web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec(), testURL2);
  // Expect a WebState to be pinned.
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(0));

  // Final check that only first three WebStates were pinned.
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(0));
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(1));
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(2));
  EXPECT_FALSE(web_state_list_.IsWebStatePinnedAt(3));
}

// Tests MoveWebStateAt method moves the pinned WebStates within pinned
// WebStates range only.
TEST_F(WebStateListTest, MoveWebStateAt_KeepsPinnedWebStateWithinPinnedRange) {
  EXPECT_TRUE(web_state_list_.empty());

  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);
  AppendNewWebState(kURL3);

  // Pin first three WebStates.
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(0, true), 0);
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(1, true), 1);
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(2, true), 2);

  // Check the WebStates order.
  EXPECT_EQ(web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec(), kURL0);
  EXPECT_EQ(web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec(), kURL1);
  EXPECT_EQ(web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec(), kURL2);
  EXPECT_EQ(web_state_list_.GetWebStateAt(3)->GetVisibleURL().spec(), kURL3);

  // Try to move first pinned WebState contains of the pinned WebStates range.
  web_state_list_.MoveWebStateAt(0, 2);

  // Try to move first pinned WebState outside of the pinned WebStates range.
  web_state_list_.MoveWebStateAt(0, 3);

  // Expect the pinned WebStates to be moved within pinned WebStates range only.
  EXPECT_EQ(web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec(), kURL2);
  EXPECT_EQ(web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec(), kURL0);
  EXPECT_EQ(web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec(), kURL1);
  EXPECT_EQ(web_state_list_.GetWebStateAt(3)->GetVisibleURL().spec(), kURL3);
}

// Tests MoveWebStateAt method moves the non-pinned WebStates within non-pinned
// WebStates range only.
TEST_F(WebStateListTest,
       MoveWebStateAt_KeepsNonPinnedWebStatesWithinNonPinnedRange) {
  EXPECT_TRUE(web_state_list_.empty());

  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);
  AppendNewWebState(kURL3);

  // Pin first two WebStates.
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(0, true), 0);
  EXPECT_EQ(web_state_list_.SetWebStatePinnedAt(1, true), 1);

  // Check WebStates order.
  EXPECT_EQ(web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec(), kURL0);
  EXPECT_EQ(web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec(), kURL1);
  EXPECT_EQ(web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec(), kURL2);
  EXPECT_EQ(web_state_list_.GetWebStateAt(3)->GetVisibleURL().spec(), kURL3);

  // Try to move first non-pinned WebState inside of the non-pinned WebStates
  // range.
  web_state_list_.MoveWebStateAt(2, 3);

  // Try to move first non-pinned WebState to the pinned WebStates range.
  web_state_list_.MoveWebStateAt(2, 1);

  // Expect the non-pinned WebStates to be moved within non-pinned WebStates
  // range only.
  EXPECT_EQ(web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec(), kURL0);
  EXPECT_EQ(web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec(), kURL1);
  EXPECT_EQ(web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec(), kURL3);
  EXPECT_EQ(web_state_list_.GetWebStateAt(3)->GetVisibleURL().spec(), kURL2);
}

TEST_F(WebStateListTest, WebStateListDestroyed) {
  // Using a local WebStateList to observe its destruction.
  std::unique_ptr<WebStateList> web_state_list =
      std::make_unique<WebStateList>(&delegate_);
  observer_.Observe(web_state_list.get());
  EXPECT_FALSE(observer_.web_state_list_destroyed());
  web_state_list.reset();
  EXPECT_TRUE(observer_.web_state_list_destroyed());
}

TEST_F(WebStateListTest, WebStateListAsWeakPtr) {
  // Using a local WebStateList to observe its destruction.
  std::unique_ptr<WebStateList> web_state_list =
      std::make_unique<WebStateList>(&delegate_);
  base::WeakPtr<WebStateList> weak_web_state_list = web_state_list->AsWeakPtr();
  EXPECT_TRUE(weak_web_state_list);
  web_state_list.reset();
  EXPECT_FALSE(weak_web_state_list);
}

TEST_F(WebStateListTest, GetGroupOfUngroupedWebState) {
  EXPECT_TRUE(web_state_list_.empty());

  AppendNewWebState(kURL0);

  EXPECT_EQ(nullptr, web_state_list_.GetGroupOfWebStateAt(0));
}

TEST_F(WebStateListTest, InsertWebState_NoGroup) {
  EXPECT_TRUE(web_state_list_.empty());
  AppendNewWebState(kURL0);

  web_state_list_.InsertWebState(CreateWebState(kURL1));

  EXPECT_EQ(nullptr, web_state_list_.GetGroupOfWebStateAt(0));
  EXPECT_EQ(nullptr, web_state_list_.GetGroupOfWebStateAt(1));
}

TEST_F(WebStateListTest, MoveWebStateAt_NoGroup) {
  EXPECT_TRUE(web_state_list_.empty());
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);
  AppendNewWebState(kURL3);

  web_state_list_.MoveWebStateAt(1, 3);

  EXPECT_EQ(web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec(), kURL0);
  EXPECT_EQ(nullptr, web_state_list_.GetGroupOfWebStateAt(0));

  EXPECT_EQ(web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec(), kURL2);
  EXPECT_EQ(nullptr, web_state_list_.GetGroupOfWebStateAt(1));

  EXPECT_EQ(web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec(), kURL3);
  EXPECT_EQ(nullptr, web_state_list_.GetGroupOfWebStateAt(2));

  EXPECT_EQ(web_state_list_.GetWebStateAt(3)->GetVisibleURL().spec(), kURL1);
  EXPECT_EQ(nullptr, web_state_list_.GetGroupOfWebStateAt(3));
}

TEST_F(WebStateListTest, ReplaceWebStateAt_NoGroup) {
  EXPECT_TRUE(web_state_list_.empty());
  AppendNewWebState(kURL0);

  web_state_list_.ReplaceWebStateAt(0, CreateWebState(kURL1));

  EXPECT_EQ(web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec(), kURL1);
  EXPECT_EQ(nullptr, web_state_list_.GetGroupOfWebStateAt(0));
}

TEST_F(WebStateListTest, CreateGroup_OneTab) {
  EXPECT_TRUE(web_state_list_.empty());
  AppendNewWebState(kURL0);
  TabGroupVisualData visual_data =
      TabGroupVisualData(u"Group A", tab_groups::TabGroupColorId::kGrey);

  const TabGroup* group = web_state_list_.CreateGroup({0}, visual_data);

  EXPECT_EQ(1, web_state_list_.count());
  EXPECT_EQ(group, web_state_list_.GetGroupOfWebStateAt(0));
  EXPECT_EQ(WebStateList::Range(0, 1), web_state_list_.GetWebStates(group));
}

TEST_F(WebStateListTest, CreateGroup_SeveralTabs) {
  EXPECT_TRUE(web_state_list_.empty());
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);
  AppendNewWebState(kURL3);
  AppendNewWebState(kURL4);
  TabGroupVisualData visual_data =
      TabGroupVisualData(u"Group A", tab_groups::TabGroupColorId::kGrey);

  const TabGroup* group = web_state_list_.CreateGroup({0, 2, 4}, visual_data);

  EXPECT_EQ(5, web_state_list_.count());

  EXPECT_EQ(web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec(), kURL0);
  EXPECT_EQ(group, web_state_list_.GetGroupOfWebStateAt(0));

  EXPECT_EQ(web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec(), kURL2);
  EXPECT_EQ(group, web_state_list_.GetGroupOfWebStateAt(1));

  EXPECT_EQ(web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec(), kURL4);
  EXPECT_EQ(group, web_state_list_.GetGroupOfWebStateAt(2));

  EXPECT_EQ(web_state_list_.GetWebStateAt(3)->GetVisibleURL().spec(), kURL1);
  EXPECT_EQ(nullptr, web_state_list_.GetGroupOfWebStateAt(3));

  EXPECT_EQ(web_state_list_.GetWebStateAt(4)->GetVisibleURL().spec(), kURL3);
  EXPECT_EQ(nullptr, web_state_list_.GetGroupOfWebStateAt(4));

  EXPECT_EQ(WebStateList::Range(0, 3), web_state_list_.GetWebStates(group));
}

TEST_F(WebStateListTest, CreateGroup_SeveralTabs_SomePinned) {
  EXPECT_TRUE(web_state_list_.empty());
  AppendNewWebState(kURL0);
  web_state_list_.SetWebStatePinnedAt(0, true);
  AppendNewWebState(kURL1);
  web_state_list_.SetWebStatePinnedAt(1, true);
  AppendNewWebState(kURL2);
  web_state_list_.SetWebStatePinnedAt(2, true);
  AppendNewWebState(kURL3);
  AppendNewWebState(kURL4);
  TabGroupVisualData visual_data =
      TabGroupVisualData(u"Group A", tab_groups::TabGroupColorId::kGrey);

  const TabGroup* group = web_state_list_.CreateGroup({1, 3}, visual_data);

  EXPECT_EQ(5, web_state_list_.count());

  EXPECT_EQ(web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec(), kURL0);
  EXPECT_EQ(nullptr, web_state_list_.GetGroupOfWebStateAt(0));
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(0));

  EXPECT_EQ(web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec(), kURL2);
  EXPECT_EQ(nullptr, web_state_list_.GetGroupOfWebStateAt(1));
  EXPECT_TRUE(web_state_list_.IsWebStatePinnedAt(1));

  EXPECT_EQ(web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec(), kURL1);
  EXPECT_EQ(group, web_state_list_.GetGroupOfWebStateAt(2));
  EXPECT_FALSE(web_state_list_.IsWebStatePinnedAt(2));

  EXPECT_EQ(web_state_list_.GetWebStateAt(3)->GetVisibleURL().spec(), kURL3);
  EXPECT_EQ(group, web_state_list_.GetGroupOfWebStateAt(3));
  EXPECT_FALSE(web_state_list_.IsWebStatePinnedAt(3));

  EXPECT_EQ(web_state_list_.GetWebStateAt(4)->GetVisibleURL().spec(), kURL4);
  EXPECT_EQ(nullptr, web_state_list_.GetGroupOfWebStateAt(4));
  EXPECT_FALSE(web_state_list_.IsWebStatePinnedAt(4));

  EXPECT_EQ(WebStateList::Range(2, 2), web_state_list_.GetWebStates(group));
}

TEST_F(WebStateListTest, CreateGroup_SeveralTabs_SomeGrouped) {
  EXPECT_TRUE(web_state_list_.empty());
  AppendNewWebState(kURL0);
  AppendNewWebState(kURL1);
  AppendNewWebState(kURL2);
  AppendNewWebState(kURL3);
  AppendNewWebState(kURL4);
  TabGroupVisualData visual_data_a =
      TabGroupVisualData(u"Group A", tab_groups::TabGroupColorId::kGrey);
  const TabGroup* group_a =
      web_state_list_.CreateGroup({0, 1, 2}, visual_data_a);

  TabGroupVisualData visual_data_b =
      TabGroupVisualData(u"Group B", tab_groups::TabGroupColorId::kBlue);
  const TabGroup* group_b = web_state_list_.CreateGroup({1, 3}, visual_data_b);

  EXPECT_EQ(5, web_state_list_.count());

  EXPECT_EQ(web_state_list_.GetWebStateAt(0)->GetVisibleURL().spec(), kURL0);
  EXPECT_EQ(group_a, web_state_list_.GetGroupOfWebStateAt(0));

  EXPECT_EQ(web_state_list_.GetWebStateAt(1)->GetVisibleURL().spec(), kURL2);
  EXPECT_EQ(group_a, web_state_list_.GetGroupOfWebStateAt(1));

  EXPECT_EQ(web_state_list_.GetWebStateAt(2)->GetVisibleURL().spec(), kURL1);
  EXPECT_EQ(group_b, web_state_list_.GetGroupOfWebStateAt(2));

  EXPECT_EQ(web_state_list_.GetWebStateAt(3)->GetVisibleURL().spec(), kURL3);
  EXPECT_EQ(group_b, web_state_list_.GetGroupOfWebStateAt(3));

  EXPECT_EQ(web_state_list_.GetWebStateAt(4)->GetVisibleURL().spec(), kURL4);
  EXPECT_EQ(nullptr, web_state_list_.GetGroupOfWebStateAt(4));

  EXPECT_EQ(WebStateList::Range(0, 2), web_state_list_.GetWebStates(group_a));
  EXPECT_EQ(WebStateList::Range(2, 2), web_state_list_.GetWebStates(group_b));
}
