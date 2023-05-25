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

#include "adapter/ios/entrance/virtual_rs_window.h"

#include <__nullptr>
#include <_types/_uint32_t.h>
#include <memory>
#include <UIKit/UIKit.h>
#include <objc/objc.h>
#include "WindowView.h"
#include "base/log/log.h"
#include "flutter/shell/platform/darwin/ios/framework/Source/vsync_waiter_ios.h"
#include "foundation/appframework/arkui/uicontent/ui_content.h"
#include "shell/common/vsync_waiter.h"
#include "transaction/rs_interfaces.h"
#include "virtual_rs_window.h"
#include "StageViewController.h"
#include "StageApplication.h"
#include "window_view_adapter.h"
#include "window_interface.h"
#include "window_option.h"
#include "hilog.h"

namespace OHOS::Rosen {

std::map<uint32_t, std::vector<std::shared_ptr<Window>>> Window::subWindowMap_;
std::map<std::string, std::pair<uint32_t, std::shared_ptr<Window>>> Window::windowMap_;
std::map<uint32_t, std::vector<sptr<IWindowLifeCycle>>> Window::lifecycleListeners_;
std::recursive_mutex Window::globalMutex_;
std::atomic<uint32_t> Window::tempWindowId = INVALID_WINDOW_ID;

Window::Window(const flutter::TaskRunners& taskRunners)
    : vsyncWaiter_(std::make_shared<flutter::VsyncWaiterIOS>(taskRunners))
{}

Window::Window(std::shared_ptr<AbilityRuntime::Platform::Context> context, uint32_t windowId)
    : context_(context), windowId_(windowId)
{}

Window::~Window()
{
    LOGI("Window: release");
    ReleaseWindowView();
}

std::shared_ptr<Window> Window::Create(
    std::shared_ptr<OHOS::AbilityRuntime::Platform::Context> context, void* windowView)
{
    LOGI("Window::Create with %{public}p", windowView);

    std::string windowName = AbilityRuntime::Platform::WindowViewAdapter::GetInstance()->GetWindowName(windowView);
    if (CheckWindowNameExist(windowName)) {
        HILOG_ERROR("Window::Create : windowName exist! windowName=%{public}s", windowName.c_str());
        return nullptr;
    }
    
    uint32_t windowId = ++tempWindowId; // for test
    auto window = std::make_shared<Window>(context, windowId);
    window->SetWindowView((WindowView*)windowView);
    window->SetWindowName(windowName);
    [(WindowView*)windowView setWindowDelegate:window];
    AddToWindowMap(window);
    return window;
}

std::shared_ptr<Window> Window::CreateSubWindow(
        std::shared_ptr<OHOS::AbilityRuntime::Platform::Context> context, 
        std::shared_ptr<OHOS::Rosen::WindowOption> option)
{
    if (CheckWindowNameExist(option->GetWindowName())) {
        HILOG_ERROR("Window::CreateSubWindow : windowName exist! windowName=%{public}s", option->GetWindowName().c_str());
        return nullptr;
    }

    uint32_t windowId = ++tempWindowId;
    if (option->GetWindowType() != OHOS::Rosen::WindowType::WINDOW_TYPE_APP_SUB_WINDOW) {
        LOGI("Window::CreateSubWindow failed, window type error![windowType=%{public}d]", static_cast<int32_t>(option->GetWindowType()));
        return nullptr;
    }

    auto window = std::make_shared<Window>(context, windowId);
    WindowView* windowView = [[WindowView alloc]init];
    LOGI("Window::Createsubwindow with %{public}p", windowView);
    window->SetWindowView(windowView);
    [windowView setWindowDelegate:window]; 
    [windowView createSurfaceNode];
    [windowView setBackgroundColor:[UIColor redColor]];   // Jason: Test for set color
    window->SetWindowName(option->GetWindowName());
    window->SetWindowType(option->GetWindowType());
    LOGI("Window::Createsubwindow with name:%s, parentId=%{public}u", window->GetWindowName().c_str(), option->GetParentId());
    window->SetParentId(option->GetParentId());
    AddToSubWindowMap(window);
    AddToWindowMap(window);
    ShowSubWindowMap("Window::CreateSubWindow", window->GetParentId());
    
    return window;
}

void Window::AddToWindowMap(std::shared_ptr<Window> window)
{
    DeleteFromWindowMap(window);
    windowMap_.insert(std::make_pair(window->GetWindowName(), 
        std::pair<uint32_t, std::shared_ptr<Window>>(window->GetWindowId(), window)));
}

bool Window::CheckWindowNameExist(std::string windowName)
{
    auto iter = windowMap_.find(windowName);
    if (iter == windowMap_.end()) {
        return false;
    }
    return true;
}

void Window::DeleteFromWindowMap(std::shared_ptr<Window> window)
{
    auto iter = windowMap_.find(window->GetWindowName());
    if (iter != windowMap_.end()) {
        windowMap_.erase(iter);
    }
}
void Window::DeleteFromWindowMap(Window* window)
{
    if (window == nullptr) {
        return;
    }
    auto iter = windowMap_.find(window->GetWindowName());
    if (iter != windowMap_.end()) {
        windowMap_.erase(iter);
    }
}
void Window::AddToSubWindowMap(std::shared_ptr<Window> window)
{
    HILOG_INFO("Window::AddToSubWindowMap : Start...");
    if (window == nullptr) {
        HILOG_ERROR("window is null");
        return;
    }
    if (window->GetType() != OHOS::Rosen::WindowType::WINDOW_TYPE_APP_SUB_WINDOW ||
        window->GetParentId() == INVALID_WINDOW_ID) {
        HILOG_ERROR("window is not subwindow");
        return;
    }
    DeleteFromSubWindowMap(window);
    uint32_t parentId = window->GetParentId();
    subWindowMap_[parentId].push_back(window);
    HILOG_INFO("Window::AddToSubWindowMap : End!!!");
}
void Window::DeleteFromSubWindowMap(std::shared_ptr<Window> window)
{
    HILOG_INFO("Window::DeleteFromSubWindowMap : Start...");
    if (window == nullptr) {
        HILOG_INFO("Window::DeleteFromSubWindowMap : window is null");
        return;
    }
    uint32_t parentId = window->GetParentId();
    if (parentId == INVALID_WINDOW_ID) {
        HILOG_INFO("Window::DeleteFromSubWindowMap : parentId is invalid");
        return;
    }
    auto iter1 = subWindowMap_.find(parentId);
    if (iter1 == subWindowMap_.end()) {
        HILOG_INFO("Window::DeleteFromSubWindowMap : find parentId failed");
        return;
    }
    auto subWindows = iter1->second;
    auto iter2 = subWindows.begin();
    while (iter2 != subWindows.end()) {
        if (*iter2 == window) {
            subWindows.erase(iter2);
            ((*iter2)->Destroy());
            break;
        } else {
            iter2++;
        }
    }
    HILOG_INFO("Window::AddToSubWindowMap : End!!!");
}

void Window::ShowSubWindowMap(std::string str, uint32_t parentId)
{
    auto iter1 = subWindowMap_.find(parentId);
    if (iter1 == subWindowMap_.end()) {
        HILOG_INFO("Window::ShowSubWindowMap : %{public}s : find parentId failed! parentId=%{public}u",
            str.c_str(), parentId);
        return;
    }
    auto subWindows = iter1->second;
    auto iter2 = subWindows.begin();
    while (iter2 != subWindows.end()) {
        HILOG_INFO("Window::ShowSubWindowMap : %{public}s : windowId=%{public}u, windowName=%{public}s",
            str.c_str(), (*iter2)->GetWindowId(), (*iter2)->GetWindowName().c_str());
        iter2++;
    }
}

WMError Window::Destroy()
{
    if (uiContent_ != nullptr) {
        uiContent_->Destroy();
        uiContent_ = nullptr;
    }

    if (windowView_ != nullptr) {
        [windowView_ removeFromSuperview];
        windowView_ = nullptr;
    }

    isWindowShow_ = false;
    ClearListenersById(GetWindowId());

    // Remove subWindows of current window from subWindowMap_ 
    if (subWindowMap_.count(GetWindowId()) > 0) {
        auto& subWindows = subWindowMap_.at(GetWindowId());
        for (auto iter = subWindows.begin(); iter != subWindows.end(); iter = subWindows.begin()) {
            if ((*iter) == nullptr) {
                subWindows.erase(iter);
                continue;
            }
            subWindows.erase(iter);
            DeleteFromWindowMap(*iter);
            (*iter)->Destroy();
        }
        subWindowMap_[GetWindowId()].clear();
        subWindowMap_.erase(GetWindowId());
    }

    // Rmove current window from subWindowMap_ of parent window
    if (subWindowMap_.count(GetParentId()) > 0) {
        auto& subWindows = subWindowMap_.at(GetParentId());
        for (auto iter = subWindows.begin(); iter < subWindows.end(); ++iter) {
            if ((*iter) == nullptr) {
                continue;
            }
            if ((*iter)->GetWindowId() == GetWindowId()) {
                subWindows.erase(iter);
                break;
            }
        }
    }

    // Remove current window from windowMap_
    if (windowMap_.count(GetWindowName()) > 0) {
        DeleteFromWindowMap(this);
    }

    NotifyAfterBackground();
    return WMError::WM_OK;
}

const std::vector<std::shared_ptr<Window>>& Window::GetSubWindow(uint32_t parentId)
{
    HILOG_INFO("Window::GetSubWindow : Start... / parentId = %{public}u, subWIndowMapSize=%{public}u",
        parentId, subWindowMap_.size());
    if (subWindowMap_.find(parentId) == subWindowMap_.end()) {
        HILOG_INFO("Window::GetSubWindow : find subwindow failed");
        return std::vector<std::shared_ptr<Window>>();
    }
    HILOG_INFO("Window::GetSubWindow : find subwindow success, parentId=%u, subwindowSize=%u",
        parentId, subWindowMap_[parentId].size());
    ShowSubWindowMap("Window::GetSubWindow", parentId);
    return subWindowMap_[parentId];
}

std::shared_ptr<Window> Window::FindWindow(const std::string& name)
{
    auto iter = windowMap_.find(name);
    if (iter == windowMap_.end()) {
        return nullptr;
    }
    return iter->second.second;
}

std::shared_ptr<Window> Window::GetTopWindow(const std::shared_ptr<OHOS::AbilityRuntime::Platform::Context>& context)
{
    StageViewController *controller = [StageApplication getApplicationTopViewController];
    NSString *instanceName = controller.instanceName;
    WindowView *windowView = static_cast<WindowView*>(OHOS::AbilityRuntime::Platform
        ::WindowViewAdapter::GetInstance()->GetWindowView([instanceName UTF8String]));
    return [windowView getWindow]; 
}

WMError Window::ShowWindow() 
{
    if (!windowView_) {
        LOGE("Window: showWindow failed");
        return WMError::WM_ERROR_INVALID_PARENT;   
    }
   
    StageViewController *controller = [StageApplication getApplicationTopViewController];
     
    if (windowView_.superview) {
        [controller.view bringSubviewToFront:windowView_];
    } else {
        [controller.view addSubview:windowView_];
    }
    isWindowShow_ = true;
    NotifyAfterForeground();
    return WMError::WM_OK;
}



WMError Window::MoveWindowTo(int32_t x, int32_t y)
{   
    if (!windowView_) {
        LOGE("Window: MoveWindowTo failed");
        return WMError::WM_ERROR_INVALID_PARENT;   
    }
    x = x < 0 ? 0 : x;
    y = y < 0 ? 0 : y;
    windowView_.frame = CGRectMake(x, y, windowView_.frame.size.width, windowView_.frame.size.height);
    rect_.posX_ = x;
    rect_.posY_ = y;
    return WMError::WM_OK;
}


WMError Window::ResizeWindowTo(int32_t width, int32_t height) {
    
    if (!windowView_) {
        LOGE("Window: ResizeWindowTo failed");
        return WMError::WM_ERROR_INVALID_PARENT;   
    }
    LOGI("Window: ResizeWindowTo %d %d", width, height);
    UIScreen *screen = [UIScreen mainScreen];
    CGFloat scale = screen.scale;
    windowView_.bounds = CGRectMake(0, 0, width / scale, height / scale);
    rect_.width_ = width;
    rect_.height_ = height;
    return WMError::WM_OK;
}

bool Window::IsWindowValid() const
{
    bool res = ((state_ > WindowState::STATE_INITIAL) && (state_ < WindowState::STATE_BOTTOM));
    if (!res) {
        LOGW("already destroyed or not created! id: %{public}u", GetWindowId());
    }
    return res;
}

void Window::RequestVsync(const std::shared_ptr<VsyncCallback>& vsyncCallback)
{
    // stage model
    if (receiver_) {
        auto callback = [vsyncCallback](int64_t timestamp, void*) {
            vsyncCallback->onCallback(timestamp);
        };
        OHOS::Rosen::VSyncReceiver::FrameCallback fcb = {
            .userData_ = this,
            .callback_ = callback,
        };
        receiver_->RequestNextVSync(fcb);
        return;
    }

    // fa model
    if (vsyncWaiter_) {
        vsyncWaiter_->AsyncWaitForVsync([vsyncCallback](fml::TimePoint frameStart, fml::TimePoint frameTarget) {
            vsyncCallback->onCallback(frameStart.ToEpochDelta().ToNanoseconds());
        });
    }
}

bool Window::CreateVSyncReceiver(std::shared_ptr<AppExecFwk::EventHandler> handler)
{
    if (receiver_) {
        return true;
    }
    auto& rsClient = Rosen::RSInterfaces::GetInstance();
    receiver_ = rsClient.CreateVSyncReceiver("Window_IOS", handler);
    VsyncError ret = receiver_->Init();
    if (ret) {
        LOGE("Window_IOS: vsync receiver init failed: %{public}d", ret);
        return false;
    }
    return true;
}

void Window::RequestNextVsync(std::function<void(int64_t, void*)> callback)
{
    if (!receiver_) {
        return;
    }
    VSyncReceiver::FrameCallback fcb = {
        .userData_ = this,
        .callback_ = callback,
    };
    receiver_->RequestNextVSync(fcb);
}

void Window::CreateSurfaceNode(void* layer)
{
    struct OHOS::Rosen::RSSurfaceNodeConfig rsSurfaceNodeConfig = { .SurfaceNodeName = "arkui-x_surface",
        .additionalData = layer };
    surfaceNode_ = OHOS::Rosen::RSSurfaceNode::Create(rsSurfaceNodeConfig);

    if (!uiContent_) {
        LOGW("Window Notify uiContent_ Surface Created, uiContent_ is nullptr, delay notify.");
        delayNotifySurfaceCreated_ = true;
    } else {
        LOGI("Window Notify uiContent_ Surface Created");
        uiContent_->NotifySurfaceCreated();
    }
}

void Window::NotifySurfaceChanged(int32_t width, int32_t height, float density)
{
    if (!surfaceNode_) {
        LOGE("Window Notify Surface Changed, surfaceNode_ is nullptr!");
        return;
    }
    LOGI("Window Notify Surface Changed wh:[%{public}d, %{public}d]", width, height);
    surfaceWidth_ = width;
    surfaceHeight_ = height;
    rect_.width_ = width;
    rect_.height_ = height;
    
    surfaceNode_->SetBoundsWidth(surfaceWidth_);
    surfaceNode_->SetBoundsHeight(surfaceHeight_);
    density_ = density;

    if (!uiContent_) {
        LOGW("Window Notify uiContent_ Surface Created, uiContent_ is nullptr, delay notify.");
        delayNotifySurfaceChanged_ = true;
    } else {
        LOGI("Window Notify uiContent_ Surface Created");
        Ace::ViewportConfig config;
        config.SetDensity(density_);
        config.SetSize(surfaceWidth_, surfaceHeight_);
        config.SetOrientation(surfaceWidth_ <= surfaceHeight_ ? 0 : 1);
        uiContent_->UpdateViewportConfig(config, WindowSizeChangeReason::RESIZE);
    }
}

void Window::NotifySurfaceDestroyed()
{
    surfaceNode_ = nullptr;

    if (!uiContent_) {
        LOGW("Window Notify Surface Destroyed, uiContent_ is nullptr, delay notify.");
        delayNotifySurfaceDestroyed_ = true;
    } else {
        LOGI("Window Notify uiContent_ Surface Destroyed");
        uiContent_->NotifySurfaceDestroyed();
    }
}

bool Window::ProcessPointerEvent(const std::vector<uint8_t>& data)
{
    if (!uiContent_) {
        LOGW("Window::ProcessPointerEvent failed ,uicontent is nullptr");
        return false;
    }
    return uiContent_->ProcessPointerEvent(data);
}

bool Window::ProcessKeyEvent(int32_t keyCode, int32_t keyAction, int32_t repeatTime, int64_t timeStamp,
    int64_t timeStampStart)
{
    if (!uiContent_) {
        return false;
    }
    return uiContent_->ProcessKeyEvent(keyCode, keyAction, repeatTime, timeStamp, timeStampStart);
}

void Window::DelayNotifyUIContentIfNeeded()
{
    if (!uiContent_) {
        LOGE("Window Delay Notify uiContent_ is nullptr!");
        return;
    }

    if (delayNotifySurfaceCreated_) {
        LOGI("Window Delay Notify uiContent_ Surface Created");
        uiContent_->NotifySurfaceCreated();
        delayNotifySurfaceCreated_ = false;
    }

    if (delayNotifySurfaceChanged_) {
        LOGI("Window Delay Notify uiContent_ Surface Changed wh:[%{public}d, %{public}d]",
            surfaceWidth_, surfaceHeight_);
        Ace::ViewportConfig config;
        config.SetDensity(density_);
        config.SetSize(surfaceWidth_, surfaceHeight_);
        config.SetOrientation(surfaceWidth_ <= surfaceHeight_ ? 0 : 1);
        uiContent_->UpdateViewportConfig(config, WindowSizeChangeReason::RESIZE);
        delayNotifySurfaceChanged_ = false;
    }

    if (delayNotifySurfaceDestroyed_) {
        LOGI("Window Delay Notify uiContent_ Surface Destroyed");
        uiContent_->NotifySurfaceDestroyed();
        delayNotifySurfaceDestroyed_ = false;
    }
}

int Window::SetUIContent(const std::string& contentInfo,
    NativeEngine* engine, NativeValue* storage, bool isdistributed, AbilityRuntime::Platform::Ability* ability)
{
    LOGI("Window::SetUIContent : Start... / this=%p, windowView=%p",this, windowView_);
    using namespace OHOS::Ace::Platform;
    (void)ability;
    std::unique_ptr<UIContent> uiContent;
    uiContent = UIContent::Create(context_.get(), engine);
    if (uiContent == nullptr) {
        LOGE("Window::SetUIContent : Create UIContent Failed!");
        return -1;
    }
    uiContent->Initialize(this, contentInfo, storage);
    // make uiContent available after Initialize/Restore
    uiContent_ = std::move(uiContent);

    uiContent_->Foreground();
    isWindowShow_ = true;

    DelayNotifyUIContentIfNeeded();
    LOGI("Window::SetUIContent : End!!!");
    return 0;
}

void Window::SetWindowView(WindowView* windowView)
{
    if (windowView == nullptr) {
        LOGE("Window::SetWindowView: WindowView is nullptr!");
        return;
    }
    if (windowView_ != nullptr) {
        LOGW("Window::SetWindowView: windowView_ has already been set!");
        return;
    }
    LOGI("Window::SetWindowView");
    [windowView_ release];
     windowView_ = [windowView retain];
}

void Window::SetWindowName(const std::string& windowName)
{
    name_ = windowName;
}

void Window::SetWindowType(WindowType windowType)
{
    windowType_ = windowType;
}

void Window::SetParentId(uint32_t parentId)
{
    parentId_ = parentId;
}

void Window::WindowFocusChanged(bool hasWindowFocus)
{
    if (!uiContent_) {
        LOGW("Window::Focus uiContent_ is nullptr");
        return;
    }
    if (hasWindowFocus) {
        LOGI("Window: notify uiContent Focus");
        uiContent_->Focus();
        NotifyAfterActive();
    } else {
        LOGI("Window: notify uiContent UnFocus");
        uiContent_->UnFocus();
        NotifyAfterInactive();
    }
}

void Window::Foreground()
{
    if (!uiContent_) {
        LOGW("Window::Foreground uiContent_ is nullptr");
        return;
    }
    LOGI("Window: notify uiContent Foreground");
    uiContent_->Foreground();
    NotifyAfterForeground();
    isWindowShow_ = true;
}

void Window::Background()
{
    if (!uiContent_) {
        LOGW("Window::Background uiContent_ is nullptr");
        return;
    }
    LOGI("Window: notify uiContent Background");
    isWindowShow_ = false;
    uiContent_->Background();
    NotifyAfterBackground();
}

void Window::ReleaseWindowView()
{
    if (windowView_ == nullptr) {
        return;
    }
    [windowView_ release];
}

void Window::UpdateConfiguration(const std::shared_ptr<OHOS::AbilityRuntime::Platform::Configuration>& config)
{
    if (uiContent_ != nullptr) {
        LOGI("Window::UpdateConfiguration called.");
        uiContent_->UpdateConfiguration(config);
    }
}

WMError Window::SetBackgroundColor(uint32_t color)
{
    LOGI("Window::SetBackgroundColor : color=%{public}u, uiContent_=%{public}p", color, uiContent_.get());
    backgroundColor_ = color;
    if (uiContent_) {
        uiContent_->SetBackgroundColor(color);
    }
    return WMError::WM_OK;
}

WMError Window::SetBrightness(float brightness)
{
    [[UIScreen mainScreen] setBrightness:brightness];
    return WMError::WM_OK;
}

float Window::GetBrightness() const
{
    return [UIScreen mainScreen].brightness;
}

WMError Window::SetKeepScreenOn(bool keepScreenOn)
{
    if (keepScreenOn) {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = NO;
    }
    return WMError::WM_OK;
}

bool Window::IsKeepScreenOn()
{
    if ([UIApplication sharedApplication].idleTimerDisabled == YES) {
        return true;
    } else {
        return false;
    }
}

WMError Window::SetSystemBarProperty(WindowType type, const SystemBarProperty& property)
{
    HILOG_INFO("Window::SetSystemBarProperty : Start... / type=%{public}d, enable=%{public}d",
        static_cast<int>(type), property.enable_);
    StageViewController *controller = [StageApplication getApplicationTopViewController];   
    if (type ==  WindowType::WINDOW_TYPE_NAVIGATION_BAR) {
        HILOG_INFO("Window::SetSystemBarProperty : Set Navigation Bar");
        if (!property.enable_) {
            HILOG_INFO("Window::SetSystemBarProperty : Set Navigation Bar - hidden");
            [controller.navigationController setNavigationBarHidden:YES animated:YES];
        } else {
            HILOG_INFO("Window::SetSystemBarProperty : Set Navigation Bar - show");
            [controller.navigationController setNavigationBarHidden:NO animated:YES];
            [controller setNeedsStatusBarAppearanceUpdate];
        }
    } else if (type == WindowType::WINDOW_TYPE_STATUS_BAR) {
        HILOG_INFO("Window::SetSystemBarProperty : Set Status Bar");
        if (!property.enable_) {
            HILOG_INFO("Window::SetSystemBarProperty : Set Status Bar - hidden");
            controller.statusBarHidden = YES;
            [controller setNeedsStatusBarAppearanceUpdate];
        } else {
            HILOG_INFO("Window::SetSystemBarProperty : Set Status Bar - show");
            controller.statusBarHidden = NO;
            [controller setNeedsStatusBarAppearanceUpdate];
        }
    } 
    sysBarPropMap_[type] = property;
    return WMError::WM_OK;
}

void Window::SetRequestedOrientation(Orientation orientation)
{
    if (orientation == Orientation::UNSPECIFIED) {
        return;
    } else if (orientation == Orientation::VERTICAL) {
        windowView_.OrientationMask = UIInterfaceOrientationMaskPortrait;
        windowView_.orientation = UIInterfaceOrientationPortrait;
    } else if (orientation == Orientation::HORIZONTAL) {
        windowView_.OrientationMask = UIInterfaceOrientationMaskLandscapeLeft;
        windowView_.orientation = UIInterfaceOrientationLandscapeLeft;
    } else if (orientation == Orientation::REVERSE_HORIZONTAL) {
        windowView_.OrientationMask = UIInterfaceOrientationMaskLandscapeRight;
        windowView_.orientation = UIInterfaceOrientationLandscapeRight;
    } else if (orientation == Orientation::REVERSE_VERTICAL) {
        windowView_.OrientationMask = UIInterfaceOrientationMaskPortraitUpsideDown;
        windowView_.orientation = UIInterfaceOrientationPortraitUpsideDown;
    }

    if (@available(iOS 16, *)) {
#if defined __IPHONE_16_0
        [windowView_.getViewController setNeedsUpdateOfSupportedInterfaceOrientations];
        NSArray *array = [[[UIApplication sharedApplication] connectedScenes] allObjects];
        UIWindowScene *scene = [array firstObject];
        UIInterfaceOrientationMask OrientationMask = windowView_.OrientationMask;
        UIWindowSceneGeometryPreferencesIOS *geometryPreferencesIOS = 
            [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:OrientationMask];
        /* start transform animation */
        [scene requestGeometryUpdateWithPreferences:geometryPreferencesIOS 
            errorHandler:^(NSError * _Nonnull error) {}];
#endif
    } else {
        [windowView_ setNewOrientation:windowView_.orientation];
    }
}

SystemBarProperty Window::GetSystemBarPropertyByType(WindowType type) const
{
    for (auto& it : sysBarPropMap_) {
        if (it.first == type) {
            return it.second;
        }
    }
}

void Window::ClearListenersById(uint32_t winId)
{
    std::lock_guard<std::recursive_mutex> lock(globalMutex_);
    ClearUselessListeners(lifecycleListeners_, winId); 
}

WMError Window::RegisterLifeCycleListener(const sptr<IWindowLifeCycle>& listener)
{
    LOGD("Start register");
    std::lock_guard<std::recursive_mutex> lock(globalMutex_);
    return RegisterListener(lifecycleListeners_[GetWindowId()], listener);
}

WMError Window::UnregisterLifeCycleListener(const sptr<IWindowLifeCycle>& listener)
{
    LOGD("Start unregister");
    std::lock_guard<std::recursive_mutex> lock(globalMutex_);
    return UnregisterListener(lifecycleListeners_[GetWindowId()], listener);
}

template<typename T>
WMError Window::RegisterListener(std::vector<sptr<T>>& holder, const sptr<T>& listener)
{
    if (listener == nullptr) {
        LOGE("listener is nullptr");
        return WMError::WM_ERROR_NULLPTR;
    }
    if (std::find(holder.begin(), holder.end(), listener) != holder.end()) {
        LOGE("Listener already registered");
        return WMError::WM_OK;
    }
    holder.emplace_back(listener);
    return WMError::WM_OK;
}

template<typename T>
WMError Window::UnregisterListener(std::vector<sptr<T>>& holder, const sptr<T>& listener)
{
    if (listener == nullptr) {
        LOGE("listener could not be null");
        return WMError::WM_ERROR_NULLPTR;
    }
    holder.erase(std::remove_if(holder.begin(), holder.end(),
        [listener](sptr<T> registeredListener) {
            return registeredListener == listener;
        }), holder.end());
    return WMError::WM_OK;
}
} // namespace OHOS::Rosen
