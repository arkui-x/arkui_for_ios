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

#include "interaction_impl.h"

#include <algorithm>
#include <atomic>
#include <cmath>
#include <deque>
#include <mutex>
#include <unordered_map>

#include "display_manager.h"
#include "adapter/ios/stage/uicontent/ace_container_sg.h"
#include "base/log/log.h"
#include "core/common/container.h"
#include "core/common/interaction/interaction_data.h"
#include "core/gestures/gesture_info.h"
#include "core/pipeline_ng/pipeline_context.h"

#if defined(ENABLE_DRAG_FRAMEWORK)
#include "drag_data.h"
#include "interaction_manager.h"
#endif

#if defined(ENABLE_DRAG_FRAMEWORK)
using namespace OHOS::Msdp::DeviceStatus;
#endif

namespace OHOS::Ace {
#if defined(ENABLE_DRAG_FRAMEWORK)
Msdp::DeviceStatus::DragCursorStyle TranslateDragCursorStyle(OHOS::Ace::DragCursorStyleCore style);
Msdp::DeviceStatus::DragResult TranslateDragResult(DragRet dragResult);
DragRet TranslateDragResult(Msdp::DeviceStatus::DragResult dragResult);
Msdp::DeviceStatus::DragBehavior TranslateDragBehavior(OHOS::Ace::DragBehavior dragBehavior);
OHOS::Ace::DragBehavior TranslateDragBehavior(Msdp::DeviceStatus::DragBehavior dragBehavior);
bool windowCreated_ = false;
std::function<void(const OHOS::Ace::DragNotifyMsg&)> callback_;

constexpr uint64_t INVALID_SYNTHETIC_DRAG_SESSION_ID = 0;
// Synthetic drag only needs a small recent-event window to bridge start/update routing.
// Keeping the cache bounded prevents unbounded growth while still tolerating bursty move events.
constexpr size_t SYNTHETIC_EVENT_SESSION_CACHE_LIMIT = 64;
constexpr uint32_t SYNTHETIC_POINTER_ID_HASH_SHIFT_BITS = 32;

struct SyntheticPointerDispatchKey {
    int32_t pointerId = -1;
    int64_t actionTime = 0;

    bool operator==(const SyntheticPointerDispatchKey& other) const
    {
        return pointerId == other.pointerId && actionTime == other.actionTime;
    }
};

struct SyntheticPointerDispatchKeyHash {
    size_t operator()(const SyntheticPointerDispatchKey& key) const
    {
        return (static_cast<size_t>(static_cast<uint32_t>(key.pointerId)) <<
            SYNTHETIC_POINTER_ID_HASH_SHIFT_BITS) ^
            static_cast<size_t>(key.actionTime);
    }
};

struct PendingSyntheticDragContext {
    uint64_t sessionId = INVALID_SYNTHETIC_DRAG_SESSION_ID;
};

struct SyntheticDragCompensationState {
    bool valid = false;
    uint64_t sessionId = INVALID_SYNTHETIC_DRAG_SESSION_ID;
    int32_t pointerId = -1;
    int32_t windowWidth = 0;
    int32_t windowHeight = 0;
    int32_t shadowWidth = 0;
    int32_t shadowHeight = 0;
    int32_t hotspotX = -1;
    int32_t hotspotY = -1;
    Rotation rotation = Rotation::ROTATION_0;
};

struct SyntheticDragRuntimeState {
    std::atomic<int32_t> syntheticDragPointerId { -1 };
    std::atomic<bool> syntheticDragActive { false };
    std::atomic<uint64_t> syntheticDragSessionGenerator { 1 };
    std::atomic<uint64_t> activeSyntheticDragSessionId { 0 };
    // If both mutexes are needed, always acquire session first and compensation second.
    std::mutex syntheticDragCompensationMutex;
    std::mutex syntheticDragSessionMutex;
    std::unordered_map<SyntheticPointerDispatchKey, PendingSyntheticDragContext, SyntheticPointerDispatchKeyHash>
        pendingSyntheticDragContexts;
    std::deque<SyntheticPointerDispatchKey> pendingSyntheticDragOrder;
    std::unordered_map<int32_t, uint64_t> syntheticPointerSessionBindings;
    std::unordered_map<SyntheticPointerDispatchKey, uint64_t, SyntheticPointerDispatchKeyHash>
        syntheticPointerDispatchMap;
    std::deque<SyntheticPointerDispatchKey> syntheticPointerDispatchOrder;
    SyntheticDragCompensationState syntheticDragCompensationState;

    void ResetCompensationStateLocked()
    {
        syntheticDragCompensationState = {};
    }

    void ResetPendingContextsLocked()
    {
        pendingSyntheticDragContexts.clear();
        pendingSyntheticDragOrder.clear();
    }

    void ResetPendingContextsLocked(int32_t pointerId)
    {
        if (pointerId < 0) {
            return;
        }
        for (auto iter = pendingSyntheticDragContexts.begin(); iter != pendingSyntheticDragContexts.end();) {
            if (iter->first.pointerId == pointerId) {
                iter = pendingSyntheticDragContexts.erase(iter);
            } else {
                ++iter;
            }
        }
        pendingSyntheticDragOrder.erase(
            std::remove_if(pendingSyntheticDragOrder.begin(), pendingSyntheticDragOrder.end(),
                [pointerId](const SyntheticPointerDispatchKey& key) { return key.pointerId == pointerId; }),
            pendingSyntheticDragOrder.end());
    }

