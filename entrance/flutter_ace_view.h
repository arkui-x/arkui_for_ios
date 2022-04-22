/*
 * Copyright (c) 2021 Huawei Device Co., Ltd.
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

#ifndef FOUNDATION_ACE_ADAPTER_PREVIEW_FLUTTER_ACE_VIEW_H
#define FOUNDATION_ACE_ADAPTER_PREVIEW_FLUTTER_ACE_VIEW_H

#include <memory>

#include "adapter/ios/entrance/ace_resource_register.h"
#include "base/utils/noncopyable.h"
#include "core/common/ace_view.h"
#include "core/event/key_event_recognizer.h"
#include "flutter/lib/ui/window/pointer_data_packet.h"

namespace OHOS::Ace::Platform {

using ReleaseCallback = std::function<void()>;

class FlutterAceView : public AceView, public Referenced {
public:
    explicit FlutterAceView(int32_t instanceId) : instanceId_(instanceId) {}
    ~FlutterAceView() override = default;

    void RegisterTouchEventCallback(TouchEventCallback&& callback) override;
    void RegisterDragEventCallback(DragEventCallBack&& callback) override;
    void RegisterKeyEventCallback(KeyEventCallback&& callback) override;
    void RegisterMouseEventCallback(MouseEventCallback&& callback) override;
    void RegisterAxisEventCallback(AxisEventCallback&& callback) override;
    void RegisterRotationEventCallback(RotationEventCallBack&& callback) override;
//    void RegisterViewDestroyCallback(ViewDestoryCallback&& callback) override;
    static uint32_t GetBackgroundColor();
    void Launch() override;

    int32_t GetInstanceId() const override
    {
        return instanceId_;
    }

    void RegisterCardViewPositionCallback(CardViewPositionCallBack&& callback) override
    {
        if (callback) {
            cardViewPositionCallBack_ = std::move(callback);
        }
    }

    void RegisterCardViewAccessibilityParamsCallback(CardViewAccessibilityParamsCallback&& callback) override
    {
        if (callback) {
            cardViewAccessibilityParamsCallback_ = std::move(callback);
        }
    }

    void RegisterViewChangeCallback(ViewChangeCallback&& callback) override
    {
        if (callback) {
            viewChangeCallback_ = std::move(callback);
        }
    }

    void RegisterDensityChangeCallback(DensityChangeCallback&& callback) override
    {
        if (callback) {
            densityChangeCallback_ = std::move(callback);
        }
    }

    void RegisterSystemBarHeightChangeCallback(SystemBarHeightChangeCallback&& callback) override
    {
        if (callback) {
            systemBarHeightChangeCallback_ = std::move(callback);
        }
    }

    void RegisterSurfaceDestroyCallback(SurfaceDestroyCallback&& callback) override
    {
        if (callback) {
            surfaceDestroyCallback_ = std::move(callback);
        }
    }

    void RegisterIdleCallback(IdleCallback&& callback) override
    {
        if (callback) {
            idleCallback_ = std::move(callback);
        }
    } 
    
    void SetPlatformResRegister(const RefPtr<PlatformResRegister>& resRegister)
    {
        resRegister_ = resRegister;
    }

    const RefPtr<PlatformResRegister>& GetPlatformResRegister() const override
    {
        return resRegister_;
    }

    bool Dump(const std::vector<std::string>& params) override;

    void ProcessIdleEvent(int64_t deadline);

    void NotifySurfaceChanged(int32_t width, int32_t height, WindowSizeChangeReason type)
    {
        width_ = width;
        height_ = height;
        if (viewChangeCallback_) {
            viewChangeCallback_(width, height, type);
        }
    }

    void NotifyDensityChanged(double density) const
    {
        if (densityChangeCallback_) {
            densityChangeCallback_(density);
        }
    }

    void NotifySystemBarHeightChanged(double statusBar, double navigationBar) const
    {
        if (systemBarHeightChangeCallback_) {
            systemBarHeightChangeCallback_(statusBar, navigationBar);
        }
    }

    void NotifySurfaceDestroyed() const
    {
        if (surfaceDestroyCallback_) {
            surfaceDestroyCallback_();
        }
    }

    // Use to receive event from glfw window
    bool HandleTouchEvent(const std::vector<uint8_t>& data) override;

    // Use to receive event from pc previewer
    bool HandleTouchEvent(const TouchEvent& touchEvent) override;

    ViewType GetViewType() const override
    {
        return AceView::ViewType::SURFACE_VIEW;
    }

    std::unique_ptr<DrawDelegate> GetDrawDelegate() override;
    std::unique_ptr<PlatformWindow> GetPlatformWindow() override;
    const void* GetNativeWindowById(uint64_t textureId) override;

private:
    int32_t instanceId_ = 0;
    RefPtr<PlatformResRegister> resRegister_;

    TouchEventCallback touchEventCallback_;
    MouseEventCallback mouseEventCallback_;
    AxisEventCallback axisEventCallback_;
    RotationEventCallBack rotationEventCallBack_;
    CardViewPositionCallBack cardViewPositionCallBack_;
    CardViewAccessibilityParamsCallback cardViewAccessibilityParamsCallback_;
    ViewChangeCallback viewChangeCallback_;
    DensityChangeCallback densityChangeCallback_;
    SystemBarHeightChangeCallback systemBarHeightChangeCallback_;
    SurfaceDestroyCallback surfaceDestroyCallback_;
    IdleCallback idleCallback_;
    DragEventCallBack dragEventCallback_;
    KeyEventCallback keyEventCallback_;
    KeyEventRecognizer keyEventRecognizer_;

    ACE_DISALLOW_COPY_AND_MOVE(FlutterAceView);
};

} // namespace OHOS::Ace::Platform

#endif // FOUNDATION_ACE_ADAPTER_PREVIEW_FLUTTER_ACE_VIEW_H
