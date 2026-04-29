/*
 * Copyright (c) 2024-2026 Huawei Device Co., Ltd.
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

#include "mmi_event_convertor.h"

#include <atomic>
#include <limits>
#include <memory>
#include <mutex>
#include <unordered_map>

#include "ace_pointer_data_packet.h"
#include "base/utils/time_util.h"
#include "base/utils/utils.h"
#include "core/event/ace_events.h"
#include "core/pipeline/pipeline_base.h"
#include "base/log/log.h"
#include "adapter/ios/entrance/interaction/interaction_impl.h"

namespace OHOS::Ace::Platform {
namespace {
constexpr int32_t ANGLE_0 = 0;
constexpr int32_t ANGLE_90 = 90;
constexpr int32_t ANGLE_180 = 180;
constexpr int32_t ANGLE_270 = 270;
constexpr double SIZE_DIVIDE = 2.0;
constexpr size_t MAX_SYNTHETIC_DOWN_TIME_MAP_SIZE = 64;
constexpr uint32_t SYNTHETIC_DOWN_TIME_CLEANUP_INTERVAL = 32;
constexpr int64_t STALE_SYNTHETIC_DOWN_TIME_TIMEOUT_US = 60LL * 1000 * 1000;

struct SyntheticDownTimeEntry {
    int64_t downTime = 0;
    int64_t lastAccessTime = 0;
};

std::unordered_map<int32_t, SyntheticDownTimeEntry> syntheticDownTimeMap;
std::atomic<uint32_t> g_syntheticDownTimeCleanupTick { 0 };
std::mutex g_syntheticDownTimeMapMutex;
std::mutex g_actionPointMapMutex;

bool ShouldCleanStaleSyntheticDownTimeEntries()
{
    const auto tick = g_syntheticDownTimeCleanupTick.fetch_add(1, std::memory_order_relaxed) + 1;
    return (tick % SYNTHETIC_DOWN_TIME_CLEANUP_INTERVAL) == 0;
}

void CleanStaleSyntheticDownTimeEntries(int64_t currentTime)
{
    for (auto iter = syntheticDownTimeMap.begin(); iter != syntheticDownTimeMap.end();) {
        if (currentTime - iter->second.lastAccessTime > STALE_SYNTHETIC_DOWN_TIME_TIMEOUT_US) {
            LOGW("clean stale synthetic down time entry, pointerId=%{public}d", iter->first);
            iter = syntheticDownTimeMap.erase(iter);
            continue;
        }
        ++iter;
    }
}

void CleanOldestSyntheticDownTimeEntry()
{
    if (syntheticDownTimeMap.empty()) {
        return;
    }

    auto oldestIter = syntheticDownTimeMap.begin();
    auto oldestAccessTime = oldestIter->second.lastAccessTime;
    for (auto iter = std::next(syntheticDownTimeMap.begin()); iter != syntheticDownTimeMap.end(); ++iter) {
        if (iter->second.lastAccessTime < oldestAccessTime) {
            oldestIter = iter;
            oldestAccessTime = iter->second.lastAccessTime;
        }
    }
    LOGW("clean oldest synthetic down time entry due to capacity limit, pointerId=%{public}d", oldestIter->first);
    syntheticDownTimeMap.erase(oldestIter);
}
} // namespace

static std::unordered_map<int32_t, bool> actionPointMap;

bool IsActionPoint(int32_t pointerId)
{
    std::lock_guard<std::mutex> lock(g_actionPointMapMutex);
    auto iter = actionPointMap.find(pointerId);
    return iter != actionPointMap.end() && iter->second;
}

void SetActionPoint(int32_t pointerId, bool actionPoint)
{
    std::lock_guard<std::mutex> lock(g_actionPointMapMutex);
    actionPointMap[pointerId] = actionPoint;
}

int64_t ResolveSyntheticDownTime(const AcePointerData& pointerData)
{
    std::lock_guard<std::mutex> lock(g_syntheticDownTimeMapMutex);
    const auto pointerId = static_cast<int32_t>(pointerData.pointer_id);
    const auto action = pointerData.pointer_action;
    const auto currentTime = pointerData.time_stamp;
    auto iter = syntheticDownTimeMap.find(pointerId);
    int64_t downTime = pointerData.time_stamp;

    if (action == AcePointerData::PointerAction::kDowned) {
        if (iter != syntheticDownTimeMap.end()) {
            LOGW("duplicate synthetic DOWN, pointerId=%{public}d", pointerId);
            iter->second.downTime = currentTime;
            iter->second.lastAccessTime = currentTime;
            return currentTime;
        }
        if (ShouldCleanStaleSyntheticDownTimeEntries()) {
            CleanStaleSyntheticDownTimeEntries(currentTime);
        }
        if (iter == syntheticDownTimeMap.end()) {
            while (syntheticDownTimeMap.size() >= MAX_SYNTHETIC_DOWN_TIME_MAP_SIZE) {
                CleanOldestSyntheticDownTimeEntry();
            }
        }
        syntheticDownTimeMap[pointerId] = { currentTime, currentTime };
        return currentTime;
    }

    if (iter != syntheticDownTimeMap.end()) {
        downTime = iter->second.downTime;
        iter->second.lastAccessTime = currentTime;
    }

    if (action == AcePointerData::PointerAction::kUped || action == AcePointerData::PointerAction::kCanceled) {
        syntheticDownTimeMap.erase(pointerId);
    }
    return downTime;
}

SourceTool GetSourceTool(int32_t orgToolType)
{
    switch (orgToolType) {
        case MMI::PointerEvent::TOOL_TYPE_FINGER:
            return SourceTool::FINGER;
        case MMI::PointerEvent::TOOL_TYPE_PEN:
            return SourceTool::PEN;
        case MMI::PointerEvent::TOOL_TYPE_RUBBER:
            return SourceTool::RUBBER;
        case MMI::PointerEvent::TOOL_TYPE_BRUSH:
            return SourceTool::BRUSH;
        case MMI::PointerEvent::TOOL_TYPE_PENCIL:
            return SourceTool::PENCIL;
        case MMI::PointerEvent::TOOL_TYPE_AIRBRUSH:
            return SourceTool::AIRBRUSH;
        case MMI::PointerEvent::TOOL_TYPE_MOUSE:
            return SourceTool::MOUSE;
        case MMI::PointerEvent::TOOL_TYPE_LENS:
            return SourceTool::LENS;
        case MMI::PointerEvent::TOOL_TYPE_TOUCHPAD:
            return SourceTool::TOUCHPAD;
        default:
            LOGW("unknown tool type");
            return SourceTool::UNKNOWN;
    }
}

void SetTouchEventType(int32_t orgAction, TouchEvent& event)
{
    switch (orgAction) {
        case MMI::PointerEvent::POINTER_ACTION_CANCEL:
            event.type = TouchType::CANCEL;
            break;
        case MMI::PointerEvent::POINTER_ACTION_DOWN:
            event.type = TouchType::DOWN;
            break;
        case MMI::PointerEvent::POINTER_ACTION_MOVE:
            event.type = TouchType::MOVE;
            break;
        case MMI::PointerEvent::POINTER_ACTION_UP:
            event.type = TouchType::UP;
            break;
        case MMI::PointerEvent::POINTER_ACTION_PULL_DOWN:
            event.type = TouchType::PULL_DOWN;
            event.pullType = TouchType::PULL_DOWN;
            break;
        case MMI::PointerEvent::POINTER_ACTION_PULL_MOVE:
            event.type = TouchType::PULL_MOVE;
            event.pullType = TouchType::PULL_MOVE;
            break;
        case MMI::PointerEvent::POINTER_ACTION_PULL_UP:
            event.type = TouchType::PULL_UP;
            event.pullType = TouchType::PULL_UP;
            break;
        case MMI::PointerEvent::POINTER_ACTION_PULL_IN_WINDOW:
            event.type = TouchType::PULL_IN_WINDOW;
            event.pullType = TouchType::PULL_IN_WINDOW;
            break;
        case MMI::PointerEvent::POINTER_ACTION_PULL_OUT_WINDOW:
            event.type = TouchType::PULL_OUT_WINDOW;
            event.pullType = TouchType::PULL_OUT_WINDOW;
            break;
        case MMI::PointerEvent::POINTER_ACTION_HOVER_ENTER:
            event.type = TouchType::HOVER_ENTER;
            break;
        case MMI::PointerEvent::POINTER_ACTION_HOVER_MOVE:
            event.type = TouchType::HOVER_MOVE;
            break;
        case MMI::PointerEvent::POINTER_ACTION_HOVER_EXIT:
            event.type = TouchType::HOVER_EXIT;
            break;
        default:
            LOGW("unknown type");
            break;
    }
}

void FillDragPointerEvent(const std::shared_ptr<MMI::PointerEvent>& pointerEvent, DragPointerEvent& event)
{
    event.rawPointerEvent = pointerEvent;
    event.pointerId = pointerEvent->GetPointerId();
    MMI::PointerEvent::PointerItem pointerItem;
    pointerEvent->GetPointerItem(pointerEvent->GetPointerId(), pointerItem);
    event.pressed = pointerItem.IsPressed();
    event.windowX = pointerItem.GetWindowX();
    event.windowY = pointerItem.GetWindowY();
    event.displayX = pointerItem.GetDisplayX();
    event.displayY = pointerItem.GetDisplayY();
    event.size = std::max(pointerItem.GetWidth(), pointerItem.GetHeight()) / SIZE_DIVIDE;
    event.force = static_cast<float>(pointerItem.GetPressure());
    event.deviceId = pointerItem.GetDeviceId();
    event.downTime = TimeStamp(std::chrono::microseconds(pointerItem.GetDownTime()));
    event.time = TimeStamp(std::chrono::microseconds(pointerEvent->GetActionTime()));
    event.sourceTool = GetSourceTool(pointerItem.GetToolType());
    event.targetWindowId = pointerItem.GetTargetWindowId();
}

void ConvertPointerEvent(const std::shared_ptr<MMI::PointerEvent>& pointerEvent, DragPointerEvent& event)
{
#ifdef ENABLE_DRAG_FRAMEWORK
    Ace::DragState dragState;
    auto interactionImpl = static_cast<Ace::InteractionImpl*>(Ace::InteractionInterface::GetInstance());
    Ace::InteractionInterface::GetInstance()->GetDragState(dragState);
    if (dragState == Ace::DragState::START &&
        interactionImpl->GetPointerId() == pointerEvent->GetPointerId()) {
        interactionImpl->UpdatePointAction(pointerEvent);
    }
#endif
    FillDragPointerEvent(pointerEvent, event);
}

void ConvertSyntheticPointerEvent(const std::shared_ptr<MMI::PointerEvent>& pointerEvent, DragPointerEvent& event)
{
#ifdef ENABLE_DRAG_FRAMEWORK
    Ace::DragState dragState;
    auto interactionImpl = static_cast<Ace::InteractionImpl*>(Ace::InteractionInterface::GetInstance());
    Ace::InteractionInterface::GetInstance()->GetDragState(dragState);
    if (dragState == Ace::DragState::START &&
        interactionImpl->GetPointerId() == pointerEvent->GetPointerId()) {
        interactionImpl->UpdateSyntheticPointAction(pointerEvent);
    }
#endif
    FillDragPointerEvent(pointerEvent, event);
}

void UpdateTouchEvent(std::vector<TouchEvent>& events)
{
    if (events.empty()) {
        return;
    }
    std::vector<TouchPoint> pointers;
    for (auto& event : events) {
        TouchPoint touchPoint;
        touchPoint.size = event.size;
        touchPoint.id = event.id;
        touchPoint.force = event.force;
        touchPoint.downTime = event.time;
        touchPoint.x = event.x;
        touchPoint.y = event.y;
        touchPoint.screenX = event.screenX;
        touchPoint.screenY = event.screenY;
        touchPoint.isPressed = (event.type == TouchType::DOWN);
        pointers.emplace_back(std::move(touchPoint));
    }
    for (auto& evt : events) {
        std::copy(pointers.begin(), pointers.end(), std::back_inserter(evt.pointers));
    } 
}

TouchPoint ConvertTouchPoint(const MMI::PointerEvent::PointerItem& pointerItem)
{
    TouchPoint touchPoint;
    // just get the max of width and height
    touchPoint.size = std::max(pointerItem.GetWidth(), pointerItem.GetHeight()) / SIZE_DIVIDE;
    touchPoint.id = pointerItem.GetPointerId();
    touchPoint.downTime = TimeStamp(std::chrono::microseconds(pointerItem.GetDownTime()));
    touchPoint.x = pointerItem.GetWindowX();
    touchPoint.y = pointerItem.GetWindowY();
    touchPoint.screenX = pointerItem.GetDisplayX();
    touchPoint.screenY = pointerItem.GetDisplayY();
    touchPoint.isPressed = pointerItem.IsPressed();
    touchPoint.force = static_cast<float>(pointerItem.GetPressure());
    touchPoint.tiltX = pointerItem.GetTiltX();
    touchPoint.tiltY = pointerItem.GetTiltY();
    touchPoint.sourceTool = static_cast<SourceTool>(pointerItem.GetToolType());
    return touchPoint;
}

void UpdateTouchEvent(const std::shared_ptr<MMI::PointerEvent>& pointerEvent, TouchEvent& touchEvent)
{
    auto ids = pointerEvent->GetPointerIds();
    for (auto&& id : ids) {
        MMI::PointerEvent::PointerItem item;
        bool ret = pointerEvent->GetPointerItem(id, item);
        if (!ret) {
            LOGE("get pointer item failed.");
            continue;
        }
        auto touchPoint = ConvertTouchPoint(item);
        touchEvent.pointers.emplace_back(std::move(touchPoint));
    }
    touchEvent.CovertId();
}

using namespace OHOS::Ace::Platform;
void SetPointerEventAction(AcePointerData::PointerAction change, std::shared_ptr<MMI::PointerEvent>& pointerEvent){
    switch (change) {
        case AcePointerData::PointerAction::kCanceled:
            pointerEvent->SetPointerAction(OHOS::MMI::PointerEvent::POINTER_ACTION_CANCEL);
            break;
        case AcePointerData::PointerAction::kAdded:
        case AcePointerData::PointerAction::kRemoved:
        case AcePointerData::PointerAction::kHovered:
            break;
        case AcePointerData::PointerAction::kDowned:
                pointerEvent->SetPointerAction(OHOS::MMI::PointerEvent::POINTER_ACTION_DOWN);
            break;
        case AcePointerData::PointerAction::kMoved:
                pointerEvent->SetPointerAction(OHOS::MMI::PointerEvent::POINTER_ACTION_MOVE);
            break;
        case AcePointerData::PointerAction::kUped:
                pointerEvent->SetPointerAction(OHOS::MMI::PointerEvent::POINTER_ACTION_UP);
            break;
    }
}

static int32_t SourceTypeFromToolType(AcePointerData::ToolType tool_type) {
    switch (tool_type) {
        case AcePointerData::ToolType::Touch:
            return OHOS::MMI::PointerEvent::TOOL_TYPE_FINGER;
        case AcePointerData::ToolType::Mouse:
            return OHOS::MMI::PointerEvent::TOOL_TYPE_MOUSE;
        case AcePointerData::ToolType::Stylus:
            return OHOS::MMI::PointerEvent::TOOL_TYPE_PEN;
        default:
        break;
    }
    return OHOS::MMI::PointerEvent::TOOL_TYPE_FINGER;
}

void SetPointerItemPressed(AcePointerData::PointerAction pointerAction, MMI::PointerEvent::PointerItem& pointerItem)
{
    switch (pointerAction) {
        case AcePointerData::PointerAction::kCanceled:
        case AcePointerData::PointerAction::kUped:
            pointerItem.SetPressed(false);
            break;
        case AcePointerData::PointerAction::kAdded:
        case AcePointerData::PointerAction::kRemoved:
        case AcePointerData::PointerAction::kHovered:
        case AcePointerData::PointerAction::kDowned:
        case AcePointerData::PointerAction::kMoved:
            pointerItem.SetPressed(true);
            break;
        default:
            pointerItem.SetPressed(false);
            break;
    }
}

void ConvertTouchEvent(const std::shared_ptr<MMI::PointerEvent>& pointerEvent, std::vector<TouchEvent>& events)
{
    auto ids = pointerEvent->GetPointerIds();
    for (auto&& point_id : ids) {
        MMI::PointerEvent::PointerItem item;
        bool ret = pointerEvent->GetPointerItem(point_id, item);
        if (!ret) {
            LOGE("get pointer item failed.");
            continue;
        }
        if (item.GetDeviceId() == -1) {
            LOGE("get device Id: -1");
            continue;
        }
        if (!IsActionPoint(item.GetPointerId())) {
            LOGE("not action point");
            continue;
        }
        TouchEvent event;
        event.SetId(item.GetPointerId())
            .SetX(item.GetWindowX())
            .SetY(item.GetWindowY())
            .SetScreenX(item.GetDisplayX())
            .SetScreenY(item.GetDisplayY())
            .SetType(TouchType::UNKNOWN)
            .SetPullType(TouchType::UNKNOWN)
            .SetTime(TimeStamp(std::chrono::microseconds(item.GetDownTime())))
            .SetSize(pointerEvent->GetFingerCount())
            .SetSourceType(SourceType::TOUCH);
        event.pointerEvent = pointerEvent;
        int32_t orgAction = pointerEvent->GetPointerAction();
        SetTouchEventType(orgAction, event);
        events.emplace_back(event);
    }
    UpdateTouchEvent(events);
}

void ConvertSyntheticTouchEvent(const std::shared_ptr<MMI::PointerEvent>& pointerEvent, std::vector<TouchEvent>& events)
{
    auto ids = pointerEvent->GetPointerIds();
    for (auto&& point_id : ids) {
        MMI::PointerEvent::PointerItem item;
        bool ret = pointerEvent->GetPointerItem(point_id, item);
        if (!ret) {
            LOGE("get pointer item failed.");
            continue;
        }
        if (item.GetDeviceId() == -1) {
            LOGE("get device Id: -1");
            continue;
        }
        if (!IsActionPoint(item.GetPointerId())) {
            LOGE("not action point");
            continue;
        }
        TouchEvent event;
        event.SetId(item.GetPointerId())
            .SetX(item.GetWindowX())
            .SetY(item.GetWindowY())
            .SetScreenX(item.GetDisplayX())
            .SetScreenY(item.GetDisplayY())
            .SetType(TouchType::UNKNOWN)
            .SetPullType(TouchType::UNKNOWN)
            .SetTime(TimeStamp(std::chrono::microseconds(pointerEvent->GetActionTime())))
            .SetSize(pointerEvent->GetFingerCount())
            .SetSourceType(SourceType::TOUCH);
        event.pointerEvent = pointerEvent;
        int32_t orgAction = pointerEvent->GetPointerAction();
        SetTouchEventType(orgAction, event);
        events.emplace_back(event);
    }
    UpdateTouchEvent(events);
}

TouchEvent ConvertTouchEvent(const std::shared_ptr<MMI::PointerEvent>& pointerEvent)
{
    auto point_id = pointerEvent->GetPointerId();
    MMI::PointerEvent::PointerItem item;
    bool ret = pointerEvent->GetPointerItem(point_id, item);
    if (!ret) {
        LOGE("get pointer item failed.");
        return TouchEvent();
    }
    if (item.GetDeviceId() == -1) {
        LOGE("get device Id: -1");
        return TouchEvent();
    }
    if (!IsActionPoint(item.GetPointerId())) {
        LOGE("not action point");
        return TouchEvent();
    }
    TouchEvent event;
    event.SetId(item.GetPointerId())
        .SetX(item.GetWindowX())
        .SetY(item.GetWindowY())
        .SetScreenX(item.GetDisplayX())
        .SetScreenY(item.GetDisplayY())
        .SetType(TouchType::UNKNOWN)
        .SetPullType(TouchType::UNKNOWN)
        .SetTime(TimeStamp(std::chrono::microseconds(item.GetDownTime())))
        .SetSize(pointerEvent->GetFingerCount())
        .SetSourceType(SourceType::TOUCH);
    event.pointerEvent = pointerEvent;
    int32_t orgAction = pointerEvent->GetPointerAction();
    SetTouchEventType(orgAction, event);
    UpdateTouchEvent(pointerEvent, event);
    return event;
}

TouchEvent ConvertSyntheticTouchEvent(const std::shared_ptr<MMI::PointerEvent>& pointerEvent)
{
    auto point_id = pointerEvent->GetPointerId();
    MMI::PointerEvent::PointerItem item;
    bool ret = pointerEvent->GetPointerItem(point_id, item);
    if (!ret) {
        LOGE("get pointer item failed.");
        return TouchEvent();
    }
    if (item.GetDeviceId() == -1) {
        LOGE("get device Id: -1");
        return TouchEvent();
    }
    if (!IsActionPoint(item.GetPointerId())) {
        LOGE("not action point");
        return TouchEvent();
    }
    TouchEvent event;
    event.SetId(item.GetPointerId())
        .SetX(item.GetWindowX())
        .SetY(item.GetWindowY())
        .SetScreenX(item.GetDisplayX())
        .SetScreenY(item.GetDisplayY())
        .SetType(TouchType::UNKNOWN)
        .SetPullType(TouchType::UNKNOWN)
        .SetTime(TimeStamp(std::chrono::microseconds(pointerEvent->GetActionTime())))
        .SetSize(pointerEvent->GetFingerCount())
        .SetSourceType(SourceType::TOUCH);
    event.pointerEvent = pointerEvent;
    int32_t orgAction = pointerEvent->GetPointerAction();
    SetTouchEventType(orgAction, event);
    UpdateTouchEvent(pointerEvent, event);
    return event;
}

void LogPointInfo(const std::shared_ptr<MMI::PointerEvent>& pointerEvent, int32_t instanceId)
{
    if (SystemProperties::GetDebugEnabled()) {
        LOGI("point source: %{public}d", pointerEvent->GetSourceType());
        auto actionId = pointerEvent->GetPointerId();
        MMI::PointerEvent::PointerItem item;
        if (pointerEvent->GetPointerItem(actionId, item)) {
            LOGI("action point info: id: %{public}d, x: %{public}d, y: %{public}d, action: %{public}d, pressure: "
                "%{public}f, tiltX: %{public}f, tiltY: %{public}f",
                actionId, item.GetWindowX(), item.GetWindowY(), pointerEvent->GetPointerAction(), item.GetPressure(),
                item.GetTiltX(), item.GetTiltY());
        }
        auto ids = pointerEvent->GetPointerIds();
        for (auto&& id : ids) {
            MMI::PointerEvent::PointerItem item;
            if (pointerEvent->GetPointerItem(id, item)) {
                LOGI("all point info: id: %{public}d, x: %{public}d, y: %{public}d, isPressed: %{public}d, pressure: "
                     "%{public}f, tiltX: %{public}f, tiltY: %{public}f",
                    actionId, item.GetWindowX(), item.GetWindowY(), item.IsPressed(), item.GetPressure(),
                    item.GetTiltX(), item.GetTiltY());
            }
        }
    }
}

void ConvertMmiPointerEvent(std::shared_ptr<MMI::PointerEvent>& pointerEvent, const std::vector<uint8_t>& data)
{
    const auto* origin = reinterpret_cast<const AcePointerData*>(data.data());
    size_t size = data.size() / sizeof(AcePointerData);
    auto current = const_cast<AcePointerData*>(origin);
    auto end = current + size;
    pointerEvent->SetPointerId(static_cast<int32_t>(current->pointer_id));
    pointerEvent->SetDeviceId(static_cast<int32_t>(current->device_id));
    pointerEvent->SetTargetDisplayId(0);
    pointerEvent->SetActionTime(current->time_stamp);
    pointerEvent->SetFingerCount(current->finger_count);
    SetPointerEventAction(current->pointer_action, pointerEvent);
    while (current < end)
    {
        OHOS::MMI::PointerEvent::PointerItem pointerItem;
        pointerItem.SetPointerId(static_cast<int32_t>(current->pointer_id));
        pointerItem.SetDeviceId(static_cast<int32_t>(current->device_id));
        pointerItem.SetDownTime(current->time_stamp);
        pointerItem.SetWindowX(static_cast<int32_t>(current->window_x));
        pointerItem.SetWindowY(static_cast<int32_t>(current->window_y));
        pointerItem.SetDisplayX(static_cast<int32_t>(current->display_x));
        pointerItem.SetDisplayY(static_cast<int32_t>(current->display_y));
        pointerItem.SetPressure(current->pressure);
        pointerItem.SetTiltY(current->tilt);
        pointerItem.SetToolType(static_cast<int32_t>(SourceTypeFromToolType(current->tool_type)));
        pointerEvent->AddPointerItem(pointerItem);
        SetActionPoint(current->pointer_id, current->actionPoint);
        current++;
    }
}

void ConvertMmiPointerEvent(
    std::vector<std::shared_ptr<MMI::PointerEvent>>& pointerEvents, const std::vector<uint8_t>& data)
{
    const auto* current = reinterpret_cast<const AcePointerData*>(data.data());
    size_t size = data.size() / sizeof(AcePointerData);
    auto end = current + size;
    auto deviceId = static_cast<int32_t>(current->device_id);
    auto actionTime = current->time_stamp;
    auto actionType = current->pointer_action;
    std::vector<OHOS::MMI::PointerEvent::PointerItem> items;
    while (current < end)
    {
        OHOS::MMI::PointerEvent::PointerItem pointerItem;
        pointerItem.SetPointerId(static_cast<int32_t>(current->pointer_id));
        pointerItem.SetDeviceId(static_cast<int32_t>(current->device_id));
        pointerItem.SetDownTime(current->time_stamp);
        pointerItem.SetWindowX(static_cast<int32_t>(current->window_x));
        pointerItem.SetWindowY(static_cast<int32_t>(current->window_y));
        pointerItem.SetDisplayX(static_cast<int32_t>(current->display_x));
        pointerItem.SetDisplayY(static_cast<int32_t>(current->display_y));
        pointerItem.SetPressure(current->pressure);
        pointerItem.SetTiltY(current->tilt);
        pointerItem.SetToolType(static_cast<int32_t>(SourceTypeFromToolType(current->tool_type)));
        SetPointerItemPressed(actionType, pointerItem);
        SetActionPoint(current->pointer_id, current->actionPoint);
        current++;
        items.emplace_back(pointerItem);
    }
    for (size_t i = 0; i < items.size(); i++) {
        int32_t pointerId = items[i].GetPointerId();
        if (!IsActionPoint(pointerId)) {
            continue;
        }
        auto pointerEvent = OHOS::MMI::PointerEvent::Create();
        pointerEvent->SetPointerId(pointerId);
        pointerEvent->SetDeviceId(deviceId);
        pointerEvent->SetTargetDisplayId(0);
        pointerEvent->SetActionTime(actionTime);
        SetPointerEventAction(actionType, pointerEvent);
        for (auto& item : items) {
            pointerEvent->AddPointerItem(item);
        }
        pointerEvents.emplace_back(pointerEvent);
    }
}

void ConvertSyntheticMmiPointerEvent(
    std::vector<std::shared_ptr<MMI::PointerEvent>>& pointerEvents, const std::vector<uint8_t>& data)
{
    const auto* current = reinterpret_cast<const AcePointerData*>(data.data());
    size_t size = data.size() / sizeof(AcePointerData);
    auto end = current + size;
    auto deviceId = static_cast<int32_t>(current->device_id);
    auto actionTime = current->time_stamp;
    auto actionType = current->pointer_action;
    std::vector<OHOS::MMI::PointerEvent::PointerItem> items;
    while (current < end) {
        OHOS::MMI::PointerEvent::PointerItem pointerItem;
        const int64_t downTime = ResolveSyntheticDownTime(*current);
        pointerItem.SetPointerId(static_cast<int32_t>(current->pointer_id));
        pointerItem.SetDeviceId(static_cast<int32_t>(current->device_id));
        pointerItem.SetDownTime(downTime);
        pointerItem.SetWindowX(static_cast<int32_t>(current->window_x));
        pointerItem.SetWindowY(static_cast<int32_t>(current->window_y));
        pointerItem.SetDisplayX(static_cast<int32_t>(current->display_x));
        pointerItem.SetDisplayY(static_cast<int32_t>(current->display_y));
        pointerItem.SetPressure(current->pressure);
        pointerItem.SetTiltY(current->tilt);
        pointerItem.SetToolType(static_cast<int32_t>(SourceTypeFromToolType(current->tool_type)));
        SetPointerItemPressed(actionType, pointerItem);
        SetActionPoint(current->pointer_id, current->actionPoint);
        current++;
        items.emplace_back(pointerItem);
    }
    for (size_t i = 0; i < items.size(); i++) {
        int32_t pointerId = items[i].GetPointerId();
        if (!IsActionPoint(pointerId)) {
            continue;
        }
        auto pointerEvent = OHOS::MMI::PointerEvent::Create();
        pointerEvent->SetPointerId(pointerId);
        pointerEvent->SetDeviceId(deviceId);
        pointerEvent->SetTargetDisplayId(0);
        pointerEvent->SetActionTime(actionTime);
        SetPointerEventAction(actionType, pointerEvent);
        for (auto& item : items) {
            pointerEvent->AddPointerItem(item);
        }
        pointerEvents.emplace_back(pointerEvent);
    }
}
} // namespace OHOS::Ace::Platform
