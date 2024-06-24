/*
 * Copyright (c) 2023-2024 Huawei Device Co., Ltd.
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

#include "adapter/ios/stage/uicontent/ace_view_sg.h"

#include "adapter/ios/entrance/ace_platform_plugin.h"
#include "adapter/ios/entrance/ace_resource_register.h"
#include "adapter/ios/stage/uicontent/ace_container_sg.h"
#include "base/log/dump_log.h"
#include "base/log/event_report.h"
#include "base/log/log.h"
#include "base/utils/macros.h"
#include "base/utils/system_properties.h"
#include "base/utils/utils.h"
#include "core/common/ace_engine.h"
#include "core/common/container_scope.h"
#include "core/common/thread_checker.h"
#include "core/components/theme/app_theme.h"
#include "core/components/theme/theme_manager.h"
#include "core/event/mouse_event.h"
#include "core/event/touch_event.h"
#include "core/image/image_cache.h"
#include "flutter/lib/ui/window/pointer_data_packet.h"

namespace OHOS::Ace::Platform {
namespace {
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

void ConvertTouchEvent(const std::vector<uint8_t>& data, std::vector<TouchEvent>& events)
{
    const auto* origin = reinterpret_cast<const flutter::PointerData*>(data.data());
    size_t size = data.size() / sizeof(flutter::PointerData);
    auto current = const_cast<flutter::PointerData*>(origin);
    auto end = current + size;

    while (current < end) {
        if (current->device == -1) {
            current++;
            continue;
        }
        std::chrono::nanoseconds nanos(current->time_stamp);
        TimeStamp time(nanos);
        TouchEvent point;
        point.SetId(static_cast<int32_t>(current->device))
            .SetX(static_cast<float>(current->physical_x))
            .SetY(static_cast<float>(current->physical_y))
            .SetScreenX(static_cast<float>(current->physical_x))
            .SetScreenY(static_cast<float>(current->physical_y))
            .SetType(TouchType::UNKNOWN)
            .SetPullType(TouchType::UNKNOWN)
            .SetTime(time)
            .SetSize(current->size)
            .SetSourceType(SourceType::NONE);
        point.sourceType = SourceType::TOUCH;
        switch (current->change) {
            case flutter::PointerData::Change::kCancel:
                point.type = TouchType::CANCEL;
                events.push_back(point);
                break;
            case flutter::PointerData::Change::kAdd:
            case flutter::PointerData::Change::kRemove:
            case flutter::PointerData::Change::kHover:
                break;
            case flutter::PointerData::Change::kDown:
                point.type = TouchType::DOWN;
                events.push_back(point);
                break;
            case flutter::PointerData::Change::kMove:
                point.type = TouchType::MOVE;
                events.push_back(point);
                break;
            case flutter::PointerData::Change::kUp:
                point.type = TouchType::UP;
                events.push_back(point);
                break;
        }
        current++;
    }
    UpdateTouchEvent(events);
}
} // namespace

AceViewSG* AceViewSG::CreateView(int32_t instanceId)
{
    auto* aceView = new AceViewSG(instanceId);
    if (aceView != nullptr) {
        aceView->IncRefCount();
    }

    return aceView;
}

void AceViewSG::SurfaceCreated(AceViewSG* view, OHOS::Rosen::Window* window)
{
    CHECK_NULL_VOID(window);
    CHECK_NULL_VOID(view);
}

void AceViewSG::RegisterTouchEventCallback(TouchEventCallback&& callback)
{
    ACE_DCHECK(callback);
    touchEventCallback_ = std::move(callback);
}

void AceViewSG::RegisterKeyEventCallback(KeyEventCallback&& callback)
{
    ACE_DCHECK(callback);
    keyEventCallback_ = std::move(callback);
}

void AceViewSG::RegisterMouseEventCallback(MouseEventCallback&& callback)
{
    ACE_DCHECK(callback);
    mouseEventCallback_ = std::move(callback);
}

void AceViewSG::RegisterRotationEventCallback(RotationEventCallBack&& callback)
{
    ACE_DCHECK(callback);
    rotationEventCallback_ = std::move(callback);
}

void AceViewSG::RegisterViewChangeCallback(ViewChangeCallback&& callback)
{
    ACE_DCHECK(callback);
    viewChangeCallback_ = std::move(callback);
}

void AceViewSG::RegisterDensityChangeCallback(DensityChangeCallback&& callback)
{
    ACE_DCHECK(callback);
    densityChangeCallback_ = std::move(callback);
}

void AceViewSG::RegisterSurfaceDestroyCallback(SurfaceDestroyCallback&& callback)
{
    ACE_DCHECK(callback);
    surfaceDestroyCallback_ = std::move(callback);
}

void AceViewSG::RegisterDragEventCallback(DragEventCallBack&& callback)
{
    ACE_DCHECK(callback);
    dragEventCallback_ = std::move(callback);
}

void AceViewSG::RegisterAxisEventCallback(AxisEventCallback&& callback)
{
    ACE_DCHECK(callback);
    axisEventCallback_ = std::move(callback);
}

void AceViewSG::RegisterViewPositionChangeCallback(ViewPositionChangeCallback&& callback)
{
    ACE_DCHECK(callback);
    viewPositionChangeCallback_ = std::move(callback);
}

void AceViewSG::RegisterSystemBarHeightChangeCallback(SystemBarHeightChangeCallback&& callback)
{
    ACE_DCHECK(callback);
    systemBarHeightChangeCallback_ = std::move(callback);
}

bool AceViewSG::Dump(const std::vector<std::string>& params)
{
    if (params.empty() || params[0] != "-drawcmd") {
        LOGE("Unsupported parameters.");
        return false;
    }
    if (DumpLog::GetInstance().GetDumpFile()) {
        DumpLog::GetInstance().AddDesc("Dump draw command not support on this version.");
        DumpLog::GetInstance().Print(0, "Info:", 0);
        return true;
    }
    return false;
}

const void* AceViewSG::GetNativeWindowById(uint64_t textureId)
{
    return AcePlatformPlugin::GetNativeWindow(instanceId_, static_cast<int64_t>(textureId));
}

std::unique_ptr<DrawDelegate> AceViewSG::GetDrawDelegate()
{
    return nullptr;
}

std::unique_ptr<PlatformWindow> AceViewSG::GetPlatformWindow()
{
    return nullptr;
}

void AceViewSG::Launch()
{
    LOGI("Launch shell holder");
}

bool AceViewSG::DispatchBasicEvent(const std::vector<TouchEvent>& touchEvents)
{
    for (const auto& point : touchEvents) {
        if (point.type == TouchType::UNKNOWN) {
            LOGW("Unknown event");
            continue;
        }
        if (touchEventCallback_) {
            touchEventCallback_(point, nullptr, nullptr);
        }
    }
    // if it is last page, let os know to quit app
    return !(IsLastPage());
}

bool AceViewSG::DispatchTouchEvent(const std::vector<uint8_t>& data)
{
    std::vector<TouchEvent> touchEvents;
    ConvertTouchEvent(data, touchEvents);
    LOGI(" ProcessTouchEvent event size%zu", touchEvents.size());
    bool forbiddenToPlatform = false;
    for (const auto& point : touchEvents) {
        DispatchEventToPerf(point);
        if (point.type == TouchType::UNKNOWN) {
            LOGW("Unknown event");
            continue;
        }
        if (touchEventCallback_) {
            touchEventCallback_(point, nullptr, nullptr);
        }
    }
    // if it is last page, let os know to quit app
    return forbiddenToPlatform || (!IsLastPage());
}

bool AceViewSG::IsLastPage() const
{
    auto container = AceEngine::Get().GetContainer(instanceId_);
    CHECK_NULL_RETURN(container, false);
    ContainerScope scope(instanceId_);
    auto context = container->GetPipelineContext();
    CHECK_NULL_RETURN(context, false);
    return context->IsLastPage();
}

bool AceViewSG::DispatchKeyEvent(const KeyEventInfo& eventInfo)
{
    CHECK_NULL_RETURN(keyEventCallback_, false);

    auto keyEvents = keyEventRecognizer_.GetKeyEvents(eventInfo.keyCode, eventInfo.keyAction, eventInfo.repeatTime,
        eventInfo.timeStamp, eventInfo.timeStampStart, eventInfo.metaKey, eventInfo.sourceDevice, eventInfo.deviceId,
        eventInfo.msg);
    if (keyEvents.size() == 0) {
        return false;
    } 
    // distribute special event firstly
    // because platform receives a raw event, the special event processing is ignored
    if (keyEvents.size() > 1) {
        DispatchEventToPerf(keyEvents.back());
        keyEventCallback_(keyEvents.back());
    }
    DispatchEventToPerf(keyEvents.front());
    return keyEventCallback_(keyEvents.front());
}

void AceViewSG::DispatchEventToPerf(const TouchEvent& pointerEvent)
{
    static bool isFirstMove = false;
    if (!PerfMonitor::GetPerfMonitor()) {
        return;
    }
    int64_t inputTime = static_cast<int64_t>(
        std::chrono::duration_cast<std::chrono::nanoseconds>(pointerEvent.time.time_since_epoch()).count());
    if (inputTime <= 0) {
        return;
    }
    PerfActionType inputType = UNKNOWN_ACTION;
    PerfSourceType sourceType = UNKNOWN_SOURCE;
    if (pointerEvent.sourceType == SourceType::MOUSE) {
        sourceType = PERF_MOUSE_EVENT;
    } else if (pointerEvent.sourceType == SourceType::TOUCH) {
        sourceType = PERF_TOUCH_EVENT;
    } else if (pointerEvent.sourceType == SourceType::TOUCH_PAD) {
        sourceType = PERF_TOUCH_PAD;
    } else {
        sourceType = UNKNOWN_SOURCE;
    }
    if (pointerEvent.type == TouchType::DOWN) {
        inputType = LAST_DOWN;
        isFirstMove = true;
    } else if (pointerEvent.type == TouchType::UP) {
        inputType = LAST_UP;
        isFirstMove = false;
    } else if (isFirstMove && pointerEvent.type == TouchType::MOVE) {
        inputType = FIRST_MOVE;
        isFirstMove = false;
    }
    PerfMonitor::GetPerfMonitor()->RecordInputEvent(inputType, sourceType, inputTime);
}

void AceViewSG::DispatchEventToPerf(const KeyEvent& keyEvent)
{
    if (keyEvent.code != KeyCode::KEY_VOLUME_DOWN
        && keyEvent.code != KeyCode::KEY_VOLUME_UP
        && keyEvent.code != KeyCode::KEY_POWER
        && keyEvent.code != KeyCode::KEY_META_LEFT
        && keyEvent.code != KeyCode::KEY_ESCAPE) {
        return;
    }
    if (!PerfMonitor::GetPerfMonitor()) {
        return;
    }
    int64_t inputTime = static_cast<int64_t>(
        std::chrono::duration_cast<std::chrono::nanoseconds>(keyEvent.timeStamp.time_since_epoch()).count());
    if (inputTime <= 0) {
        return;
    }
    PerfActionType inputType = UNKNOWN_ACTION;
    if (keyEvent.action == KeyAction::UP) {
        inputType = LAST_UP;
    } else if (keyEvent.action == KeyAction::DOWN) {
        inputType = LAST_DOWN;
    }
    PerfSourceType sourceType = PERF_KEY_EVENT;
    PerfMonitor::GetPerfMonitor()->RecordInputEvent(inputType, sourceType, inputTime);
}

void AceViewSG::NotifySurfaceDestroyed() const
{
    ACE_DCHECK(surfaceDestroyCallback_);
    surfaceDestroyCallback_();
}

void AceViewSG::NotifySurfaceChanged(int32_t width, int32_t height, WindowSizeChangeReason type)
{
    if (viewChangeCallback_) {
        viewChangeCallback_(width, height, type, nullptr);
    }
    width_ = width;
    height_ = height;
}

void AceViewSG::NotifyDensityChanged(double density)
{
    ACE_DCHECK(densityChangeCallback_);
    densityChangeCallback_(density);
}

void AceViewSG::SetViewportMetrics(AceViewSG* view, const ViewportConfig& config)
{
    CHECK_NULL_VOID(view);
    view->NotifyDensityChanged(config.Density());
}

void AceViewSG::SurfaceChanged(AceViewSG* view, int32_t width, int32_t height, int32_t orientation,
    WindowSizeChangeReason type)
{
    CHECK_NULL_VOID(view);
    view->NotifySurfaceChanged(width, height, type);

    auto instanceId = view->GetInstanceId();
    auto container = Platform::AceContainerSG::GetContainer(instanceId);
    if (container) {
        auto pipelineContext = container->GetPipelineContext();
        CHECK_NULL_VOID(pipelineContext);
        pipelineContext->HideOverlays();
    }
}

void AceViewSG::SurfacePositionChanged(AceViewSG* view, int32_t posX, int32_t posY)
{
    CHECK_NULL_VOID(view);
    view->NotifySurfacePositionChanged(posX, posY);
}

void AceViewSG::NotifySurfacePositionChanged(int32_t posX, int32_t posY)
{
    if (posX_ == posX && posY_ == posY) {
        LOGI("surface position not changed");
        return;
    }
    if (viewPositionChangeCallback_) {
        viewPositionChangeCallback_(posX, posY);
    }
    posX_ = posX;
    posY_ = posY;
}
} // namespace OHOS::Ace::Platform