    void RegisterPendingContextLocked(int32_t pointerId, int64_t actionTime, uint64_t sessionId)
    {
        if (pointerId < 0 || actionTime <= 0 || sessionId == INVALID_SYNTHETIC_DRAG_SESSION_ID) {
            return;
        }
        SyntheticPointerDispatchKey key { pointerId, actionTime };
        if (pendingSyntheticDragContexts.find(key) == pendingSyntheticDragContexts.end()) {
            pendingSyntheticDragOrder.push_back(key);
        }
        pendingSyntheticDragContexts[key] = { sessionId };
        while (pendingSyntheticDragOrder.size() > SYNTHETIC_EVENT_SESSION_CACHE_LIMIT) {
            const auto oldest = pendingSyntheticDragOrder.front();
            pendingSyntheticDragOrder.pop_front();
            pendingSyntheticDragContexts.erase(oldest);
        }
    }

    uint64_t FindLatestPendingSessionIdLocked(int32_t pointerId, SyntheticPointerDispatchKey* matchedKey)
    {
        if (pointerId < 0) {
            return INVALID_SYNTHETIC_DRAG_SESSION_ID;
        }
        for (auto iter = pendingSyntheticDragOrder.rbegin(); iter != pendingSyntheticDragOrder.rend(); ++iter) {
            if (iter->pointerId != pointerId) {
                continue;
            }
            auto pendingIter = pendingSyntheticDragContexts.find(*iter);
            if (pendingIter == pendingSyntheticDragContexts.end()) {
                continue;
            }
            if (matchedKey != nullptr) {
                *matchedKey = pendingIter->first;
            }
            return pendingIter->second.sessionId;
        }
        return INVALID_SYNTHETIC_DRAG_SESSION_ID;
    }

    void ConsumePendingContextLocked(const SyntheticPointerDispatchKey& key)
    {
        pendingSyntheticDragContexts.erase(key);
        pendingSyntheticDragOrder.erase(
            std::remove(pendingSyntheticDragOrder.begin(), pendingSyntheticDragOrder.end(), key),
            pendingSyntheticDragOrder.end());
    }

    void RegisterDispatchLocked(int32_t pointerId, int64_t actionTime, uint64_t sessionId)
    {
        if (pointerId < 0 || actionTime <= 0 || sessionId == INVALID_SYNTHETIC_DRAG_SESSION_ID) {
            return;
        }
        SyntheticPointerDispatchKey key { pointerId, actionTime };
        if (syntheticPointerDispatchMap.find(key) == syntheticPointerDispatchMap.end()) {
            syntheticPointerDispatchOrder.push_back(key);
        }
        syntheticPointerDispatchMap[key] = sessionId;
        while (syntheticPointerDispatchOrder.size() > SYNTHETIC_EVENT_SESSION_CACHE_LIMIT) {
            const auto oldest = syntheticPointerDispatchOrder.front();
            syntheticPointerDispatchOrder.pop_front();
            syntheticPointerDispatchMap.erase(oldest);
        }
    }

    enum class SyntheticSessionResolveSource {
        INVALID,
        DISPATCH,
        POINTER_BINDING,
        PENDING_CONTEXT,
    };

