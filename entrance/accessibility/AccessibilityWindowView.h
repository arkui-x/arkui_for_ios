/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACCESSIBILITY_ACCESSIBILITYWINDOWVIEW_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACCESSIBILITY_ACCESSIBILITYWINDOWVIEW_H

#import <UIKit/UIKit.h>
#import "AccessibilityElement.h"
#import "AccessibilityNodeInfo.h"
#import "foundation/arkui/ace_engine/adapter/ios/entrance/WindowView.h"

@interface AccessibilityWindowView : WindowView

- (AccessibilityElement*)GetOrCreateObject:(int64_t)elementId;
- (AccessibilityElement*)CreateObject;
- (void)UpdateAccessibilityNodes:(NSMutableDictionary*)dictNodeInfo eventType:(size_t)eventType;
- (void)UpdateAccessibilityNodesWithElementId:(AccessibilityNodeInfo*)nodeInfo;
- (void)ExecuteAction:(void (^)(const int64_t elementId, const int32_t action, NSDictionary* actionDic))callback;
- (void)RequestUpdate:(void (^)(const int64_t elementId))callback;
- (bool)SubscribeState:(void (^)(bool state))block;
- (void)UnSubscribeState;
- (void)SendAccessibilityEvent:(int64_t)elementId eventType:(size_t)eventType;
- (void)UpdateAccessibilityValue:(int64_t)elementId info:(AccessibilityNodeInfo*)info;
- (int)IsViewOffscreenTopOrBottom:(int64_t)elementId;

@end
#endif // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACCESSIBILITY_ACCESSIBILITYWINDOWVIEW_H
