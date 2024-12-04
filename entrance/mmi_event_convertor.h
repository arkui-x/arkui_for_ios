/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_MMI_EVENT_CONVERTOR_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_MMI_EVENT_CONVERTOR_H


#include "pointer_event.h"

#include "base/geometry/ng/offset_t.h"
#include "base/geometry/ng/vector.h"
#include "base/utils/macros.h"
#include "core/event/touch_event.h"
#include "core/event/pointer_event.h"

namespace OHOS::Ace::Platform {
namespace {
const std::unordered_map<SourceType, int32_t> SOURCE_TYPE_MAP = {
    { SourceType::TOUCH, MMI::PointerEvent::SOURCE_TYPE_TOUCHSCREEN },
    { SourceType::TOUCH_PAD, MMI::PointerEvent::SOURCE_TYPE_TOUCHPAD },
    { SourceType::MOUSE, MMI::PointerEvent::SOURCE_TYPE_MOUSE },
};

const std::unordered_map<TouchType, int32_t> TOUCH_TYPE_MAP = {
    { TouchType::CANCEL, MMI::PointerEvent::POINTER_ACTION_CANCEL },
    { TouchType::DOWN, MMI::PointerEvent::POINTER_ACTION_DOWN },
    { TouchType::MOVE, MMI::PointerEvent::POINTER_ACTION_MOVE },
    { TouchType::UP, MMI::PointerEvent::POINTER_ACTION_UP },
    { TouchType::PULL_DOWN, MMI::PointerEvent::POINTER_ACTION_PULL_DOWN },
    { TouchType::PULL_MOVE, MMI::PointerEvent::POINTER_ACTION_PULL_MOVE },
    { TouchType::PULL_UP, MMI::PointerEvent::POINTER_ACTION_PULL_UP },
    { TouchType::PULL_IN_WINDOW, MMI::PointerEvent::POINTER_ACTION_PULL_IN_WINDOW },
    { TouchType::PULL_OUT_WINDOW, MMI::PointerEvent::POINTER_ACTION_PULL_OUT_WINDOW },
};
} // namespace

template<typename E>
void GetEventDevice(int32_t sourceType, E& event)
{
    switch (sourceType) {
        case OHOS::MMI::PointerEvent::SOURCE_TYPE_TOUCHSCREEN:
            event.sourceType = SourceType::TOUCH;
            break;
        case OHOS::MMI::PointerEvent::SOURCE_TYPE_TOUCHPAD:
            event.sourceType = SourceType::TOUCH_PAD;
            break;
        case OHOS::MMI::PointerEvent::SOURCE_TYPE_MOUSE:
            event.sourceType = SourceType::MOUSE;
            break;
        default:
            event.sourceType = SourceType::NONE;
            break;
    }
}

void ConvertPointerEvent(const std::shared_ptr<MMI::PointerEvent>& pointerEvent, DragPointerEvent& event);
void ConvertTouchEvent(const std::shared_ptr<MMI::PointerEvent>& pointerEvent, std::vector<TouchEvent>& events);
TouchEvent ConvertTouchEvent(const std::shared_ptr<MMI::PointerEvent>& pointerEvent);
TouchPoint ConvertTouchPoint(const MMI::PointerEvent::PointerItem& pointerItem);
void LogPointInfo(const std::shared_ptr<MMI::PointerEvent>& pointerEvent, int32_t instanceId);
void ConvertMmiPointerEvent(std::shared_ptr<MMI::PointerEvent>& pointerEvent, const std::vector<uint8_t>& data);
void ConvertMmiPointerEvent(
    std::vector<std::shared_ptr<MMI::PointerEvent>>& pointerEvents, const std::vector<uint8_t>& data);
} // namespace OHOS::Ace::Platform

#endif // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_MMI_EVENT_CONVERTOR_H
