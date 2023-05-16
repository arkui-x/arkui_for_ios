/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_VIRTUAL_RS_WINDOW_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_VIRTUAL_RS_WINDOW_H

#include <memory>
#include <map>


#include "base/log/log.h"
#include "base/utils/noncopyable.h"

#include "flutter/shell/common/vsync_waiter.h"
#include "refbase.h"
#include "render_service_client/core/ui/rs_surface_node.h"
#include "vsync_receiver.h"
#include "foundation/appframework/window_manager/interfaces/innerkits/wm/wm_common.h"
#include "foundation/appframework/window_manager/interfaces/innerkits/wm/window_interface.h"

class NativeValue;
class NativeEngine;
#ifdef __OBJC__  
@class WindowView;
@class UIViewController;  
#else  
typedef struct objc_object WindowView;
typedef struct objc_object UIViewController;
#endif

namespace OHOS {
namespace AbilityRuntime::Platform {
class Context;
class Configuration;
class Ability;
}

namespace Ace::Platform {
class UIContent;
}

namespace AppExecFwk {
class EventHandler;
}

namespace Rosen {
class IWindowLifeCycle;
class WindowOption;
using OnCallback = std::function<void(int64_t)>;
struct VsyncCallback {
    OnCallback onCallback;
};
class VSyncReceiver;

enum class WindowSizeChangeReason : uint32_t {
    UNDEFINED = 0,
    MAXIMIZE,
    RECOVER,
    ROTATION,
    DRAG,
    DRAG_START,
    DRAG_END,
    RESIZE,
    MOVE,
    HIDE,
    TRANSFORM,
    CUSTOM_ANIMATION_SHOW,
    FULL_TO_SPLIT,
    SPLIT_TO_FULL,
    END,
};

class Window : public RefBase{
#define CALL_LIFECYCLE_LISTENER(windowLifecycleCb, listeners) \
    do {                                                      \
        for (auto& listener : (listeners)) {                  \
            LOGI("Window: notify listener"); \
            if (listener.GetRefPtr() != nullptr) {            \
                listener.GetRefPtr()->windowLifecycleCb();    \
                LOGI("Window: notify listener not nullptr"); \
            }                                                 \
        }                                                     \
    } while (0)    
public:
    static std::shared_ptr<Window> Create(
        std::shared_ptr<OHOS::AbilityRuntime::Platform::Context> context, void* windowView);

    static std::shared_ptr<Window> CreateSubWindow(
        std::shared_ptr<OHOS::AbilityRuntime::Platform::Context> context, 
        std::shared_ptr<OHOS::Rosen::WindowOption> option);
    explicit Window(const flutter::TaskRunners& taskRunners);
    explicit Window(std::shared_ptr<AbilityRuntime::Platform::Context> context, uint32_t windowId);
    virtual ~Window() override;
    static std::vector<std::shared_ptr<Window>> GetSubWindow(uint32_t parentId);
    static std::shared_ptr<Window> FindWindow(const std::string& name);
    static std::shared_ptr<Window> GetTopWindow(const std::shared_ptr<OHOS::AbilityRuntime::Platform::Context>& context = nullptr);

    WMError ShowWindow();
    WMError DestroyWindow();
    WMError MoveWindowTo(int32_t x, int32_t y);
    WMError ResizeWindowTo(int32_t width, int32_t height);

    bool CreateVSyncReceiver(std::shared_ptr<AppExecFwk::EventHandler> handler);
    void RequestNextVsync(std::function<void(int64_t, void*)> callback);

    virtual void RequestVsync(const std::shared_ptr<VsyncCallback>& vsyncCallback);

    void CreateSurfaceNode(void* layer);
    void NotifySurfaceChanged(int32_t width, int32_t height, float density);
    void NotifySurfaceDestroyed();

    bool ProcessPointerEvent(const std::vector<uint8_t>& data);
    bool ProcessKeyEvent(
        int32_t keyCode, int32_t keyAction, int32_t repeatTime, int64_t timeStamp = 0, int64_t timeStampStart = 0);

    int SetUIContent(const std::string& contentInfo, NativeEngine* engine,
        NativeValue* storage, bool isdistributed, AbilityRuntime::Platform::Ability* ability);
        
    WMError SetBackgroundColor(uint32_t color);
    uint32_t GetBackgroundColor() const 
    {
        return backgroundColor_;
    }
    WMError SetBrightness(float brightness);
    float GetBrightness() const 
    {
        return 0;
    }
    WMError SetKeepScreenOn(bool keepScreenOn);
    bool IsKeepScreenOn();
    WMError SetSystemBarProperty(WindowType type, const SystemBarProperty& property);
    void WindowFocusChanged(bool hasWindowFocus);
    void Foreground();
    void Background();
    void Destroy();
    bool IsSubWindow() const{
        return windowType_  == OHOS::Rosen::WindowType::WINDOW_TYPE_APP_SUB_WINDOW;
    }
    uint32_t GetWindowId() const{
        return windowId_;
    }
    uint32_t GetParentId() const{
        return parentId_;
    }
    std::shared_ptr<RSSurfaceNode> GetSurfaceNode() const
    {
        return surfaceNode_;
    }

    void UpdateConfiguration(const std::shared_ptr<OHOS::AbilityRuntime::Platform::Configuration>& config);

