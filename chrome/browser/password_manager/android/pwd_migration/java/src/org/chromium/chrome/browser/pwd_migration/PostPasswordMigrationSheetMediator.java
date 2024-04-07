// Copyright 2024 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package org.chromium.chrome.browser.pwd_migration;

import static org.chromium.chrome.browser.pwd_migration.PostPasswordMigrationSheetProperties.VISIBLE;

import org.chromium.components.browser_ui.bottomsheet.BottomSheetController.StateChangeReason;
import org.chromium.ui.modelutil.PropertyModel;

/**
 * Contains the logic for the post password migration sheet. It sets the state of the model and
 * reacts to events.
 */
class PostPasswordMigrationSheetMediator {
    private PropertyModel mModel;

    void initialize(PropertyModel model) {
        mModel = model;
    }

    void showSheet() {
        mModel.set(VISIBLE, true);
    }

    void onDismissed(@StateChangeReason int reason) {
        if (!mModel.get(VISIBLE)) return; // Dismiss only if not dismissed yet.
        mModel.set(VISIBLE, false);
    }

    PropertyModel getModel() {
        return mModel;
    }
}
