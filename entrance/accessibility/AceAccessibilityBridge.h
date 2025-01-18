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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACCESSIBILITY_ACCESSIBILITYBRIDGE_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACCESSIBILITY_ACCESSIBILITYBRIDGE_H

#include "adapter/ios/osal/accessibility_manager_impl.h"

using namespace OHOS::Ace::Framework;

bool ExecuteActionOC(
    const int windowId, const std::shared_ptr<AccessibilityManagerImpl::InteractionOperation>& interactionOperation);
void UpdateNodesOC(
    const std::list<OHOS::Accessibility::AccessibilityElementInfo>& infos, const int windowId, const size_t eventType);
void SendAccessibilityEventOC(const int64_t elementId, const int windowId, const size_t eventType);
bool SubscribeState(
    const int windowId, const std::shared_ptr<AccessibilityManagerImpl::AccessibilityStateObserver>& stateObserver);
void UnSubscribeState(const int windowId);
int32_t GetAccessibilityElementActionTypes(const OHOS::Accessibility::AccessibilityElementInfo& info);

#endif // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACCESSIBILITY_ACCESSIBILITYBRIDGE_H