    std::pair<uint64_t, SyntheticSessionResolveSource> ResolveSessionIdWithSourceLocked(
        int32_t pointerId, int64_t actionTime)
    {
        if (pointerId < 0) {
            return { INVALID_SYNTHETIC_DRAG_SESSION_ID, SyntheticSessionResolveSource::INVALID };
        }
        if (actionTime > 0) {
            SyntheticPointerDispatchKey key { pointerId, actionTime };
            auto keyIter = syntheticPointerDispatchMap.find(key);
            if (keyIter != syntheticPointerDispatchMap.end()) {
                return { keyIter->second, SyntheticSessionResolveSource::DISPATCH };
            }
        }
        auto bindingIter = syntheticPointerSessionBindings.find(pointerId);
        if (bindingIter != syntheticPointerSessionBindings.end()) {
            return { bindingIter->second, SyntheticSessionResolveSource::POINTER_BINDING };
        }
        const auto pendingSessionId = FindLatestPendingSessionIdLocked(pointerId, nullptr);
        if (pendingSessionId != INVALID_SYNTHETIC_DRAG_SESSION_ID) {
            return { pendingSessionId, SyntheticSessionResolveSource::PENDING_CONTEXT };
        }
        return { INVALID_SYNTHETIC_DRAG_SESSION_ID, SyntheticSessionResolveSource::INVALID };
    }
};

SyntheticDragRuntimeState& GetSyntheticDragRuntimeState()
{
    static SyntheticDragRuntimeState state;
    return state;
}

Rotation GetSyntheticDragRotation()
{
    auto container = Container::Current();
    CHECK_NULL_RETURN(container, Rotation::ROTATION_0);
    auto displayInfo = container->GetDisplayInfo();
    CHECK_NULL_RETURN(displayInfo, Rotation::ROTATION_0);
    return displayInfo->GetRotation();
}

void RegisterSyntheticPointerDispatchLocked(int32_t pointerId, int64_t actionTime, uint64_t sessionId)
{
    auto& state = GetSyntheticDragRuntimeState();
    if (pointerId < 0 || actionTime <= 0 || sessionId == INVALID_SYNTHETIC_DRAG_SESSION_ID) {
        return;
    }
    state.RegisterDispatchLocked(pointerId, actionTime, sessionId);
}

uint64_t ResolveSyntheticDragSessionIdLocked(int32_t pointerId, int64_t actionTime)
{
    auto& state = GetSyntheticDragRuntimeState();
    const auto sessionId = state.ResolveSessionIdWithSourceLocked(pointerId, actionTime).first;
    if (sessionId == INVALID_SYNTHETIC_DRAG_SESSION_ID) {
        LOGW("[UITEST_IOS_DRAGFIX] resolve synthetic session missed pointerId=%{public}d actionTime=%{public}" PRId64,
            pointerId, actionTime);
    }
    return sessionId;
}

uint64_t MatchAndConsumeSyntheticDragSessionId(const DragDataCore& dragData, bool isSyntheticDrag)
{
    auto& state = GetSyntheticDragRuntimeState();
    if (!isSyntheticDrag) {
        return INVALID_SYNTHETIC_DRAG_SESSION_ID;
    }
    std::lock_guard<std::mutex> lock(state.syntheticDragSessionMutex);
    SyntheticPointerDispatchKey matchedKey;
    const auto sessionId = state.FindLatestPendingSessionIdLocked(dragData.pointerId, &matchedKey);
    if (sessionId != INVALID_SYNTHETIC_DRAG_SESSION_ID) {
        state.ConsumePendingContextLocked(matchedKey);
        return sessionId;
    }
    auto bindingIter = state.syntheticPointerSessionBindings.find(dragData.pointerId);
    if (bindingIter != state.syntheticPointerSessionBindings.end()) {
        return bindingIter->second;
    }
    return INVALID_SYNTHETIC_DRAG_SESSION_ID;
}

void UpdateSyntheticDragCompensationStateLocked(const DragDataCore& dragData,
    const std::shared_ptr<OHOS::Rosen::Window>& dragWindow, int32_t width, int32_t height, uint64_t sessionId)
{
    auto& compensationState = GetSyntheticDragRuntimeState().syntheticDragCompensationState;
    compensationState.valid = true;
    compensationState.sessionId = sessionId;
    compensationState.pointerId = dragData.pointerId;
    compensationState.windowWidth = width;
    compensationState.windowHeight = height;
    if (dragWindow) {
        const auto rect = dragWindow->GetRect();
        if (rect.width_ > 0) {
            compensationState.windowWidth = rect.width_;
        }
        if (rect.height_ > 0) {
            compensationState.windowHeight = rect.height_;
        }
    }
    compensationState.shadowWidth = 0;
    compensationState.shadowHeight = 0;
    compensationState.hotspotX = -1;
    compensationState.hotspotY = -1;
    if (!dragData.shadowInfos.empty() && dragData.shadowInfos.front().pixelMap) {
        compensationState.shadowWidth =
            dragData.shadowInfos.front().pixelMap->GetWidth();
        compensationState.shadowHeight =
            dragData.shadowInfos.front().pixelMap->GetHeight();
        compensationState.hotspotX = -dragData.shadowInfos.front().x;
        compensationState.hotspotY = -dragData.shadowInfos.front().y;
    }
    compensationState.rotation = GetSyntheticDragRotation();
}

struct SyntheticCompensatedPoint {
    int32_t displayX = 0;
    int32_t displayY = 0;
};

SyntheticCompensatedPoint CompensateSyntheticDragPointWithHotspotLocked(int32_t displayX, int32_t displayY)
{
    const auto& compensationState = GetSyntheticDragRuntimeState().syntheticDragCompensationState;
    float compensatedX = static_cast<float>(displayX);
    float compensatedY = static_cast<float>(displayY);
    const auto hotspotX = static_cast<float>(compensationState.hotspotX);
    const auto hotspotY = static_cast<float>(compensationState.hotspotY);
    const auto shadowWidth = static_cast<float>(compensationState.shadowWidth);
    const auto shadowHeight = static_cast<float>(compensationState.shadowHeight);
    switch (compensationState.rotation) {
        case Rotation::ROTATION_0:
            break;
        case Rotation::ROTATION_90:
            compensatedX = static_cast<float>(compensationState.windowWidth) -
                static_cast<float>(displayY) - hotspotY;
            compensatedY = static_cast<float>(displayX) - hotspotX;
            break;
        case Rotation::ROTATION_180:
            compensatedX = static_cast<float>(compensationState.windowWidth) -
                static_cast<float>(displayX) - (shadowWidth - 2.0f * hotspotX);
            compensatedY = static_cast<float>(compensationState.windowHeight) -
                static_cast<float>(displayY) - (shadowHeight - 2.0f * hotspotY);
            break;
        case Rotation::ROTATION_270:
            compensatedX = static_cast<float>(displayY) + hotspotY;
            compensatedY = static_cast<float>(compensationState.windowHeight) -
                static_cast<float>(displayX) - hotspotX;
            break;
        default:
            break;
    }
    return { static_cast<int32_t>(std::lround(compensatedX)), static_cast<int32_t>(std::lround(compensatedY)) };
}

SyntheticCompensatedPoint CompensateSyntheticDragPointLocked(int32_t displayX, int32_t displayY, int32_t pointerId)
{
    const auto& compensationState = GetSyntheticDragRuntimeState().syntheticDragCompensationState;
    if (!compensationState.valid || compensationState.pointerId != pointerId) {
        return { displayX, displayY };
    }
    const bool hasHotspot = compensationState.shadowWidth > 0 &&
        compensationState.shadowHeight > 0 &&
        compensationState.hotspotX >= 0 &&
        compensationState.hotspotY >= 0;
    if (!hasHotspot) {
        LOGW("[UITEST_IOS_DRAGFIX] fallback synthetic compensation without hotspot "
             "pointerId=%{public}d rotation=%{public}d shadow=(%{public}d,%{public}d) "
             "hotspot=(%{public}d,%{public}d) display=(%{public}d,%{public}d)",
            pointerId, static_cast<int32_t>(compensationState.rotation),
            compensationState.shadowWidth, compensationState.shadowHeight,
            compensationState.hotspotX, compensationState.hotspotY,
            displayX, displayY);
        return { displayX, displayY };
    }
    return CompensateSyntheticDragPointWithHotspotLocked(displayX, displayY);
}

std::shared_ptr<MMI::PointerEvent> CreateSyntheticCompensatedPointerEvent(
    const std::shared_ptr<MMI::PointerEvent>& pointerEvent, uint64_t sessionId)
{
    CHECK_NULL_RETURN(pointerEvent, nullptr);
    auto& state = GetSyntheticDragRuntimeState();
    std::lock_guard<std::mutex> lock(state.syntheticDragCompensationMutex);
    if (!state.syntheticDragCompensationState.valid ||
        state.syntheticDragCompensationState.sessionId != sessionId ||
        state.syntheticDragCompensationState.pointerId != pointerEvent->GetPointerId()) {
        return pointerEvent;
    }
    auto adjustedEvent = MMI::PointerEvent::Create();
    CHECK_NULL_RETURN(adjustedEvent, pointerEvent);
    adjustedEvent->SetPointerId(pointerEvent->GetPointerId());
    adjustedEvent->SetDeviceId(pointerEvent->GetDeviceId());
    adjustedEvent->SetTargetDisplayId(pointerEvent->GetTargetDisplayId());
    adjustedEvent->SetActionTime(pointerEvent->GetActionTime());
    adjustedEvent->SetFingerCount(pointerEvent->GetFingerCount());
    adjustedEvent->SetPointerAction(pointerEvent->GetPointerAction());
    adjustedEvent->SetSourceType(pointerEvent->GetSourceType());
    adjustedEvent->SetPullId(pointerEvent->GetPullId());
    auto pointerIds = pointerEvent->GetPointerIds();
    for (const auto id : pointerIds) {
        MMI::PointerEvent::PointerItem pointerItem;
        if (!pointerEvent->GetPointerItem(id, pointerItem)) {
            return pointerEvent;
        }
        if (id == pointerEvent->GetPointerId()) {
            const auto originalDisplayX = pointerItem.GetDisplayX();
            const auto originalDisplayY = pointerItem.GetDisplayY();
            const auto compensatedPoint = CompensateSyntheticDragPointLocked(originalDisplayX, originalDisplayY, id);
            pointerItem.SetDisplayX(compensatedPoint.displayX);
            pointerItem.SetDisplayY(compensatedPoint.displayY);
            pointerItem.SetWindowX(pointerItem.GetWindowX() + (compensatedPoint.displayX - originalDisplayX));
            pointerItem.SetWindowY(pointerItem.GetWindowY() + (compensatedPoint.displayY - originalDisplayY));
        }
        adjustedEvent->AddPointerItem(pointerItem);
    }
    return adjustedEvent;
}

namespace {

struct SyntheticDragHeightContext {
    int32_t rootHeight = 0;
    int32_t displayHeight = 0;
    int32_t coordinateHeight = 0;
};

SyntheticDragHeightContext GetSyntheticDragHeightContext()
{
    SyntheticDragHeightContext context;
    context.rootHeight = static_cast<int32_t>(NG::PipelineContext::GetCurrentRootHeight());
    auto defaultDisplay = Rosen::DisplayManager::GetInstance().GetDefaultDisplaySync();
    if (defaultDisplay) {
        auto defaultDisplayInfo = defaultDisplay->GetDisplayInfo();
        if (defaultDisplayInfo) {
            context.displayHeight = defaultDisplayInfo->GetHeight();
        }
    }
    context.coordinateHeight = context.rootHeight > 0 ? context.rootHeight : context.displayHeight;
    return context;
}

} // namespace

Msdp::DeviceStatus::DragData CreateBaseMsdpDragData(const DragDataCore& dragData)
{
    Msdp::DeviceStatus::DragData msdpDragData { {}, dragData.buffer, dragData.udKey, dragData.extraInfo,
        dragData.filterInfo, dragData.sourceType, dragData.dragNum, dragData.pointerId,
        dragData.displayX, dragData.displayY, dragData.displayId, dragData.mainWindow, dragData.hasCanceledAnimation,
        dragData.hasCoordinateCorrected, dragData.summarys };
    for (auto& shadowInfo : dragData.shadowInfos) {
        if (shadowInfo.pixelMap) {
            msdpDragData.shadowInfos.push_back(
                { shadowInfo.pixelMap->GetPixelMapSharedPtr(), shadowInfo.x, shadowInfo.y });
        } else {
            msdpDragData.shadowInfos.push_back({ nullptr, shadowInfo.x, shadowInfo.y });
        }
    }
    return msdpDragData;
}

void StartManualDragWindow(const DragDataCore& dragData)
{
    auto msdpDragData = CreateBaseMsdpDragData(dragData);
    InteractionManager::GetInstance()->StartDrag(msdpDragData);
}

void StartSyntheticDragWindow(const DragDataCore& dragData,
    const std::shared_ptr<OHOS::Rosen::Window>& dragWindow, int32_t width, int32_t height, uint64_t sessionId)
{
    auto& state = GetSyntheticDragRuntimeState();
    InitializeSyntheticDragCompensation(dragData, dragWindow, width, height, sessionId);
    int32_t adjustedDisplayX = dragData.displayX;
    int32_t adjustedDisplayY = dragData.displayY;
    {
        std::lock_guard<std::mutex> lock(state.syntheticDragCompensationMutex);
        const auto compensatedPoint =
            CompensateSyntheticDragPointLocked(dragData.displayX, dragData.displayY, dragData.pointerId);
        adjustedDisplayX = compensatedPoint.displayX;
        adjustedDisplayY = compensatedPoint.displayY;
    }

    auto msdpDragData = CreateBaseMsdpDragData(dragData);
    msdpDragData.displayX = adjustedDisplayX;
    msdpDragData.displayY = adjustedDisplayY;

    const auto heightContext = GetSyntheticDragHeightContext();
    const auto shadowCount = static_cast<int32_t>(dragData.shadowInfos.size());
    const auto firstShadowX = shadowCount > 0 ? dragData.shadowInfos.front().x : 0;
    const auto firstShadowY = shadowCount > 0 ? dragData.shadowInfos.front().y : 0;
    InteractionManager::GetInstance()->StartDrag(msdpDragData);
}

#endif

void UpdateSyntheticDragTouchState(int32_t pointerId, bool active)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    auto& state = GetSyntheticDragRuntimeState();
    if (active) {
        state.syntheticDragPointerId.store(pointerId, std::memory_order_relaxed);
        state.syntheticDragActive.store(true, std::memory_order_release);
        return;
    }
    const auto currentPointerId = state.syntheticDragPointerId.load(std::memory_order_acquire);
    if (pointerId < 0 || currentPointerId == pointerId) {
        state.syntheticDragActive.store(false, std::memory_order_release);
    }
#else
    (void)pointerId;
    (void)active;
#endif
}

