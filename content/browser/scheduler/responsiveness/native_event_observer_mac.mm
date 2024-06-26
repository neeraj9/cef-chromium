// Copyright 2018 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "content/browser/scheduler/responsiveness/native_event_observer.h"

#import <AppKit/AppKit.h>

#import "content/public/browser/native_event_processor_mac.h"

namespace content::responsiveness {

void NativeEventObserver::RegisterObserver() {
  if (![NSApp conformsToProtocol:@protocol(NativeEventProcessor)])
    return;
  id<NativeEventProcessor> processor =
      static_cast<id<NativeEventProcessor>>(NSApp);
  [processor addNativeEventProcessorObserver:this];
}
void NativeEventObserver::DeregisterObserver() {
  if (![NSApp conformsToProtocol:@protocol(NativeEventProcessor)])
    return;
  id<NativeEventProcessor> processor =
      static_cast<id<NativeEventProcessor>>(NSApp);
  [processor removeNativeEventProcessorObserver:this];
}

void NativeEventObserver::WillRunNativeEvent(const void* opaque_identifier) {
  will_run_event_callback_.Run(opaque_identifier);
}
void NativeEventObserver::DidRunNativeEvent(const void* opaque_identifier) {
  did_run_event_callback_.Run(opaque_identifier);
}

}  // namespace content::responsiveness
