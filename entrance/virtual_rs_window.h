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

#include "refbase.h"
#include "render_service_client/core/ui/rs_surface_node.h"
#include "vsync_receiver.h"
#include "foundation/appframework/window_manager/interfaces/innerkits/wm/wm_common.h"
#include "foundation/appframework/window_manager/interfaces/innerkits/wm/window_interface.h"
#include "core/event/touch_event.h"

class NativeEngine;
typedef struct napi_value__* napi_value;
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
using NotifyNativeWinDestroyFunc = std::function<void(std::string windowName)>;
using NotifyWillTerminateFunc = std::function<void()>;
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

/**
 * @brief Enumerates occupied area type.
 */
enum class OccupiedAreaType : uint32_t {
    TYPE_INPUT, // area of input window
};

/**
 * @class IOccupiedAreaChangeListener
 *
 * @brief IOccupiedAreaChangeListener is used to observe OccupiedArea change.
 */
class IOccupiedAreaChangeListener : public RefBase {
public:
    /**
     * @brief Notify caller when OccupiedArea size change.
     *
     * @param info Occupied area info when occupied changed.
     */
    virtual void OnSizeChange(const Rect &rect, OccupiedAreaType type) {}
};

class Window : public RefBase {
#define CALL_LIFECYCLE_LISTENER(windowLifecycleCb, listeners) \
    do {                                                      \
        for (auto& listener : (listeners)) {                  \
            if (listener.GetRefPtr() != nullptr) {            \
                listener.GetRefPtr()->windowLifecycleCb();    \
            }                                                 \
        }                                                     \
    } while (0)
public:
    static std::shared_ptr<Window> Create(
        std::shared_ptr<OHOS::AbilityRuntime::Platform::Context> context, void* windowView);

    static std::shared_ptr<Window> CreateSubWindow(
        std::shared_ptr<OHOS::AbilityRuntime::Platform::Context> context,
        std::shared_ptr<OHOS::Rosen::WindowOption> option);
    explicit Window(std::shared_ptr<AbilityRuntime::Platform::Context> context, uint32_t windowId);
    virtual ~Window() override;
    static std::vector<std::shared_ptr<Window>> GetSubWindow(uint32_t parentId);
    static std::shared_ptr<Window> FindWindow(const std::string& name);
    static std::shared_ptr<Window> GetTopWindow(
        const std::shared_ptr<OHOS::AbilityRuntime::Platform::Context>& context = nullptr);

    WMError ShowWindow();
    WMError MoveWindowTo(int32_t x, int32_t y);
    WMError ResizeWindowTo(int32_t width, int32_t height);

   
    bool CreateVSyncReceiver(std::shared_ptr<AppExecFwk::EventHandler> handler);
    void RequestNextVsync(std::function<void(int64_t, void*)> callback);

    virtual void FlushFrameRate(int32_t rate) {}
    virtual void RequestVsync(const std::shared_ptr<VsyncCallback>& vsyncCallback);

    void CreateSurfaceNode(void* layer);
    void NotifySurfaceChanged(int32_t width, int32_t height, float density);
    void NotifyKeyboardHeightChanged(int32_t height);
    void NotifySurfaceDestroyed();

    bool ProcessBackPressed();
    bool ProcessPointerEvent(const std::vector<uint8_t>& data);
    bool ProcessKeyEvent(
        int32_t keyCode, int32_t keyAction, int32_t repeatTime, int64_t timeStamp = 0, int64_t timeStampStart = 0, int32_t metaKey = 0);

    WMError SetUIContent(const std::string& contentInfo, NativeEngine* engine, napi_value storage, bool isdistributed,
        AbilityRuntime::Platform::Ability* ability);
    Ace::Platform::UIContent* GetUIContent();
        
    WMError SetBackgroundColor(uint32_t color);

    uint32_t GetBackgroundColor() const
    {
        return backgroundColor_;
    }
    WMError SetBrightness(float brightness);
    float GetBrightness() const;
    WMError SetKeepScreenOn(bool keepScreenOn);
    bool IsKeepScreenOn();
    WMError SetSystemBarProperty(WindowType type, const SystemBarProperty& property);
    void WindowFocusChanged(bool hasWindowFocus);
    void Foreground();
    void Background();
    WMError Destroy();
    void RegisterWindowDestroyedListener(const NotifyNativeWinDestroyFunc& func);
    void RegisterWillTerminateListener(const NotifyWillTerminateFunc& func);

    WMError RegisterOccupiedAreaChangeListener(const sptr<IOccupiedAreaChangeListener> &listener);
    WMError UnregisterOccupiedAreaChangeListener(const sptr<IOccupiedAreaChangeListener> &listener);

    WMError SetColorSpace(ColorSpace colorSpace);
    ColorSpace GetColorSpace() const;

    bool IsSubWindow() const
    {
        return windowType_  == OHOS::Rosen::WindowType::WINDOW_TYPE_APP_SUB_WINDOW;
    }

    uint32_t GetWindowId() const
    {
        return windowId_;
    }