void CompleteSyntheticDragTouchState(int32_t pointerId, bool active)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    auto& state = GetSyntheticDragRuntimeState();
    if (active) {
        return;
    }
    const auto currentPointerId = state.syntheticDragPointerId.load(std::memory_order_relaxed);
    if (pointerId >= 0 && currentPointerId >= 0 && currentPointerId != pointerId) {
        return;
    }
    {
        std::scoped_lock lock(state.syntheticDragSessionMutex, state.syntheticDragCompensationMutex);
        state.syntheticPointerSessionBindings.erase(currentPointerId);
        if (pointerId >= 0 && pointerId != currentPointerId) {
            state.syntheticPointerSessionBindings.erase(pointerId);
        }
        state.ResetPendingContextsLocked(currentPointerId);
        if (pointerId >= 0 && pointerId != currentPointerId) {
            state.ResetPendingContextsLocked(pointerId);
        }
        state.ResetCompensationStateLocked();
        state.activeSyntheticDragSessionId.store(INVALID_SYNTHETIC_DRAG_SESSION_ID, std::memory_order_relaxed);
        state.syntheticDragPointerId.store(-1, std::memory_order_relaxed);
    }
#else
    (void)pointerId;
    (void)active;
#endif
}

void PrepareSyntheticDragCompensationContext(int32_t pointerId, bool active, bool isStart, int64_t actionTime)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    auto& state = GetSyntheticDragRuntimeState();
    std::lock_guard<std::mutex> lock(state.syntheticDragSessionMutex);
    if (pointerId < 0) {
        return;
    }
    auto bindingIter = state.syntheticPointerSessionBindings.find(pointerId);
    uint64_t sessionId = bindingIter != state.syntheticPointerSessionBindings.end() ?
        bindingIter->second : INVALID_SYNTHETIC_DRAG_SESSION_ID;
    if (active && (isStart || sessionId == INVALID_SYNTHETIC_DRAG_SESSION_ID)) {
        sessionId = state.syntheticDragSessionGenerator.fetch_add(1, std::memory_order_relaxed);
        state.syntheticPointerSessionBindings[pointerId] = sessionId;
        state.RegisterPendingContextLocked(pointerId, actionTime, sessionId);
    } else if (active && sessionId != INVALID_SYNTHETIC_DRAG_SESSION_ID) {
        state.RegisterPendingContextLocked(pointerId, actionTime, sessionId);
    } else if (!active && sessionId == INVALID_SYNTHETIC_DRAG_SESSION_ID) {
        sessionId = state.FindLatestPendingSessionIdLocked(pointerId, nullptr);
    }
    RegisterSyntheticPointerDispatchLocked(pointerId, actionTime, sessionId);
