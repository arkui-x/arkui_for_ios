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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_STAGE_ACE_VIEW_SG_H
#define FOUNDATION_ACE_ADAPTER_IOS_STAGE_ACE_VIEW_SG_H

#include <memory>

#include "interfaces/inner_api/ace/viewport_config.h"

#include "base/memory/referenced.h"
#include "base/utils/noncopyable.h"
#include "core/common/ace_view.h"
#include "core/common/platform_res_register.h"
#include "core/event/key_event_recognizer.h"

#ifdef ENABLE_ROSEN_BACKEND
#include "core/common/thread_model_impl.h"
#endif

#include "adapter/ios/entrance/virtual_rs_window.h"
#include "adapter/ios/entrance/mmi_event_convertor.h"
#include "core/event/touch_event.h"
#include "core/pipeline_ng/pipeline_context.h"

namespace OHOS::Ace::Platform {
class ACE_FORCE_EXPORT AceViewSG : public AceView {
public:
    explicit AceViewSG(int32_t id) : instanceId_(id)
    {
#ifdef ENABLE_ROSEN_BACKEND
        threadModel_ = ThreadModelImpl::CreateThreadModel(true, false, false);
#endif
    }
    ~AceViewSG() override = default;

    static AceViewSG* CreateView(int32_t instanceId);
    static void SurfaceCreated(AceViewSG* view, OHOS::Rosen::Window* window);
    static void SurfaceChanged(AceViewSG* view, int32_t width, int32_t height, int32_t orientation,
        WindowSizeChangeReason type = WindowSizeChangeReason::UNDEFINED);
    static void SurfacePositionChanged(AceViewSG* view, int32_t posX, int32_t posY);
    static void SetViewportMetrics(AceViewSG* view, const ViewportConfig& config);

    struct KeyEventInfo {
        int32_t keyCode {};
        int32_t keyAction {};
        int32_t repeatTime {};
        int64_t timeStamp {};
        int64_t timeStampStart {};
        int32_t metaKey {};
        int32_t sourceDevice {};
        int32_t deviceId {};
        std::string msg {};
    };

    int32_t GetInstanceId() const override
    {
        return instanceId_;
    }

    void RegisterTouchEventCallback(TouchEventCallback&& callback) override;
    void RegisterKeyEventCallback(KeyEventCallback&& callback) override;
    void RegisterNonPointerEventCallback(NonPointerEventCallback&& callback) override {}
    void RegisterMouseEventCallback(MouseEventCallback&& callback) override;
    void RegisterRotationEventCallback(RotationEventCallBack&& callback) override;
    void RegisterViewChangeCallback(ViewChangeCallback&& callback) override;
    void RegisterDensityChangeCallback(DensityChangeCallback&& callback) override;
    void RegisterSurfaceDestroyCallback(SurfaceDestroyCallback&& callback) override;
    void RegisterDragEventCallback(DragEventCallBack&& callback) override;
    void RegisterAxisEventCallback(AxisEventCallback&& callback) override;
    void RegisterCardViewPositionCallback(CardViewPositionCallBack&& callback) override {}
    void RegisterCrownEventCallback(CrownEventCallback&& callback) override;
    void RegisterTouchpadInteractionBeginCallback(TouchpadInteractionBeginCallback&& callback) override;
    void RegisterCardViewAccessibilityParamsCallback(CardViewAccessibilityParamsCallback&& callback) override {}
    void RegisterViewPositionChangeCallback(ViewPositionChangeCallback&& callback) override;
    void RegisterTransformHintChangeCallback(TransformHintChangeCallback&& callback) override {}
    void RegisterSystemBarHeightChangeCallback(SystemBarHeightChangeCallback&& callback) override;
    void RegisterIdleCallback(IdleCallback&& callback) override {}
    bool DispatchBasicEvent (const std::vector<TouchEvent>& touchEvents);

    bool Dump(const std::vector<std::string>& params) override;
    const void* GetNativeWindowById(uint64_t textureId) override;
    std::unique_ptr<DrawDelegate> GetDrawDelegate() override;
    std::unique_ptr<PlatformWindow> GetPlatformWindow() override;

    void Launch() override;

#ifdef ENABLE_ROSEN_BACKEND
    ThreadModelImpl* GetThreadModel()
    {
        return threadModel_.get();
    }
#endif

    bool DispatchTouchEvent(const std::shared_ptr<MMI::PointerEvent>& pointerEvent,
        const RefPtr<OHOS::Ace::NG::FrameNode>& node = nullptr, const std::function<void()>& callback = nullptr);
    bool DispatchTouchEventTargetHitTest(const std::shared_ptr<OHOS::MMI::PointerEvent>& pointerEvent, const std::string& target);
    bool DispatchKeyEvent(const KeyEventInfo& eventInfo);

    void DispatchEventToPerf(const TouchEvent& pointerEvent);
    void DispatchEventToPerf(const KeyEvent& keyEvent);

    void NotifySurfaceDestroyed() const;
    void NotifySurfaceChanged(int32_t width, int32_t height, WindowSizeChangeReason type);
    void NotifyDensityChanged(double density);

    void ProcessTouchEvent(const std::shared_ptr<MMI::PointerEvent>& pointerEvent,
        const RefPtr<OHOS::Ace::NG::FrameNode>& node = nullptr, const std::function<void()>& callback = nullptr);
    void ProcessDragEvent(const std::shared_ptr<MMI::PointerEvent>& pointerEvent, const RefPtr<OHOS::Ace::NG::FrameNode>& node);
    void ProcessDragEvent(int32_t x, int32_t y, const DragEventAction& action, const RefPtr<OHOS::Ace::NG::FrameNode>& node);

    void SetPlatformResRegister(const RefPtr<PlatformResRegister>& resRegister)
    {
        resRegister_ = resRegister;
    }

    const RefPtr<PlatformResRegister>& GetPlatformResRegister() const override
    {
        return resRegister_;
    }

    ViewType GetViewType() const override
    {
        return AceView::ViewType::SURFACE_VIEW;
    }

private:
    bool IsLastPage() const;
    void NotifySurfacePositionChanged(int32_t posX, int32_t posY);

    int32_t instanceId_ = -1;

    TouchEventCallback touchEventCallback_;
    MouseEventCallback mouseEventCallback_;
    AxisEventCallback axisEventCallback_;
    CrownEventCallback crownEventCallback_;
    TouchpadInteractionBeginCallback touchpadInteractionBeginCallback_;
    RotationEventCallBack rotationEventCallback_;
    ViewChangeCallback viewChangeCallback_;
    ViewPositionChangeCallback viewPositionChangeCallback_;
    DensityChangeCallback densityChangeCallback_;
    SystemBarHeightChangeCallback systemBarHeightChangeCallback_;
    SurfaceDestroyCallback surfaceDestroyCallback_;
    DragEventCallBack dragEventCallback_;
    KeyEventCallback keyEventCallback_;
    KeyEventRecognizer keyEventRecognizer_;

    RefPtr<PlatformResRegister> resRegister_;

#ifdef ENABLE_ROSEN_BACKEND
    std::unique_ptr<ThreadModelImpl> threadModel_;
    sptr<Rosen::Window> rsWinodw_;
#endif

    ACE_DISALLOW_COPY_AND_MOVE(AceViewSG);
};
} // namespace OHOS::Ace::Platform

#endif // FOUNDATION_ACE_ADAPTER_IOS_STAGE_ACE_VIEW_SG_H