    bool IsWindowShow() 
    {
        return isWindowShow_;
    }
  
    std::string& GetWindowName() {
        return name_;
    }

    Rect GetRect() {
        return rect_;
    }

    WindowType GetType() {
        return windowType_;
    }

    WindowMode GetMode() {
        return windowMode_;
    }

    WindowState GetWindowState() {
        return state_;
    }

    SystemBarProperty GetSystemBarPropertyByType(WindowType type) const;
    void SetRequestedOrientation(Orientation);
    WMError RegisterLifeCycleListener(const sptr<IWindowLifeCycle>& listener);
    WMError UnregisterLifeCycleListener(const sptr<IWindowLifeCycle>& listener);

private:
    void SetWindowView(WindowView* windowView);
    void ReleaseWindowView();

    void DelayNotifyUIContentIfNeeded();
    bool IsWindowValid() const;
    
    template<typename T1, typename T2, typename Ret>
    using EnableIfSame = typename std::enable_if<std::is_same_v<T1, T2>, Ret>::type;
    template<typename T> WMError RegisterListener(std::vector<sptr<T>>& holder, const sptr<T>& listener);
    template<typename T> WMError UnregisterListener(std::vector<sptr<T>>& holder, const sptr<T>& listener);
    template<typename T> void ClearUselessListeners(std::map<uint32_t, T>& listeners, uint32_t winId)
    {
        listeners.erase(winId);
    }
    template<typename T>
    inline EnableIfSame<T, IWindowLifeCycle, std::vector<wptr<IWindowLifeCycle>>> GetListeners()
    {
        std::vector<wptr<IWindowLifeCycle>> lifecycleListeners;
        {
            std::lock_guard<std::recursive_mutex> lock(globalMutex_);
            for (auto& listener : lifecycleListeners_[GetWindowId()]) {
                lifecycleListeners.push_back(listener);
            }
        }
        return lifecycleListeners;
    }
    inline void NotifyAfterForeground(bool needNotifyListeners = true, bool needNotifyUiContent = true)
    {
        if (needNotifyListeners) {
            auto lifecycleListeners = GetListeners<IWindowLifeCycle>();
            CALL_LIFECYCLE_LISTENER(AfterForeground, lifecycleListeners);
        }
    }

    inline void NotifyAfterBackground(bool needNotifyListeners = true, bool needNotifyUiContent = true)
    {
        if (needNotifyListeners) {
            auto lifecycleListeners = GetListeners<IWindowLifeCycle>();
            CALL_LIFECYCLE_LISTENER(AfterBackground, lifecycleListeners);
        }
    }
  
    inline void NotifyAfterActive()
    {
        auto lifecycleListeners = GetListeners<IWindowLifeCycle>();
        CALL_LIFECYCLE_LISTENER(AfterActive, lifecycleListeners);
    }

    inline void NotifyAfterInactive()
    {
        auto lifecycleListeners = GetListeners<IWindowLifeCycle>();
        CALL_LIFECYCLE_LISTENER(AfterInactive, lifecycleListeners);
    }
    void ClearListenersById(uint32_t winId);
    void DestroySubWindow();

    int32_t surfaceWidth_ = 0;
    int32_t surfaceHeight_ = 0;
    Rect rect_ = {0, 0, 0, 0};
    std::string name_;
    float density_ = 0;
    std::shared_ptr<RSSurfaceNode> surfaceNode_;
    std::shared_ptr<flutter::VsyncWaiter> vsyncWaiter_;
    bool isWindowShow_ = false;
    WindowView* windowView_ = nullptr;
    std::shared_ptr<UIViewController> viewController_ = nullptr;
    std::shared_ptr<AbilityRuntime::Platform::Context> context_;
    std::unique_ptr<OHOS::Ace::Platform::UIContent> uiContent_;

    std::shared_ptr<VSyncReceiver> receiver_ = nullptr;

    std::unordered_map<WindowType, SystemBarProperty> sysBarPropMap_ {
        { WindowType::WINDOW_TYPE_STATUS_BAR,     SystemBarProperty() },
        { WindowType::WINDOW_TYPE_NAVIGATION_BAR, SystemBarProperty() },
    };

    static std::recursive_mutex globalMutex_;
    bool delayNotifySurfaceCreated_ = false;
    bool delayNotifySurfaceChanged_ = false;
    bool delayNotifySurfaceDestroyed_ = false;
    uint32_t windowId_ = 0;
    uint32_t parentId_ = 0;
    WindowMode windowMode_;
    WindowType windowType_;
    uint32_t backgroundColor_;
    WindowState state_ { WindowState::STATE_INITIAL };
    static std::map<uint32_t, std::vector<std::shared_ptr<Window>>> subWindowMap_;
    static std::map<std::string, std::pair<uint32_t, std::shared_ptr<Window>>> windowMap_;
    static std::map<uint32_t, std::vector<sptr<IWindowLifeCycle>>> lifecycleListeners_;
   
    ACE_DISALLOW_COPY_AND_MOVE(Window);
};

} // namespace Rosen
} // namespace OHOS
#endif // FOUNDATION_ACE_ADAPTER_ANDROID_ENTRANCE_JAVA_JNI_VIRTUAL_RS_WINDOW_H