#else
    (void)pointerId;
    (void)active;
    (void)isStart;
    (void)actionTime;
#endif
}

uint64_t ResolveSyntheticDragSessionId(const std::shared_ptr<MMI::PointerEvent>& pointerEvent)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    CHECK_NULL_RETURN(pointerEvent, INVALID_SYNTHETIC_DRAG_SESSION_ID);
    auto& state = GetSyntheticDragRuntimeState();
    std::lock_guard<std::mutex> lock(state.syntheticDragSessionMutex);
    return ResolveSyntheticDragSessionIdLocked(pointerEvent->GetPointerId(),
        static_cast<int64_t>(pointerEvent->GetActionTime()));
#else
    (void)pointerEvent;
    return INVALID_SYNTHETIC_DRAG_SESSION_ID;
#endif
}
void InitializeSyntheticDragCompensation(const DragDataCore& dragData,
    const std::shared_ptr<OHOS::Rosen::Window>& dragWindow, int32_t width, int32_t height, uint64_t sessionId)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    auto& state = GetSyntheticDragRuntimeState();
    std::lock_guard<std::mutex> lock(state.syntheticDragCompensationMutex);
    UpdateSyntheticDragCompensationStateLocked(dragData, dragWindow, width, height, sessionId);
#else
    (void)dragData;
    (void)dragWindow;
    (void)width;
    (void)height;
    (void)sessionId;