    uint32_t GetParentId() const
    {
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
  
    std::string& GetWindowName()
    {
        return name_;
    }

    Rect GetRect()
    {
        return rect_;
    }

    WindowType GetType()
    {
        return windowType_;
    }

    WindowMode GetMode()
    {
        return windowMode_;
    }

    WindowState GetWindowState()
    {
        return state_;
    }

    void UpdateOtherWindowFocusStateToFalse(Window *window);
    SystemBarProperty GetSystemBarPropertyByType(WindowType type) const;
    void SetRequestedOrientation(Orientation);
    WMError RegisterLifeCycleListener(const sptr<IWindowLifeCycle>& listener);
    WMError UnregisterLifeCycleListener(const sptr<IWindowLifeCycle>& listener);
    bool ProcessBasicEvent(const std::vector<Ace::TouchEvent>& touchEvents);
    int64_t GetVSyncPeriod()
    {
        return static_cast<int64_t>(1000000000.0f / 60); // SyncPeriod of 60 fps
    }
    void NotifyWillTeminate();
    void SetFocusable(bool focusable);
    bool GetFocusable() const;
private:
    void SetWindowView(WindowView* windowView);
    void SetWindowName(const std::string& windowName);
    void SetWindowType(WindowType windowType);
    void SetParentId(uint32_t parentId);
    void ReleaseWindowView();

    void DelayNotifyUIContentIfNeeded();
    bool IsWindowValid() const;

    GraphicColorGamut GetSurfaceGamutFromColorSpace(ColorSpace colorSpace) const;
    ColorSpace GetColorSpaceFromSurfaceGamut(GraphicColorGamut colorGamut) const;

    bool isActive_ = false;
    bool focusable_ = true;
    template<typename T1, typename T2, typename Ret>
    using EnableIfSame = typename std::enable_if<std::is_same_v<T1, T2>, Ret>::type;
    template<typename T> WMError RegisterListener(std::vector<sptr<T>>& holder, const sptr<T>& listener);
    template<typename T> WMError UnregisterListener(std::vector<sptr<T>>& holder, const sptr<T>& listener);
    template<typename T> void ClearUselessListeners(std::map<uint32_t, T>& listeners, uint32_t winId)
    {
        listeners.erase(winId);
    }
    template <typename T>
    inline EnableIfSame<T, IOccupiedAreaChangeListener, std::vector<sptr<IOccupiedAreaChangeListener>>> GetListeners()
    {
        std::vector<sptr<IOccupiedAreaChangeListener>> occupiedAreaChangeListeners;
        {
            std::lock_guard<std::recursive_mutex> lock(globalMutex_);
            for (auto &listener : occupiedAreaChangeListeners_[GetWindowId()]) {
                occupiedAreaChangeListeners.push_back(listener);
            }
        }
        return occupiedAreaChangeListeners;
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
        CALL_LIFECYCLE_LISTENER(AfterFocused, lifecycleListeners);
    }

    inline void NotifyAfterInactive()
    {
        auto lifecycleListeners = GetListeners<IWindowLifeCycle>();
        CALL_LIFECYCLE_LISTENER(AfterUnfocused, lifecycleListeners);
    }

    inline void NotifyBeforeDestroy(std::string windowName)
    {
        std::lock_guard<std::recursive_mutex> lock(globalMutex_);
        if (notifyNativefunc_) {
            notifyNativefunc_(windowName);
        }
    }

    void ClearListenersById(uint32_t winId);

private:
    int32_t surfaceWidth_ = 0;
    int32_t surfaceHeight_ = 0;
    Rect rect_ = {0, 0, 0, 0};
    std::string name_;
    float density_ = 0;
    std::shared_ptr<RSSurfaceNode> surfaceNode_;
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

    NotifyNativeWinDestroyFunc notifyNativefunc_;
    NotifyWillTerminateFunc notifyWillTerminatefunc_;
    static std::map<uint32_t, std::vector<sptr<IOccupiedAreaChangeListener>>> occupiedAreaChangeListeners_;
    static std::recursive_mutex globalMutex_;
    bool delayNotifySurfaceCreated_ = false;
    bool delayNotifySurfaceChanged_ = false;
    bool delayNotifySurfaceDestroyed_ = false;
    uint32_t windowId_ = 0;
    uint32_t parentId_ = 0;
    WindowMode windowMode_;
    WindowType windowType_;
    uint32_t backgroundColor_;
    float brightness_ = 0.0;
    WindowState state_ { WindowState::STATE_INITIAL };

    static void AddToWindowMap(std::shared_ptr<Window> window);
    static void DeleteFromWindowMap(std::shared_ptr<Window> window);
    static void DeleteFromWindowMap(Window* window);
    static void AddToSubWindowMap(std::shared_ptr<Window> window);
    static void DeleteFromSubWindowMap(std::shared_ptr<Window> window);
    static void ShowSubWindowMap(const std::string& str, uint32_t parentId);
    static bool CheckWindowNameExist(const std::string& windowName);

    static std::map<std::string, std::pair<uint32_t, std::shared_ptr<Window>>> windowMap_;
    static std::map<uint32_t, std::vector<std::shared_ptr<Window>>> subWindowMap_;
    static std::map<uint32_t, std::vector<sptr<IWindowLifeCycle>>> lifecycleListeners_;

    ACE_DISALLOW_COPY_AND_MOVE(Window);

    static std::atomic<uint32_t> tempWindowId;
};
} // namespace Rosen
} // namespace OHOS
#endif // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_VIRTUAL_RS_WINDOW_H
