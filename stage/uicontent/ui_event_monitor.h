/*
 * Copyright (c) 2023-2026 Huawei Device Co., Ltd.
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
#ifndef FOUNDATION_ACE_ADAPTER_IOS_STAGE_UI_EVENT_MONITOR_H
#define FOUNDATION_ACE_ADAPTER_IOS_STAGE_UI_EVENT_MONITOR_H

#include <atomic>
#include <cstdint>
#include <memory>
#include <vector>

#include "core/accessibility/accessibility_manager.h"
#include "core/accessibility/accessibility_utils.h"

namespace OHOS::Ace::Platform {

class UiEventMonitor : public std::enable_shared_from_this<UiEventMonitor> {
public:
    static std::shared_ptr<UiEventMonitor> Create()
    {
        struct MakeSharedEnabler : public UiEventMonitor {
            MakeSharedEnabler() : UiEventMonitor() {}
        };
        return std::make_shared<MakeSharedEnabler>();
    }

    ~UiEventMonitor();

    inline static const std::vector<uint32_t> EVENT_MASK = {
        static_cast<uint32_t>(OHOS::Ace::AccessibilityEventType::TEXT_CHANGE),
        static_cast<uint32_t>(OHOS::Ace::AccessibilityEventType::PAGE_CHANGE),
        static_cast<uint32_t>(OHOS::Ace::AccessibilityEventType::CHANGE),
        static_cast<uint32_t>(OHOS::Ace::AccessibilityEventType::SCROLL_END),
        static_cast<uint32_t>(OHOS::Ace::AccessibilityEventType::PAGE_OPEN),
    };

    void Init();
    void OnAccessibilityEvent(const OHOS::Ace::AccessibilityEvent& accessibilityEvent);
    bool WaitEventIdle(uint32_t idleThresholdMs, uint32_t timeoutMs);
    uint64_t GetLastEventMillis();
    void ResetEventTimer();

private:
    UiEventMonitor();

    static uint64_t GetCurrentMillisecond();

    std::atomic<uint64_t> lastEventMillis_ { 0 };
    std::atomic<int32_t> activeScrollCount_ { 0 };
};

} // namespace OHOS::Ace::Platform

#endif // FOUNDATION_ACE_ADAPTER_IOS_STAGE_UI_EVENT_MONITOR_H