#endif
}

bool IsSyntheticDragTouchActiveForPointer(int32_t pointerId)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    const auto& state = GetSyntheticDragRuntimeState();
    if (!state.syntheticDragActive.load(std::memory_order_acquire)) {
        return false;
    }
    return state.syntheticDragPointerId.load(std::memory_order_relaxed) == pointerId;
#else
    (void)pointerId;
    return false;
#endif
}

InteractionInterface* InteractionInterface::GetInstance()
{
    static InteractionImpl instance;
    return &instance;
}

int32_t InteractionImpl::UpdateShadowPic(const OHOS::Ace::ShadowInfoCore& shadowInfo)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    auto pixelMap = shadowInfo.pixelMap;
    if (!pixelMap) {
        Msdp::DeviceStatus::ShadowInfo msdpShadowInfo { nullptr, shadowInfo.x, shadowInfo.y };
        return InteractionManager::GetInstance()->UpdateShadowPic(msdpShadowInfo);
    }
    Msdp::DeviceStatus::ShadowInfo msdpShadowInfo { shadowInfo.pixelMap->GetPixelMapSharedPtr(), shadowInfo.x,
        shadowInfo.y };
    return InteractionManager::GetInstance()->UpdateShadowPic(msdpShadowInfo);
#endif
    return -1;
}

int32_t InteractionImpl::SetDragWindowVisible(bool visible, const std::shared_ptr<Rosen::RSTransaction>& rSTransaction)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    return InteractionManager::GetInstance()->SetDragWindowVisible(visible);
#endif
    return -1;
}

int32_t InteractionImpl::SetMouseDragMonitorState(bool state)
{
    return -1;
}

int32_t InteractionImpl::StartDrag(
    const DragDataCore& dragData, std::function<void(const OHOS::Ace::DragNotifyMsg&)> callback)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    callback_ = callback;
    auto& state = GetSyntheticDragRuntimeState();
    std::shared_ptr<OHOS::Rosen::Window> window = GetDragWindow();
    CHECK_NULL_RETURN(window, -1);
    const bool isSyntheticDrag = IsSyntheticDragTouchActiveForPointer(dragData.pointerId);
    const auto syntheticSessionId = MatchAndConsumeSyntheticDragSessionId(dragData, isSyntheticDrag);
    if (isSyntheticDrag && syntheticSessionId == INVALID_SYNTHETIC_DRAG_SESSION_ID) {
        LOGW("[UITEST_IOS_DRAGFIX] synthetic start without session, pointerId=%{public}d", dragData.pointerId);
    }
    state.activeSyntheticDragSessionId.store(
        isSyntheticDrag ? syntheticSessionId : INVALID_SYNTHETIC_DRAG_SESSION_ID, std::memory_order_relaxed);
    surfaceNodeListener_ = new SurfaceNodeListener(window, dragData, isSyntheticDrag, syntheticSessionId);
    CHECK_NULL_RETURN(surfaceNodeListener_, -1);
    window->RegisterSurfaceNodeListener(surfaceNodeListener_);
    window->ShowWindow();
    RegisterDragWindow();
    return 0;
#endif
    return -1;
}

void InteractionImpl::RegisterDragWindow()
{
    auto callback = [surfaceNodeListener = surfaceNodeListener_] {
        CHECK_NULL_VOID(surfaceNodeListener);
        CHECK_NULL_VOID(surfaceNodeListener->dragWindow_);
        auto window = surfaceNodeListener->dragWindow_;
        CHECK_NULL_VOID(window);
        window->UnregisterSurfaceNodeListener(surfaceNodeListener);
        window->Destroy();
        surfaceNodeListener->dragWindow_ = nullptr;
        windowCreated_ = false;
    };
    InteractionManager::GetInstance()->RegisterDragWindow(callback);
}

int32_t InteractionImpl::GetDragBundleInfo(DragBundleInfo& dragBundleInfo)
{
    return -1;
}

int32_t InteractionImpl::UpdateDragStyle(OHOS::Ace::DragCursorStyleCore style, const int32_t eventId)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    return InteractionManager::GetInstance()->UpdateDragStyle(TranslateDragCursorStyle(style));
#endif
    return -1;
}

int32_t InteractionImpl::UpdatePreviewStyle(const OHOS::Ace::PreviewStyle& previewStyle)
{
    return -1;
}

int32_t InteractionImpl::UpdatePreviewStyleWithAnimation(const OHOS::Ace::PreviewStyle& previewStyle,
    const OHOS::Ace::PreviewAnimation& animation)
{
    return -1;
}

int32_t InteractionImpl::StopDrag(DragDropRet result, std::function<void()> callback)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    auto& state = GetSyntheticDragRuntimeState();
    LOGI("InteractionImpl::StopDrag");
    Msdp::DeviceStatus::DragDropResult dragDropResult { TranslateDragResult(result.result), result.hasCustomAnimation,
        result.mainWindow, TranslateDragBehavior(result.dragBehavior) };
    OHOS::Ace::DragNotifyMsg msg { 0, 0, InteractionManager::GetInstance()->GetDragTargetPid(),
            TranslateDragResult(dragDropResult.result), TranslateDragBehavior(dragDropResult.dragBehavior) };
    if (callback_) {
        callback_(msg);
    }
    state.activeSyntheticDragSessionId.store(INVALID_SYNTHETIC_DRAG_SESSION_ID, std::memory_order_relaxed);
    return InteractionManager::GetInstance()->StopDrag(dragDropResult);
#endif
    return -1;
}

int32_t InteractionImpl::GetUdKey(std::string& udKey)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    return InteractionManager::GetInstance()->GetUdKey(udKey);
#endif
    return -1;
}

int32_t InteractionImpl::GetShadowOffset(ShadowOffsetData& shadowOffsetData)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    return InteractionManager::GetInstance()->GetShadowOffset(
        shadowOffsetData.offsetX, shadowOffsetData.offsetY, shadowOffsetData.width, shadowOffsetData.height);
#endif
    return -1;
}

int32_t InteractionImpl::GetDragState(DragState& dragState) const
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    Msdp::DeviceStatus::DragState state;
    int32_t ret = InteractionManager::GetInstance()->GetDragState(state);
    LOGI("InteractionImpl::GetDragState = %{public}d", ret);
    switch (state) {
        case Msdp::DeviceStatus::DragState::ERROR:
            dragState = DragState::ERROR;
            break;
        case Msdp::DeviceStatus::DragState::START:
            dragState = DragState::START;
            break;
        case Msdp::DeviceStatus::DragState::STOP:
            dragState = DragState::STOP;
            break;
        case Msdp::DeviceStatus::DragState::CANCEL:
            dragState = DragState::CANCEL;
            break;
        case Msdp::DeviceStatus::DragState::MOTION_DRAGGING:
            dragState = DragState::MOTION_DRAGGING;
            break;
        default:
            dragState = DragState::ERROR;
            LOGW("unknow msdp drag state: %d", state);
            break;
    }
    return ret;
#endif
    return -1;
}

int32_t InteractionImpl::GetDragSummary(std::map<std::string, int64_t>& summary,
    std::map<std::string, int64_t>& detailedSummary, std::map<std::string, std::vector<int32_t>>& summaryFormat,
    int32_t& version, int64_t& totalSize, std::string& tag)
{
#ifdef ENABLE_DRAG_FRAMEWORK
    Msdp::DeviceStatus::DragSummaryInfo dragSummary;
    auto ret = InteractionManager::GetInstance()->GetDragSummaryInfo(dragSummary);
    if (ret != 0) {
        return ret;
    }
    summary = dragSummary.summarys;
    detailedSummary = dragSummary.detailedSummarys;
    summaryFormat = dragSummary.summaryFormat;
    version = dragSummary.version;
    totalSize = dragSummary.totalSize;
    return ret;
#endif
    return -1;
}

int32_t InteractionImpl::GetDragExtraInfo(std::string& extraInfo)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    return InteractionManager::GetInstance()->GetExtraInfo(extraInfo);
#endif
    return -1;
}

int32_t InteractionImpl::EnterTextEditorArea(bool enable)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    return InteractionManager::GetInstance()->EnterTextEditorArea(enable);
#endif
    return -1;
}

int32_t InteractionImpl::AddPrivilege(const std::string& signature, const DragEventData& dragEventData)
{
    return -1;
}

int32_t InteractionImpl::RegisterCoordinationListener(std::function<void()> dragOutCallback)
{
    return -1;
}

int32_t InteractionImpl::UnRegisterCoordinationListener()
{
    return -1;
}

int32_t InteractionImpl::SetDraggableState(bool state)
{
    return -1;
}

int32_t InteractionImpl::GetAppDragSwitchState(bool& state)
{
    return -1;
}

void InteractionImpl::SetDraggableStateAsync(bool state, int64_t downTime) {}

int32_t InteractionImpl::EnableInternalDropAnimation(const std::string& animationInfo)
{
    return -1;
}

bool InteractionImpl::IsDragStart() const
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    return InteractionManager::GetInstance()->IsDragStart();
#endif
    return false;
}

int32_t InteractionImpl::UpdatePointAction(const std::shared_ptr<MMI::PointerEvent>& pointerEvent)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    return InteractionManager::GetInstance()->UpdatePointerAction(pointerEvent);
#endif
    return -1;
}

int32_t InteractionImpl::UpdateSyntheticPointAction(const std::shared_ptr<MMI::PointerEvent>& pointerEvent)
{
#if defined(ENABLE_DRAG_FRAMEWORK)
    auto& state = GetSyntheticDragRuntimeState();
    const auto sessionId = ResolveSyntheticDragSessionId(pointerEvent);
    const auto activeSessionId = state.activeSyntheticDragSessionId.load(std::memory_order_relaxed);
    if (sessionId == INVALID_SYNTHETIC_DRAG_SESSION_ID) {
        LOGW("[UITEST_IOS_DRAGFIX] skip synthetic update due to missing session, "
             "pointerId=%{public}d actionTime=%{public}" PRId64,
            pointerEvent ? pointerEvent->GetPointerId() : -1,
            pointerEvent ? static_cast<int64_t>(pointerEvent->GetActionTime()) : 0);
        return 0;
    }
    if (activeSessionId != INVALID_SYNTHETIC_DRAG_SESSION_ID && sessionId != activeSessionId) {
        LOGW("[UITEST_IOS_DRAGFIX] skip stale synthetic update sessionId=%{public}llu "
             "activeSessionId=%{public}llu pointerId=%{public}d",
            static_cast<unsigned long long>(sessionId), static_cast<unsigned long long>(activeSessionId),
            pointerEvent ? pointerEvent->GetPointerId() : -1);
        return 0;
    }
    auto adjustedPointerEvent = CreateSyntheticCompensatedPointerEvent(pointerEvent, sessionId);
    return InteractionManager::GetInstance()->UpdatePointerAction(adjustedPointerEvent);
#endif
    return -1;
}

std::shared_ptr<OHOS::Rosen::Window> InteractionImpl::GetDragWindow()
{
    auto containerId = Container::CurrentId();
    auto container = Platform::AceContainerSG::GetContainer(containerId);
    CHECK_NULL_RETURN(container, nullptr);
    std::string packagePath = container->GetPackagePathStr();
    std::string filePath = packagePath + "/systemres" + "/resources";
    InteractionManager::GetInstance()->SetSVGFilePath(filePath);
    sptr<Rosen::Window> window = container->GetUIWindow(containerId);
    CHECK_NULL_RETURN(window, nullptr);
    auto dragWindow = Rosen::Window::CreateDragWindow(window->GetContext());
    return dragWindow;
}

void SurfaceNodeListener::OnSurfaceNodeChanged(int32_t width, int32_t height, float density)
{
#ifdef ENABLE_DRAG_FRAMEWORK
    (void)density;
    if (windowCreated_) {
        return;
    }
    InteractionManager::GetInstance()->SetDragWindow(dragWindow_);
    if (isSyntheticDrag_) {
        StartSyntheticDragWindow(dragData, dragWindow_, width, height, syntheticSessionId_);
    } else {
        StartManualDragWindow(dragData);
    }
    windowCreated_ = true;
#endif
}

#if defined(ENABLE_DRAG_FRAMEWORK)
Msdp::DeviceStatus::DragCursorStyle TranslateDragCursorStyle(OHOS::Ace::DragCursorStyleCore style)
{
    switch (style) {
        case OHOS::Ace::DragCursorStyleCore::DEFAULT:
            return Msdp::DeviceStatus::DragCursorStyle::DEFAULT;
        case OHOS::Ace::DragCursorStyleCore::FORBIDDEN:
            return Msdp::DeviceStatus::DragCursorStyle::FORBIDDEN;
        case OHOS::Ace::DragCursorStyleCore::COPY:
            return Msdp::DeviceStatus::DragCursorStyle::COPY;
        case OHOS::Ace::DragCursorStyleCore::MOVE:
            return Msdp::DeviceStatus::DragCursorStyle::MOVE;
        default:
            return Msdp::DeviceStatus::DragCursorStyle::DEFAULT;
    }
}

Msdp::DeviceStatus::DragResult TranslateDragResult(DragRet dragResult)
{
    switch (dragResult) {
        case DragRet::DRAG_SUCCESS:
            return Msdp::DeviceStatus::DragResult::DRAG_SUCCESS;
        case DragRet::DRAG_FAIL:
            return Msdp::DeviceStatus::DragResult::DRAG_FAIL;
        case DragRet::DRAG_CANCEL:
            return Msdp::DeviceStatus::DragResult::DRAG_CANCEL;
        default:
            return Msdp::DeviceStatus::DragResult::DRAG_SUCCESS;
    }
}

DragRet TranslateDragResult(Msdp::DeviceStatus::DragResult dragResult)
{
    switch (dragResult) {
        case Msdp::DeviceStatus::DragResult::DRAG_SUCCESS:
            return DragRet::DRAG_SUCCESS;
        case Msdp::DeviceStatus::DragResult::DRAG_FAIL:
            return DragRet::DRAG_FAIL;
        case Msdp::DeviceStatus::DragResult::DRAG_CANCEL:
            return DragRet::DRAG_CANCEL;
        default:
            return DragRet::DRAG_SUCCESS;
    }
}

Msdp::DeviceStatus::DragBehavior TranslateDragBehavior(OHOS::Ace::DragBehavior dragBehavior)
{
    switch (dragBehavior) {
        case OHOS::Ace::DragBehavior::COPY:
            return Msdp::DeviceStatus::DragBehavior::COPY;
        case OHOS::Ace::DragBehavior::MOVE:
            return Msdp::DeviceStatus::DragBehavior::MOVE;
        default:
            return Msdp::DeviceStatus::DragBehavior::UNKNOWN;
    }
}

OHOS::Ace::DragBehavior TranslateDragBehavior(Msdp::DeviceStatus::DragBehavior dragBehavior)
{
    switch (dragBehavior) {
        case Msdp::DeviceStatus::DragBehavior::COPY:
            return OHOS::Ace::DragBehavior::COPY;
        case Msdp::DeviceStatus::DragBehavior::MOVE:
            return OHOS::Ace::DragBehavior::MOVE;
        default:
            return OHOS::Ace::DragBehavior::UNKNOWN;
    }
}
#endif

} // namespace OHOS::Ace
