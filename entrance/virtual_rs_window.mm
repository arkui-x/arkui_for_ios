/*
 * Copyright (c) 2023-2025 Huawei Device Co., Ltd.
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
#include "foundation/appframework/arkui/uicontent/ui_content.h"
#include "transaction/rs_interfaces.h"
#include "virtual_rs_window.h"
#include "StageViewController.h"
#include "StageApplication.h"
#include "window_view_adapter.h"
#include "window_interface.h"
#include "window_option.h"
#include "InstanceIdGenerator.h"
#include "hilog.h"
#include "napi/native_api.h"
#include "core/event/touch_event.h"
#include "core/event/key_event.h"
#include "core/pipeline/pipeline_base.h"
#include "interaction/interaction_impl.h"
#include "mmi_event_convertor.h"
#include "AccessibilityWindowView.h"

namespace OHOS::Rosen {
#define BOTTOM_SAFE_AREA_HEIGHT_VP 28.0
const std::string DRAG_WINDOW_NAME = "dragWindow";
Ace::KeyCode KeyCodeToAceKeyCode(int32_t keyCode)
{
    Ace::KeyCode aceKeyCode = Ace::KeyCode::KEY_UNKNOWN;
    const static std::map<int32_t, Ace::KeyCode> TO_OHOS_KEYCODE_MAP = {
        { 4      /* UIKeyboardHIDUsageKeyboardA */,                      Ace::KeyCode::KEY_A               },
        { 5      /* UIKeyboardHIDUsageKeyboardB */,                      Ace::KeyCode::KEY_B               },
        { 6      /* UIKeyboardHIDUsageKeyboardC */,                      Ace::KeyCode::KEY_C               },
        { 7      /* UIKeyboardHIDUsageKeyboardD */,                      Ace::KeyCode::KEY_D               },
        { 8      /* UIKeyboardHIDUsageKeyboardE */,                      Ace::KeyCode::KEY_E               },
        { 9      /* UIKeyboardHIDUsageKeyboardF */,                      Ace::KeyCode::KEY_F               },
        { 10     /* UIKeyboardHIDUsageKeyboardG */,                      Ace::KeyCode::KEY_G               },
        { 11     /* UIKeyboardHIDUsageKeyboardH */,                      Ace::KeyCode::KEY_H               },
        { 12     /* UIKeyboardHIDUsageKeyboardI */,                      Ace::KeyCode::KEY_I               },
        { 13     /* UIKeyboardHIDUsageKeyboardJ */,                      Ace::KeyCode::KEY_J               },
        { 14     /* UIKeyboardHIDUsageKeyboardK */,                      Ace::KeyCode::KEY_K               },
        { 15     /* UIKeyboardHIDUsageKeyboardL */,                      Ace::KeyCode::KEY_L               },
        { 16     /* UIKeyboardHIDUsageKeyboardM */,                      Ace::KeyCode::KEY_M               },
        { 17     /* UIKeyboardHIDUsageKeyboardN */,                      Ace::KeyCode::KEY_N               },
        { 18     /* UIKeyboardHIDUsageKeyboardO */,                      Ace::KeyCode::KEY_O               },
        { 19     /* UIKeyboardHIDUsageKeyboardP */,                      Ace::KeyCode::KEY_P               },
        { 20     /* UIKeyboardHIDUsageKeyboardQ */,                      Ace::KeyCode::KEY_Q               },
        { 21     /* UIKeyboardHIDUsageKeyboardR */,                      Ace::KeyCode::KEY_R               },
        { 22     /* UIKeyboardHIDUsageKeyboardS */,                      Ace::KeyCode::KEY_S               },
        { 23     /* UIKeyboardHIDUsageKeyboardT */,                      Ace::KeyCode::KEY_T               },
        { 24     /* UIKeyboardHIDUsageKeyboardU */,                      Ace::KeyCode::KEY_U               },
        { 25     /* UIKeyboardHIDUsageKeyboardV */,                      Ace::KeyCode::KEY_V               },
        { 26     /* UIKeyboardHIDUsageKeyboardW */,                      Ace::KeyCode::KEY_W               },
        { 27     /* UIKeyboardHIDUsageKeyboardX */,                      Ace::KeyCode::KEY_X               },
        { 28     /* UIKeyboardHIDUsageKeyboardY */,                      Ace::KeyCode::KEY_Y               },
        { 29     /* UIKeyboardHIDUsageKeyboardZ */,                      Ace::KeyCode::KEY_Z               },
        { 30     /* UIKeyboardHIDUsageKeyboard1 */,                      Ace::KeyCode::KEY_1               },
        { 31     /* UIKeyboardHIDUsageKeyboard2 */,                      Ace::KeyCode::KEY_2               },
        { 32     /* UIKeyboardHIDUsageKeyboard3 */,                      Ace::KeyCode::KEY_3               },
        { 33     /* UIKeyboardHIDUsageKeyboard4 */,                      Ace::KeyCode::KEY_4               },
        { 34     /* UIKeyboardHIDUsageKeyboard5 */,                      Ace::KeyCode::KEY_5               },
        { 35     /* UIKeyboardHIDUsageKeyboard6 */,                      Ace::KeyCode::KEY_6               },
        { 36     /* UIKeyboardHIDUsageKeyboard7 */,                      Ace::KeyCode::KEY_7               },
        { 37     /* UIKeyboardHIDUsageKeyboard8 */,                      Ace::KeyCode::KEY_8               },
        { 38     /* UIKeyboardHIDUsageKeyboard9 */,                      Ace::KeyCode::KEY_9               },
        { 39     /* UIKeyboardHIDUsageKeyboard0 */,                      Ace::KeyCode::KEY_0               },
        { 40     /* UIKeyboardHIDUsageKeyboardReturnOrEnter */,          Ace::KeyCode::KEY_ENTER           },
        { 41     /* UIKeyboardHIDUsageKeyboardEscape */,                 Ace::KeyCode::KEY_ESCAPE          },
        { 42     /* UIKeyboardHIDUsageKeyboardDeleteOrBackspace */,      Ace::KeyCode::KEY_DEL             },
        { 43     /* UIKeyboardHIDUsageKeyboardTab */,                    Ace::KeyCode::KEY_TAB             },
        { 44     /* UIKeyboardHIDUsageKeyboardSpacebar */,               Ace::KeyCode::KEY_SPACE           },
        { 45     /* UIKeyboardHIDUsageKeyboardHyphen */,                 Ace::KeyCode::KEY_MINUS           },
        { 46     /* UIKeyboardHIDUsageKeyboardEqualSign */,              Ace::KeyCode::KEY_EQUALS          },
        { 47     /* UIKeyboardHIDUsageKeyboardOpenBracket */,            Ace::KeyCode::KEY_LEFT_BRACKET    },
        { 48     /* UIKeyboardHIDUsageKeyboardCloseBracket */,           Ace::KeyCode::KEY_RIGHT_BRACKET   },
        { 49     /* UIKeyboardHIDUsageKeyboardBackslash */,              Ace::KeyCode::KEY_BACKSLASH       },
        { 51     /* UIKeyboardHIDUsageKeyboardSemicolon */,              Ace::KeyCode::KEY_SEMICOLON       },
        { 52     /* UIKeyboardHIDUsageKeyboardQuote */,                  Ace::KeyCode::KEY_APOSTROPHE      },
        { 53     /* UIKeyboardHIDUsageKeyboardGraveAccentAndTilde */,    Ace::KeyCode::KEY_GRAVE           },
        { 54     /* UIKeyboardHIDUsageKeyboardComma */,                  Ace::KeyCode::KEY_COMMA           },
        { 55     /* UIKeyboardHIDUsageKeyboardPeriod */,                 Ace::KeyCode::KEY_PERIOD          },
        { 56     /* UIKeyboardHIDUsageKeyboardSlash */,                  Ace::KeyCode::KEY_SLASH           },
        { 57     /* UIKeyboardHIDUsageKeyboardCapsLock */,               Ace::KeyCode::KEY_CAPS_LOCK       },
        { 58     /* UIKeyboardHIDUsageKeyboardF1 */,                     Ace::KeyCode::KEY_F1              },
        { 59     /* UIKeyboardHIDUsageKeyboardF2 */,                     Ace::KeyCode::KEY_F2              },
        { 60     /* UIKeyboardHIDUsageKeyboardF3 */,                     Ace::KeyCode::KEY_F3              },
        { 61     /* UIKeyboardHIDUsageKeyboardF4 */,                     Ace::KeyCode::KEY_F4              },
        { 62     /* UIKeyboardHIDUsageKeyboardF5 */,                     Ace::KeyCode::KEY_F5              },
        { 63     /* UIKeyboardHIDUsageKeyboardF6 */,                     Ace::KeyCode::KEY_F6              },
        { 64     /* UIKeyboardHIDUsageKeyboardF7 */,                     Ace::KeyCode::KEY_F7              },
        { 65     /* UIKeyboardHIDUsageKeyboardF8 */,                     Ace::KeyCode::KEY_F8              },
        { 66     /* UIKeyboardHIDUsageKeyboardF9 */,                     Ace::KeyCode::KEY_F9              },
        { 67     /* UIKeyboardHIDUsageKeyboardF10 */,                    Ace::KeyCode::KEY_F10             },
        { 68     /* UIKeyboardHIDUsageKeyboardF11 */,                    Ace::KeyCode::KEY_F11             },
        { 69     /* UIKeyboardHIDUsageKeyboardF12 */,                    Ace::KeyCode::KEY_F12             },
        { 70     /* UIKeyboardHIDUsageKeyboardPrintScreen */,            Ace::KeyCode::KEY_SYSRQ           },
        { 71     /* UIKeyboardHIDUsageKeyboardScrollLock */,             Ace::KeyCode::KEY_SCROLL_LOCK     },
        { 72     /* UIKeyboardHIDUsageKeyboardPause */,                  Ace::KeyCode::KEY_BREAK           },
        { 73     /* UIKeyboardHIDUsageKeyboardInsert */,                 Ace::KeyCode::KEY_INSERT          },
        { 74     /* UIKeyboardHIDUsageKeyboardHome */,                   Ace::KeyCode::KEY_MOVE_HOME       },
        { 75     /* UIKeyboardHIDUsageKeyboardPageUp */,                 Ace::KeyCode::KEY_PAGE_UP         },
        { 76     /* UIKeyboardHIDUsageKeyboardDeleteForward */,          Ace::KeyCode::KEY_FORWARD_DEL     },
        { 77     /* UIKeyboardHIDUsageKeyboardEnd */,                    Ace::KeyCode::KEY_MOVE_END        },
        { 78     /* UIKeyboardHIDUsageKeyboardPageDown */,               Ace::KeyCode::KEY_PAGE_DOWN       },
        { 79     /* UIKeyboardHIDUsageKeyboardRightArrow */,             Ace::KeyCode::KEY_DPAD_RIGHT      },
        { 80     /* UIKeyboardHIDUsageKeyboardLeftArrow */,              Ace::KeyCode::KEY_DPAD_LEFT       },
        { 81     /* UIKeyboardHIDUsageKeyboardDownArrow */,              Ace::KeyCode::KEY_DPAD_DOWN       },
        { 82     /* UIKeyboardHIDUsageKeyboardUpArrow */,                Ace::KeyCode::KEY_DPAD_UP         },
        { 83     /* UIKeyboardHIDUsageKeypadNumLock */,                  Ace::KeyCode::KEY_NUM_LOCK        },
        { 84     /* UIKeyboardHIDUsageKeypadSlash */,                    Ace::KeyCode::KEY_NUMPAD_DIVIDE   },
        { 85     /* UIKeyboardHIDUsageKeypadAsterisk */,                 Ace::KeyCode::KEY_NUMPAD_MULTIPLY },
        { 86     /* UIKeyboardHIDUsageKeypadHyphen */,                   Ace::KeyCode::KEY_NUMPAD_SUBTRACT },
        { 87     /* UIKeyboardHIDUsageKeypadPlus */,                     Ace::KeyCode::KEY_NUMPAD_ADD      },
        { 88     /* UIKeyboardHIDUsageKeypadEnter */,                    Ace::KeyCode::KEY_NUMPAD_ENTER    },
        { 89     /* UIKeyboardHIDUsageKeypad1 */,                        Ace::KeyCode::KEY_NUMPAD_1        },
        { 90     /* UIKeyboardHIDUsageKeypad2 */,                        Ace::KeyCode::KEY_NUMPAD_2        },
        { 91     /* UIKeyboardHIDUsageKeypad3 */,                        Ace::KeyCode::KEY_NUMPAD_3        },
        { 92     /* UIKeyboardHIDUsageKeypad4 */,                        Ace::KeyCode::KEY_NUMPAD_4        },
        { 93     /* UIKeyboardHIDUsageKeypad5 */,                        Ace::KeyCode::KEY_NUMPAD_5        },
        { 94     /* UIKeyboardHIDUsageKeypad6 */,                        Ace::KeyCode::KEY_NUMPAD_6        },
        { 95     /* UIKeyboardHIDUsageKeypad7 */,                        Ace::KeyCode::KEY_NUMPAD_7        },
        { 96     /* UIKeyboardHIDUsageKeypad8 */,                        Ace::KeyCode::KEY_NUMPAD_8        },
        { 97     /* UIKeyboardHIDUsageKeypad9 */,                        Ace::KeyCode::KEY_NUMPAD_9        },
        { 98     /* UIKeyboardHIDUsageKeypad0 */,                        Ace::KeyCode::KEY_NUMPAD_0        },
        { 99     /* UIKeyboardHIDUsageKeypadPeriod */,                   Ace::KeyCode::KEY_NUMPAD_DOT      },
        { 101    /* UIKeyboardHIDUsageKeyboardApplication */,            (Ace::KeyCode)2466                },
        { 224    /* UIKeyboardHIDUsageKeyboardLeftControl */,            Ace::KeyCode::KEY_CTRL_LEFT       },
        { 225    /* UIKeyboardHIDUsageKeyboardLeftShift */,              Ace::KeyCode::KEY_SHIFT_LEFT      },
        { 226    /* UIKeyboardHIDUsageKeyboardLeftAlt */,                Ace::KeyCode::KEY_ALT_LEFT        },
        { 227    /* UIKeyboardHIDUsageKeyboardLeftGUI */,                Ace::KeyCode::KEY_META_LEFT       },
        { 228    /* UIKeyboardHIDUsageKeyboardRightControl */,           Ace::KeyCode::KEY_CTRL_RIGHT      },
        { 229    /* UIKeyboardHIDUsageKeyboardRightShift */,             Ace::KeyCode::KEY_SHIFT_RIGHT     },
        { 230    /* UIKeyboardHIDUsageKeyboardRightAlt */,               Ace::KeyCode::KEY_ALT_RIGHT       },
        { 231    /* UIKeyboardHIDUsageKeyboardRightGUI */,               Ace::KeyCode::KEY_META_RIGHT      },
    };
    
    auto checkIter = TO_OHOS_KEYCODE_MAP.find(keyCode);
    if (checkIter != TO_OHOS_KEYCODE_MAP.end()) {
        aceKeyCode = checkIter->second;
    }
    return aceKeyCode;
}

const std::map<ColorSpace, GraphicColorGamut> COLOR_SPACE_JS_TO_GAMUT_MAP {
    { ColorSpace::COLOR_SPACE_DEFAULT, GraphicColorGamut::GRAPHIC_COLOR_GAMUT_SRGB },
    { ColorSpace::COLOR_SPACE_WIDE_GAMUT, GraphicColorGamut::GRAPHIC_COLOR_GAMUT_DCI_P3 },
};

const char* const kOrientationMaskUpdateNotificationName = "arkui_x.iosPlatform.setPreferredOrientationNotificationName";
const char* const kOrientationMaskUpdateNotificationKey = "arkui_x.iosPlatform.setPreferredOrientationNotificationKey";

void DummyWindowRelease(Window* window)
{
    window->DecStrongRef(window);
    LOGI("Rosenwindow rsWindow_Window: dummy release");
}
std::map<uint32_t, std::vector<std::shared_ptr<Window>>> Window::subWindowMap_;
std::map<std::string, std::pair<uint32_t, std::shared_ptr<Window>>> Window::windowMap_;
std::map<uint32_t, std::vector<sptr<IWindowLifeCycle>>> Window::lifecycleListeners_;
std::map<uint32_t, std::vector<sptr<IWindowChangeListener>>> Window::windowChangeListeners_;
std::map<uint32_t, std::vector<sptr<ITouchOutsideListener>>> Window::touchOutsideListeners_;
std::map<uint32_t, std::vector<sptr<IWindowSurfaceNodeListener>>> Window::surfaceNodeListeners_;
std::map<uint32_t, std::vector<sptr<IWindowStatusChangeListener>>> Window::windowStatusChangeListeners_;
std::map<uint32_t, std::vector<sptr<IAvoidAreaChangedListener>>> Window::avoidAreaChangeListeners_;

std::recursive_mutex Window::globalMutex_;
std::map<uint32_t, std::vector<sptr<IOccupiedAreaChangeListener>>> Window::occupiedAreaChangeListeners_;
std::map<uint32_t, std::vector<sptr<IAvoidAreaChangedListener>>> Window::avoidAreaChangedListeners_;
constexpr Rect emptyRect = {0, 0, 0, 0};

static Rect MakeAvoidRect(float left, float top , float width, float height) {
    if (width <= 0 || height <= 0) {
        width = 0;
        height = 0;
        left = 0;
        top = 0;
    }
    return (Rect){left, top, width, height};
}

static uint32_t ColorConvertFromUIColor(UIColor* uiColor)
{
    if (uiColor == nullptr) {
        return 0;
    }
    CGFloat red = 0;
    CGFloat green = 0;
    CGFloat blue = 0;
    CGFloat alpha = 0;
    [uiColor getRed:&red green:&green blue:&blue alpha:&alpha];
    uint32_t result = ((uint8_t)(red * UINT8_MAX)<<24) |
        ((uint8_t)(green * UINT8_MAX)<<16) |
        ((uint8_t)(blue * UINT8_MAX)<<8) |
        ((uint8_t)(alpha * UINT8_MAX));
    return result;
}

static UIColor* ColorConvertToUIColor(uint32_t color)
{
    return [UIColor colorWithRed:(((color>>24)&UINT8_MAX)*1.0/UINT8_MAX)
        green:(((color>>16)&UINT8_MAX)*1.0/UINT8_MAX)
        blue:(((color>>8)&UINT8_MAX)*1.0/UINT8_MAX)
        alpha:((color&UINT8_MAX)*1.0/UINT8_MAX)];
}

static WMError SetSystemBar(WindowType type, const SystemBarProperty& property)
{
    StageViewController *controller = [StageApplication getApplicationTopViewController];
    if (![controller isKindOfClass:[StageViewController class]]) {
        return WMError::WM_ERROR_INVALID_WINDOW;
    }
    if (type ==  WindowType::WINDOW_TYPE_NAVIGATION_BAR) {
        if (!property.enable_) {
            [controller.navigationController setNavigationBarHidden:YES animated:NO];
        } else {
            [controller.navigationController setNavigationBarHidden:NO animated:NO];
            [controller setNeedsStatusBarAppearanceUpdate];
        }
    } else if (type == WindowType::WINDOW_TYPE_STATUS_BAR) {
        if (!property.enable_) {
            controller.statusBarHidden = YES;
        } else {
            controller.statusBarHidden = NO;
        }
        [[UIApplication sharedApplication]setStatusBarHidden:!property.enable_ animated:property.enableAnimation_];
        if (property.enableAnimation_) {
            [UIView animateWithDuration:0.25 animations:^{
                [controller setNeedsStatusBarAppearanceUpdate];
            }];
        } else {
            [controller setNeedsStatusBarAppearanceUpdate];
        }
    }
    [controller.view setNeedsLayout];
    [controller.view layoutIfNeeded];
    return WMError::WM_OK;
}

static WMError SetSpecificBar(WindowType type, const SystemBarProperty& property) {
    StageViewController* controller = [StageApplication getApplicationTopViewController];
    WMError ret = WMError::WM_OK;
    if (![controller isKindOfClass:[StageViewController class]]) {
        return WMError::WM_ERROR_INVALID_WINDOW;
    }
    if (type == WindowType::WINDOW_TYPE_STATUS_BAR || type == WindowType::WINDOW_TYPE_NAVIGATION_BAR) {
        ret = SetSystemBar(type, property);
    } else if (type == WindowType::WINDOW_TYPE_NAVIGATION_INDICATOR) {
        if (@available(iOS 11.0, *)) {
            if (!property.enable_) {
                LOGI("Set homeIndicatorAutoHidden - hidden");
                controller.homeIndicatorHidden = YES;
                [controller setNeedsUpdateOfHomeIndicatorAutoHidden];
            } else {
                LOGI("Set homeIndicatorAutoHidden - show");
                controller.homeIndicatorHidden = NO;
                [controller setNeedsUpdateOfHomeIndicatorAutoHidden];
            }
            [controller.view setNeedsLayout];
            [controller.view layoutIfNeeded];
        } else {
            LOGE("Set SetSpecificBarProperty failed, iOS version less than 11");
            return WMError::WM_ERROR_INVALID_PARAM;
        }
    } else {
        LOGE("Set SetSpecificBarProperty failed, invalid parm");
        return WMError::WM_ERROR_INVALID_PARAM;
    }
    // WINDOW_TYPE_NAVIGATION_INDICATOR
    return WMError::WM_OK;
}

Window::Window(std::shared_ptr<AbilityRuntime::Platform::Context> context, uint32_t windowId)
    : context_(context), windowId_(windowId)
{
}

Window::~Window()
{
    LOGI("Window: release id = %u", windowId_);
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
    
    uint32_t windowId = [InstanceIdGenerator getAndIncrement];
    auto window = std::shared_ptr<Window>(new Window(context, windowId), DummyWindowRelease);
    window->SetWindowView((WindowView*)windowView);
    window->SetWindowName(windowName);
    window->IncStrongRef(window.get());
    window->SetMode(Rosen::WindowMode::WINDOW_MODE_FULLSCREEN);
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

    uint32_t windowId = [InstanceIdGenerator getAndIncrement];
    if (option->GetWindowType() != OHOS::Rosen::WindowType::WINDOW_TYPE_APP_SUB_WINDOW) {
        LOGI("Window::CreateSubWindow failed, window type error![windowType=%{public}d]", static_cast<int32_t>(option->GetWindowType()));
        return nullptr;
    }

    auto window = std::shared_ptr<Window>(new Window(context, windowId), DummyWindowRelease);
    AccessibilityWindowView* windowView = [[AccessibilityWindowView alloc]init];
    LOGI("Window::Createsubwindow with %{public}p", windowView);
    window->SetWindowView(windowView);
    [windowView setWindowDelegate:window]; 
    [windowView createSurfaceNode];
    window->IncStrongRef(window.get());
    window->SetWindowName(option->GetWindowName());
    window->SetWindowType(option->GetWindowType());
    window->SetMode(Rosen::WindowMode::WINDOW_MODE_FLOATING);
    LOGI("Window::Createsubwindow with name:%s, parentId=%{public}u", window->GetWindowName().c_str(), option->GetParentId());
    window->SetParentId(option->GetParentId());
    AddToSubWindowMap(window);
    AddToWindowMap(window);
    ShowSubWindowMap("Window::CreateSubWindow", window->GetParentId());
    
    return window;
}

std::shared_ptr<Window> Window::CreateDragWindow(
    std::shared_ptr<OHOS::AbilityRuntime::Platform::Context> context)
{
    auto mainWindow = Window::GetTopWindow(context);
    if (!mainWindow) {
        LOGI("Window::CreateDragWindow failed,can not find mainWindow");
        return nullptr;
    }
    std::shared_ptr<WindowOption> option = std::make_shared<WindowOption>();
    if (!option) {
        LOGI("Window::CreateDragWindow failed,option ==nullptr");
        return nullptr;
    }
    option->SetParentId(mainWindow->GetWindowId());
    option->SetWindowType(Rosen::WindowType::WINDOW_TYPE_APP_SUB_WINDOW);
    option->SetWindowMode(Rosen::WindowMode::WINDOW_MODE_FLOATING);
    std::string windowName = mainWindow->GetWindowName() + DRAG_WINDOW_NAME;
    option->SetWindowName(windowName);
    std::shared_ptr<Window> window = Window::CreateSubWindow(context, option);
    if (window == nullptr) {
        HILOG_ERROR("drag window is null");
        return nullptr;
    }
    window->SetTouchable(false);
    window->SetFocusable(false);
    window->SetFullScreen(true);
    window->SetOnTop(true);
    return window;
}

void Window::AddToWindowMap(std::shared_ptr<Window> window)
{
    DeleteFromWindowMap(window);
    windowMap_.insert(std::make_pair(window->GetWindowName(), 
        std::pair<uint32_t, std::shared_ptr<Window>>(window->GetWindowId(), window)));
}

bool Window::CheckWindowNameExist(const std::string& windowName)
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

void Window::ShowSubWindowMap(const std::string& str, uint32_t parentId)
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
    HILOG_INFO("Window::Destroy");
    if (uiContent_ != nullptr) {
        uiContent_->Destroy();
        uiContent_ = nullptr;
    }
    NotifyBeforeDestroy(GetWindowName());

    if (windowView_ != nullptr) {
        [windowView_ hide];
        [windowView_ release];
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
            auto windowPtr = (*iter);
            subWindows.erase(iter);
            DeleteFromWindowMap(windowPtr);
            windowPtr->Destroy();
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

void Window::RegisterWindowDestroyedListener(const NotifyNativeWinDestroyFunc& func)
{
    LOGD("Start register");
    notifyNativefunc_ = std::move(func);
}

void Window::RegisterWillTerminateListener(const NotifyWillTerminateFunc& func)
{
    notifyWillTerminatefunc_ = std::move(func);
}

void Window::NotifyApplicationForeground(bool applicationForeground)
{
    NSLog(@"NotifyApplicationForeground: %d", applicationForeground);
    applicationForeground_ = applicationForeground;
}

std::vector<std::shared_ptr<Window>> Window::GetSubWindow(uint32_t parentId)
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

std::shared_ptr<Window> Window::FindWindow(const int windowId)
{
    for (auto iter = windowMap_.begin(); iter != windowMap_.end(); iter++) {
        if (iter->second.first == windowId) {
            return iter->second.second;
        }
    }
    return nullptr;
}

std::shared_ptr<Window> Window::GetTopWindow(const std::shared_ptr<OHOS::AbilityRuntime::Platform::Context>& context)
{
    StageViewController *controller = [StageApplication getApplicationTopViewController];
    if (![controller isKindOfClass:[StageViewController class]]) {
        return nullptr;
    }
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
    if (![controller isKindOfClass:[StageViewController class]]) {
        return WMError::WM_ERROR_INVALID_PARENT;
    }
    UIView *mainWindowView = [controller getWindowView];

    if ([windowView_ showOnView:mainWindowView.superview]) {
        DelayNotifyUIContentIfNeeded();
        NotifyAfterForeground();
        isWindowShow_ = true;
        UpdateWindowStatus();
        return WMError::WM_OK;
    }
    return WMError::WM_ERROR_INVALID_PARENT;
}

WMError Window::Hide()
{
    if (!windowView_) {
        LOGE("Window: showWindow failed");
        return WMError::WM_ERROR_INVALID_PARENT;
    }

    if ([windowView_ hide]) {
        isWindowShow_ = false;
        NotifyAfterBackground();
        UpdateWindowStatus();
        return WMError::WM_OK;
    }

    return WMError::WM_ERROR_INVALID_PARENT;
}

WMError Window::MoveWindowTo(int32_t x, int32_t y)
{   
    if (!windowView_) {
        LOGE("Window: MoveWindowTo failed");
        return WMError::WM_ERROR_INVALID_PARENT;   
    }
    if (isFullScreen_) {
        return WMError::WM_ERROR_INVALID_PARENT;
    }
    UIScreen *screen = [UIScreen mainScreen];
    CGFloat scale = screen.scale;
    if (scale == 0) {
        scale = 2;
    }
    x = x < 0 ? 0 : x / scale;
    y = y < 0 ? 0 : y / scale;
    windowView_.frame = CGRectMake(x, y, windowView_.frame.size.width, windowView_.frame.size.height);
    rect_.posX_ = x;
    rect_.posY_ = y;
    return WMError::WM_OK;
}

bool Window::ProcessBackPressed()
{
    if (!uiContent_) {
        LOGW("Window::ProcessBackPressed uiContent_ is nullptr");
        return false;
    }
    return uiContent_->ProcessBackPressed();
}

bool Window::ProcessBasicEvent(const std::vector<Ace::TouchEvent>& touchEvents)
{
    if (!uiContent_) {
        LOGW("Window::ProcessBasicEvent uiContent_ is nullptr");
        return false;
    }
    return uiContent_->ProcessBasicEvent(touchEvents);
}

WMError Window::SetFullScreen(bool status)
{
    if (!windowView_) {
        LOGE("Window: SetFullScreen failed");
        return WMError::WM_ERROR_INVALID_WINDOW;
    }
    windowView_.fullScreen = status;
    isFullScreen_ = status;
    return WMError::WM_OK;
}

WMError Window::SetOnTop(bool status)
{
    if (!windowView_) {
        LOGE("Window: SetFullScreen failed");
        return WMError::WM_ERROR_INVALID_WINDOW;
    }
    if (status) {
        windowView_.zOrder = NSIntegerMax;
    } else {
       windowView_.zOrder = 0;
    }
    return WMError::WM_OK;
}
WMError Window::SetFocusable(bool focusable)
{
    if (!windowView_) {
        LOGE("Window: SetFocusable failed");
        return WMError::WM_ERROR_INVALID_WINDOW;
    }
    windowView_.focusable = focusable;
    focusable_ = focusable;
    return WMError::WM_OK;
}

bool Window::GetFocusable() const
{
    return focusable_;
}

WMError Window::SetTouchHotAreas(const std::vector<Rect>& rects)
{
    if (!windowView_) {
        return WMError::WM_ERROR_INVALID_WINDOW;
    }
    int size = rects.size();
    if (size == 0) {
        [windowView_ setTouchHotAreas:nullptr size:0];
        return WMError::WM_OK;
    }
    CGRect* cgRects = (CGRect *)malloc(sizeof(CGRect) * size);
    UIScreen *screen = [UIScreen mainScreen];
    CGFloat scale = screen.scale;
    if (scale < 1) {
        return WMError::WM_ERROR_INVALID_WINDOW;
    }
    for (int i = 0; i < size; i++) {
        cgRects[i] = CGRectMake(rects[i].posX_/scale , rects[i].posY_/scale,
            rects[i].width_/scale, rects[i].height_/scale);
    }
    [windowView_ setTouchHotAreas:cgRects size:size];
    free(cgRects);
    return WMError::WM_OK;
}

WMError Window::RequestFocus()
{
    if (!windowView_ || !focusable_ || !isWindowShow_) {
        return WMError::WM_ERROR_INVALID_WINDOW;
    }
    if ([windowView_ requestFocus]) {
        return WMError::WM_OK;
    } else {
        return WMError::WM_ERROR_INVALID_WINDOW;
    }
}
bool Window::IsFocused() const
{
    return isFocused_;
}
WMError Window::SetTouchable(bool isTouchable)
{
    if (!windowView_) {
        LOGE("Window: SetTouchable failed");
        return WMError::WM_ERROR_INVALID_WINDOW;
    }
    windowView_.userInteractionEnabled = isTouchable;
    isTouchable_ = isTouchable;
    return WMError::WM_OK;
}
bool Window::GetTouchable() const
{
    if(!windowView_) {
        LOGE("Window: GetTouchable failed");
        return true;
    }
    return isTouchable_;
}

WMError Window::ResizeWindowTo(int32_t width, int32_t height) {
    
    if (!windowView_) {
        LOGE("Window: ResizeWindowTo failed");
        return WMError::WM_ERROR_INVALID_PARENT;   
    }
    LOGI("Window: ResizeWindowTo %d %d", width, height);
    if (isFullScreen_) {
        return WMError::WM_ERROR_INVALID_PARENT;
    }
    UIScreen *screen = [UIScreen mainScreen];
    CGFloat scale = screen.scale;
    windowView_.frame = CGRectMake(windowView_.frame.origin.x, windowView_.frame.origin.y, width / scale, height / scale);

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
            vsyncCallback->onCallback(timestamp, 0);
        };
        OHOS::Rosen::VSyncReceiver::FrameCallback fcb = {
            .userData_ = this,
            .callback_ = callback,
        };
        receiver_->RequestNextVSync(fcb);
        return;
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
    } else {
        LOGI("Window Notify uiContent_ Surface Created");
        uiContent_->NotifySurfaceCreated();
    }
    delayNotifySurfaceCreated_ = true;
    auto surfaceNodeListeners = GetListeners<IWindowSurfaceNodeListener>();
    for (auto& listener : surfaceNodeListeners) {
        if (listener != nullptr) {
            listener->OnSurfaceNodeCreated();
        }
    }
}

WindowStatus Window::GetWindowStatusInner(WindowMode mode)
{
    LOGD("GetWindowStatusInner mode= %d",mode);
    auto windowStatus = WindowStatus::WINDOW_STATUS_UNDEFINED;
    if (mode == WindowMode::WINDOW_MODE_FLOATING) {
        windowStatus = WindowStatus::WINDOW_STATUS_FLOATING;
    } else if (mode == WindowMode::WINDOW_MODE_FULLSCREEN) {
        windowStatus = WindowStatus::WINDOW_STATUS_FULLSCREEN;
    } if (mode == WindowMode::WINDOW_MODE_SPLIT_PRIMARY || mode == WindowMode::WINDOW_MODE_SPLIT_SECONDARY) {
        windowStatus = WindowStatus::WINDOW_STATUS_SPLITSCREEN;
    }
    if (!isWindowShow_) {
        windowStatus = WindowStatus::WINDOW_STATUS_MINIMIZE;
    }
    return windowStatus;
}

void Window::NotifySurfaceChanged(int32_t width, int32_t height, float density)
{
    rect_.width_ = width;
    rect_.height_ = height;
    NotifySizeChange(rect_);
    if (!surfaceNode_) {
        LOGE("Window Notify Surface Changed, surfaceNode_ is nullptr!");
        return;
    }
    LOGI("Window Notify Surface Changed wh:[%{public}d, %{public}d]", width, height);
    surfaceWidth_ = width;
    surfaceHeight_ = height;
    surfaceNode_->SetBoundsWidth(surfaceWidth_);
    surfaceNode_->SetBoundsHeight(surfaceHeight_);
    density_ = density;

    if (!uiContent_) {
        LOGW("Window Notify uiContent_ Surface Created, uiContent_ is nullptr, delay notify.");
    } else {
        LOGI("Window Notify uiContent_ Surface Created");
        Ace::ViewportConfig config;
        config.SetDensity(density_);
        config.SetSize(surfaceWidth_, surfaceHeight_);
        config.SetOrientation(surfaceWidth_ <= surfaceHeight_ ? 0 : 1);
        uiContent_->UpdateViewportConfig(config, WindowSizeChangeReason::RESIZE);
    }

    delayNotifySurfaceChanged_ = true;
    auto surfaceNodeListeners = GetListeners<IWindowSurfaceNodeListener>();
    for (auto& listener : surfaceNodeListeners) {
        if (listener != nullptr) {
            listener->OnSurfaceNodeChanged(width, height, density);
        }
    }
}
void Window::NotifyTraitCollectionDidChange(bool isSplitScreen)
{
    if (windowMode_ == WindowMode::WINDOW_MODE_FULLSCREEN && isSplitScreen) {
        windowMode_ = WindowMode::WINDOW_MODE_SPLIT_PRIMARY;
    } else if (windowMode_ == WindowMode::WINDOW_MODE_SPLIT_PRIMARY && !isSplitScreen) {
        windowMode_ = WindowMode::WINDOW_MODE_FULLSCREEN;
    }
    UpdateWindowStatus();
}

void Window::UpdateWindowStatus()
{
    auto windowStatus = GetWindowStatusInner(windowMode_);
    if (status_ != windowStatus) {
        status_ = windowStatus;
        NotifyWindowStatusChange(windowStatus);
    }
}
void Window::NotifyWindowStatusChange(WindowStatus windowStatus)
{
    LOGD("NotifyWindowStatusChange %d",windowStatus);
    auto windowStatusChangeListeners = GetListeners<IWindowStatusChangeListener>();
    for (auto& listener : windowStatusChangeListeners) {
        if (listener != nullptr) {
            listener->OnWindowStatusChange(windowStatus);
        }
    }
}

void Window::NotifySafeAreaChanged()
{
     for (auto type : {
            AvoidAreaType::TYPE_SYSTEM,
            AvoidAreaType::TYPE_CUTOUT,
            AvoidAreaType::TYPE_NAVIGATION_INDICATOR
        }) {
        auto avoidArea  = std::make_shared<Rosen::AvoidArea>();
        GetAvoidAreaByType(type, *avoidArea);
        UpdateAvoidArea(avoidArea, type);
    }
}

void Window::UpdateAvoidArea(const std::shared_ptr<Rosen::AvoidArea>& avoidArea, AvoidAreaType type)
{
    if (!avoidArea) {
        LOGE("invalid avoidArea");
        return;
    }

    LOGD("UpdateAvoidArea type:%{public}d, top:{%{public}d,%{public}d,%{public}d,%{public}d}, "
        "left:{%{public}d,%{public}d,%{public}d,%{public}d}, right:{%{public}d,%{public}d,%{public}d,%{public}d}, "
        "bottom:{%{public}d,%{public}d,%{public}d,%{public}d}",
        type, avoidArea->topRect_.posX_, avoidArea->topRect_.posY_, avoidArea->topRect_.width_,
        avoidArea->topRect_.height_, avoidArea->leftRect_.posX_, avoidArea->leftRect_.posY_,
        avoidArea->leftRect_.width_, avoidArea->leftRect_.height_, avoidArea->rightRect_.posX_,
        avoidArea->rightRect_.posY_, avoidArea->rightRect_.width_, avoidArea->rightRect_.height_,
        avoidArea->bottomRect_.posX_, avoidArea->bottomRect_.posY_, avoidArea->bottomRect_.width_,
        avoidArea->bottomRect_.height_);

    {
        std::lock_guard<std::recursive_mutex> lock(globalMutex_);
        if (avoidAreaMap_[type] != *avoidArea) {
            avoidAreaMap_[type] = *avoidArea;
            NotifyAvoidAreaChange(avoidArea, type);
        }    
    }
}
void Window::NotifyAvoidAreaChange(const std::shared_ptr<AvoidArea>& avoidArea, AvoidAreaType type)
{
    auto avoidAreaChangeListeners = GetListeners<IAvoidAreaChangedListener>();
    for (auto& listener : avoidAreaChangeListeners) {
        if (listener != nullptr) {
            LOGD("type=%{public}u", type);
            listener->OnAvoidAreaChanged(*avoidArea, type);
        }
    }
}

void Window::NotifyTouchOutside()
{
    auto touchOutsideListeners = GetListeners<ITouchOutsideListener>();
    for (auto& listener : touchOutsideListeners) {
        if (listener != nullptr) {
            listener->OnTouchOutside();
        }
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

    auto surfaceNodeListeners = GetListeners<IWindowSurfaceNodeListener>();
    for (auto& listener : surfaceNodeListeners) {
        if (listener != nullptr) {
            listener->OnSurfaceNodeDestroyed();
        }
    }
}

bool Window::ProcessPointerEvent(const std::vector<uint8_t>& data)
{
    if (!uiContent_) {
        LOGW("Window::ProcessPointerEvent failed ,uicontent is nullptr");
        return false;
    }
    std::vector<std::shared_ptr<MMI::PointerEvent>> pointerEvents;
    Ace::Platform::ConvertMmiPointerEvent(pointerEvents, data);
    bool result = true;
    for (auto& pointerEvent : pointerEvents) {
         result &= uiContent_->ProcessPointerEvent(pointerEvent);
    }
    return result;
}

bool Window::ProcessPointerEventTargetHitTest(const std::vector<uint8_t>& data, const std::string& target)
{
    if (!uiContent_) {
        LOGW("Window::ProcessPointerEventTargetHitTest failed, uicontent is nullptr");
        return false;
    }
    std::shared_ptr<OHOS::MMI::PointerEvent> pointerEvent = OHOS::MMI::PointerEvent::Create();
    Ace::Platform::ConvertMmiPointerEvent(pointerEvent, data);
    return uiContent_->ProcessPointerEventTargetHitTest(pointerEvent, target);
}

bool Window::ProcessKeyEvent(int32_t keyCode, int32_t keyAction, int32_t repeatTime, int64_t timeStamp,
    int64_t timeStampStart, int32_t metaKey)
{
    if (!uiContent_) {
        return false;
    }

    Ace::KeyCode aceKeyCode = KeyCodeToAceKeyCode(keyCode);
    Ace::SourceType sourceType = Ace::SourceType::NONE;

    if (aceKeyCode != Ace::KeyCode::KEY_UNKNOWN) {
        sourceType = Ace::SourceType::KEYBOARD;
    } 

    return uiContent_->ProcessKeyEvent(static_cast<int32_t>(aceKeyCode), keyAction, repeatTime, timeStamp, timeStampStart, metaKey, static_cast<int32_t>(sourceType));
}

void Window::DelayNotifyUIContentIfNeeded()
{
    if (!uiContent_) {
        LOGE("Window Delay Notify uiContent_ is nullptr!");
        return;
    }
    if (delayNotifySurfaceCreated_) {
        LOGD("Window Delay Notify uiContent_ Surface Created");
        uiContent_->NotifySurfaceCreated();
    }

    if (delayNotifySurfaceChanged_) {
        LOGD("Window Delay Notify uiContent_ Surface Changed wh:[%{public}d, %{public}d]", surfaceWidth_,
            surfaceHeight_);
        Ace::ViewportConfig config;
        config.SetDensity(density_);
        config.SetSize(surfaceWidth_, surfaceHeight_);
        config.SetOrientation(surfaceWidth_ <= surfaceHeight_ ? 0 : 1);
        uiContent_->UpdateViewportConfig(config, WindowSizeChangeReason::RESIZE);
    }

    if (delayNotifySurfaceDestroyed_) {
        LOGI("Window Delay Notify uiContent_ Surface Destroyed");
        uiContent_->NotifySurfaceDestroyed();
        delayNotifySurfaceDestroyed_ = false;
    }

    if (delayNotifyFocusChanged_) {
        if (isFocused_) {
            uiContent_->Focus();
        } else {
            uiContent_->UnFocus();
        }
        delayNotifyFocusChanged_ = false;
    }
}

WMError Window::SetUIContent(const std::string& contentInfo,
    NativeEngine* engine, napi_value storage, bool isdistributed,
    AbilityRuntime::Platform::Ability* ability, bool loadContentByName)
{
    LOGI("Window::SetUIContent : Start");
    using namespace OHOS::Ace::Platform;
    (void)ability;
    if (uiContent_) {
        uiContent_->Destroy();
    }
    std::unique_ptr<UIContent> uiContent;
    uiContent = UIContent::Create(context_.get(), engine);
    if (uiContent == nullptr) {
        LOGE("Window::SetUIContent : Create UIContent Failed!");
        return WMError::WM_ERROR_NULLPTR;
    }
    if (loadContentByName) {
        LOGI("Window::SetUIContent: InitializeByName");
        uiContent->InitializeByName(this, contentInfo, storage);
    }else {
        uiContent->Initialize(this, contentInfo, storage);
    }

    // make uiContent available after Initialize/Restore
    uiContent_ = std::move(uiContent);

    DelayNotifyUIContentIfNeeded();
    NSLog(@"applicationState is %ld", (long)[UIApplication sharedApplication].applicationState);
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
        uiContent_->Foreground();
    }
    LOGI("Window::SetUIContent : End!!!");
    return WMError::WM_OK;
}

Ace::Platform::UIContent* Window::GetUIContent() {
    return uiContent_.get();
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

void Window::SetMode(WindowMode windowMode)
{
    windowMode_ = windowMode;
}

void Window::SetParentId(uint32_t parentId)
{
    parentId_ = parentId;
}

void Window::WindowActiveChanged(bool isActive)
{
    if (uiContent_) {
       if (isActive && isFocused_) {
            LOGI("Window: notify uiContent Focus");
            uiContent_->Focus();
        } else {
            Ace::DragState dragState;
            Ace::InteractionInterface::GetInstance()->GetDragState(dragState);
            if (dragState == Ace::DragState::START) {
                OHOS::Ace::DragDropRet dropResult { OHOS::Ace::DragRet::DRAG_CANCEL, false, GetWindowId(),
                        OHOS::Ace::DragBehavior::UNKNOWN };
                Ace::InteractionInterface::GetInstance()->StopDrag(dropResult);
            }
            LOGI("Window: notify uiContent UnFocus");
            uiContent_->UnFocus();
        }
    }
}

void Window::WindowFocusChanged(bool hasWindowFocus)
{
    isFocused_ = hasWindowFocus;
    if (uiContent_) {
       if (hasWindowFocus) {
            LOGI("Window: notify uiContent Focus");
            uiContent_->Focus();
        } else {
            LOGI("Window: notify uiContent UnFocus");
            uiContent_->UnFocus();
        }
    } else {
        delayNotifyFocusChanged_ = true;
    }
    if (isActive_ != hasWindowFocus) {
        isActive_ = hasWindowFocus;
        if (isActive_) {
            NotifyAfterActive();
        } else {
            NotifyAfterInactive();
        }
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
    UpdateWindowStatus();
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
    UpdateWindowStatus();
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
    LOGI("Window::SetBackgroundColor called. color=%u", color);
    backgroundColor_ = color;

    if (uiContent_) {
        uiContent_->SetBackgroundColor(color);
        return WMError::WM_OK;
    }
    return WMError::WM_ERROR_INVALID_OPERATION;
}

WMError Window::SetBrightness(float brightness)
{
    if (brightness < MINIMUM_BRIGHTNESS || brightness > MAXIMUM_BRIGHTNESS) {
        LOGE("invalid brightness value: %{public}f", brightness);
        return WMError::WM_ERROR_INVALID_PARAM;
    }
    windowView_.brightness = brightness;
    if (isWindowShow_) {
        [windowView_ updateBrightness:true];
    }
    return WMError::WM_OK;
}

float Window::GetBrightness() const
{
    if (windowView_ != nullptr) {
        return windowView_.brightness;
    }
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

WMError Window::SetWindowPrivacyMode(bool isPrivacyMode) {
    if (IsSubWindow()) {
        return WMError::WM_OK;
    }
    StageViewController* controller = [StageApplication getApplicationTopViewController];
    if (![controller isKindOfClass:[StageViewController class]]) {
        return WMError::WM_ERROR_INVALID_WINDOW;;
    }
    controller.privacyMode = isPrivacyMode;
     return WMError::WM_OK;
}
WMError Window::SetSystemBarProperty(WindowType type, const SystemBarProperty& property)
{
    WMError ret = SetSystemBar(type, property);
    if ( ret == WMError::WM_OK) {
        sysBarPropMap_[type] = property;
    }
    return WMError::WM_OK;
}

WMError Window::UpdateSystemBarProperties(
    const std::unordered_map<WindowType, SystemBarProperty>& systemBarProperties,
    const std::unordered_map<WindowType, SystemBarPropertyFlag>& systemBarPropertyFlags)
{
    for (auto& [systemBarType, systemBarPropertyFlag] : systemBarPropertyFlags) {
        if (systemBarProperties.find(systemBarType) == systemBarProperties.end()) {
            LOGI("Window::UpdateSystemBarProperties system bar type is invalid");
            return WMError::WM_DO_NOTHING;
        }
        auto property = GetSystemBarPropertyByType(systemBarType);
        property.enable_ = systemBarPropertyFlag.enableFlag ?
            systemBarProperties.at(systemBarType).enable_ : property.enable_;
        
        property.backgroundColor_ = systemBarPropertyFlag.backgroundColorFlag ?
            systemBarProperties.at(systemBarType).backgroundColor_ : property.backgroundColor_;
        property.contentColor_ = systemBarPropertyFlag.contentColorFlag ?
            systemBarProperties.at(systemBarType).contentColor_ : property.contentColor_;
        property.enableAnimation_ = systemBarPropertyFlag.enableAnimationFlag ?
            systemBarProperties.at(systemBarType).enableAnimation_ : property.enableAnimation_;
        if (systemBarPropertyFlag.enableFlag) {
            property.settingFlag_ |= SystemBarSettingFlag::ENABLE_SETTING;
        }
        if (systemBarPropertyFlag.backgroundColorFlag || systemBarPropertyFlag.contentColorFlag) {
            property.settingFlag_ |= SystemBarSettingFlag::COLOR_SETTING;
        }
        if (systemBarPropertyFlag.enableFlag || systemBarPropertyFlag.backgroundColorFlag ||
            systemBarPropertyFlag.contentColorFlag || systemBarPropertyFlag.enableAnimationFlag) {
            if (systemBarType == WindowType::WINDOW_TYPE_STATUS_BAR) {
                SetStatusBar(property.contentColor_, property.backgroundColor_, property.enableAnimation_);
            } else {
                LOGE("The WindowType is not set to UpdateSystemBarProperties. The WindowType is %{public}d", systemBarType);
            }
        }
        // std::lock_guard<std::recursive_mutex> lock(g_sysBarPropMapMutex);
        sysBarPropMap_[systemBarType] = property;
    }
    return WMError::WM_OK;
}

void Window::SetStatusBar(uint32_t titleColor, uint32_t backgroundColor, bool animation)
{
    StageViewController* controller = [StageApplication getApplicationTopViewController];
    if (![controller isKindOfClass:[StageViewController class]]) {
        return;
    }
    if (titleColor == SYSTEM_COLOR_WHITE) {
        controller.statusBarStyle = UIStatusBarStyleLightContent;
    } else if (titleColor == SYSTEM_COLOR_BLACK) {
        if (@available(iOS 13.0, *)) {
            controller.statusBarStyle =  UIStatusBarStyleDarkContent;
        } else {
            controller.statusBarStyle =  UIStatusBarStyleDefault;
        }
    } else {
        controller.statusBarStyle =  UIStatusBarStyleDefault;
    }
    controller.statusBarAnimation = animation;
    [[UIApplication sharedApplication]setStatusBarStyle:controller.statusBarStyle animated:animation];
    [controller setNeedsStatusBarAppearanceUpdate];
}

void Window::SetRequestedOrientation(Orientation orientation)
{
    if (orientation == Orientation::UNSPECIFIED || orientation == Orientation::VERTICAL) {
        windowView_.OrientationMask = UIInterfaceOrientationMaskPortrait;
    } else if (orientation == Orientation::HORIZONTAL) {
        windowView_.OrientationMask = UIInterfaceOrientationMaskLandscapeRight;
    } else if (orientation == Orientation::REVERSE_HORIZONTAL) {
        windowView_.OrientationMask = UIInterfaceOrientationMaskLandscapeLeft;
    } else if (orientation == Orientation::REVERSE_VERTICAL) {
        windowView_.OrientationMask = UIInterfaceOrientationMaskPortraitUpsideDown;
    } else if (orientation == Orientation::SENSOR) {
        windowView_.OrientationMask = UIInterfaceOrientationMaskAll;
    } else if (orientation == Orientation::SENSOR_VERTICAL) {
        windowView_.OrientationMask = UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
    } else if (orientation == Orientation::SENSOR_HORIZONTAL) {
        windowView_.OrientationMask = UIInterfaceOrientationMaskLandscape;
    }

    [[NSNotificationCenter defaultCenter]postNotificationName:@(kOrientationMaskUpdateNotificationName)
        object:nil userInfo:@{@(kOrientationMaskUpdateNotificationKey):@(windowView_.OrientationMask)}];
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
    ClearUselessListeners(windowChangeListeners_, winId);
    ClearUselessListeners(touchOutsideListeners_, winId);
    ClearUselessListeners(surfaceNodeListeners_, winId);
    ClearUselessListeners(windowStatusChangeListeners_, winId);
    ClearUselessListeners(avoidAreaChangeListeners_, winId);
}

void Window::NotifyWillTeminate()
{
    if (notifyWillTerminatefunc_) {
        notifyWillTerminatefunc_();
    }
}

void Window::NotifySizeChange(Rect rect)
{
    auto windowChangeListeners = GetListeners<IWindowChangeListener>();
    for (auto& listener : windowChangeListeners) {
        if (listener != nullptr) {
            listener->OnSizeChange(rect);
        }
    }
}

void Window::NotifyKeyboardHeightChanged(int32_t height)
{
    if (keyBoardHieght_ == height) {
        return;
    }
    keyBoardHieght_ = height;
    auto occupiedAreaChangeListeners = GetListeners<IOccupiedAreaChangeListener>();
    for (auto& listener : occupiedAreaChangeListeners) {
        if (listener != nullptr) {
            Rect rect = { 0, 0, 0, height };
            listener->OnSizeChange(rect, OccupiedAreaType::TYPE_INPUT);
        }
    }
    LOGD("NotifyKeyboardHeightChanged %d",height);
    auto type = AvoidAreaType::TYPE_KEYBOARD;
    auto avoidArea  = std::make_shared<Rosen::AvoidArea>();
    GetAvoidAreaByType(type, *avoidArea);
    UpdateAvoidArea(avoidArea, type);
}

WMError Window::RegisterOccupiedAreaChangeListener(const sptr<IOccupiedAreaChangeListener>& listener)
{
    LOGD("Start register");
    std::lock_guard<std::recursive_mutex> lock(globalMutex_);
    return RegisterListener(occupiedAreaChangeListeners_[GetWindowId()], listener);
}

WMError Window::UnregisterOccupiedAreaChangeListener(const sptr<IOccupiedAreaChangeListener>& listener)
{
    LOGD("Start unregister");
    std::lock_guard<std::recursive_mutex> lock(globalMutex_);
    return UnregisterListener(occupiedAreaChangeListeners_[GetWindowId()], listener);
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

WMError Window::RegisterAvoidAreaChangeListener(const sptr<IAvoidAreaChangedListener>& listener)
{
    LOGD("Start register AvoidAreaChangeListener");
    std::lock_guard<std::recursive_mutex> lock(globalMutex_);
    WMError ret = RegisterListener(avoidAreaChangeListeners_[GetWindowId()], listener);
    return ret;
}

WMError Window::UnregisterAvoidAreaChangeListener(const sptr<IAvoidAreaChangedListener>& listener)
{
    LOGD("Start unregister AvoidAreaChangeListener");
    std::lock_guard<std::recursive_mutex> lock(globalMutex_);
    WMError ret = UnregisterListener(avoidAreaChangeListeners_[GetWindowId()], listener);
    return ret;
}

WMError Window::RegisterWindowStatusChangeListener(const sptr<IWindowStatusChangeListener>& listener)
{
    LOGD("Start register WindowChangeListener");
    std::lock_guard<std::recursive_mutex> lock(globalMutex_);
    return RegisterListener(windowStatusChangeListeners_[GetWindowId()], listener);
}

WMError Window::UnregisterWindowStatusChangeListener(const sptr<IWindowStatusChangeListener>& listener)
{
    LOGD("Start unregister WindowChangeListener");
    std::lock_guard<std::recursive_mutex> lock(globalMutex_);
    return UnregisterListener(windowStatusChangeListeners_[GetWindowId()], listener);

}

WMError Window::RegisterWindowChangeListener(const sptr<IWindowChangeListener>& listener)
{
    LOGD("Start register");
    std::lock_guard<std::recursive_mutex> lock(globalMutex_);
    return RegisterListener(windowChangeListeners_[GetWindowId()], listener);
}

WMError Window::UnregisterWindowChangeListener(const sptr<IWindowChangeListener>& listener)
{
    LOGD("Start unregister");
    std::lock_guard<std::recursive_mutex> lock(globalMutex_);
    return UnregisterListener(windowChangeListeners_[GetWindowId()], listener);
}

WMError Window::RegisterTouchOutsideListener(const sptr<ITouchOutsideListener>& listener)
{
    LOGD("Start register TouchOutsideListener");
    std::lock_guard<std::recursive_mutex> lock(globalMutex_);
    return RegisterListener(touchOutsideListeners_[GetWindowId()], listener);
}

WMError Window::UnregisterTouchOutsideListener(const sptr<ITouchOutsideListener>& listener)
{
    LOGD("Start unregister TouchOutsideListener");
    std::lock_guard<std::recursive_mutex> lock(globalMutex_);
    return UnregisterListener(touchOutsideListeners_[GetWindowId()], listener);
}

WMError Window::RegisterSurfaceNodeListener(const sptr<IWindowSurfaceNodeListener>& listener)
{
    LOGI("Start register SurfaceNodeListener");
    std::lock_guard<std::recursive_mutex> lock(globalMutex_);
    return RegisterListener(surfaceNodeListeners_[GetWindowId()], listener);
}

WMError Window::UnregisterSurfaceNodeListener(const sptr<IWindowSurfaceNodeListener>& listener)
{
    LOGI("Start unregister SurfaceNodeListener");
    std::lock_guard<std::recursive_mutex> lock(globalMutex_);
    return UnregisterListener(surfaceNodeListeners_[GetWindowId()], listener);
}

ColorSpace Window::GetColorSpaceFromSurfaceGamut(GraphicColorGamut colorGamut) const
{
    for (auto& item : COLOR_SPACE_JS_TO_GAMUT_MAP) {
        if (item.second == colorGamut) {
            return item.first;
        }
    }
    return ColorSpace::COLOR_SPACE_DEFAULT;
}

GraphicColorGamut Window::GetSurfaceGamutFromColorSpace(ColorSpace colorSpace) const
{
    for (auto& item : COLOR_SPACE_JS_TO_GAMUT_MAP) {
        if (item.first == colorSpace) {
            return item.second;
        }
    }
    return GraphicColorGamut::GRAPHIC_COLOR_GAMUT_SRGB;
}

WMError Window::SetColorSpace(ColorSpace colorSpace)
{
    auto surfaceGamut = GetSurfaceGamutFromColorSpace(colorSpace);
    LOGI("Window::SetColorSpace called. colorSpace=%{public}d, surfaceGamut=%{public}d", colorSpace, surfaceGamut);
    surfaceNode_->SetColorSpace(surfaceGamut);
    return WMError::WM_OK;
}

ColorSpace Window::GetColorSpace() const
{
    GraphicColorGamut gamut = surfaceNode_->GetColorSpace();
    ColorSpace colorSpace = GetColorSpaceFromSurfaceGamut(gamut);
    return colorSpace;
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

WMError Window::SetLayoutFullScreen(bool status) {
    StageViewController* controller = [StageApplication getApplicationTopViewController];
    if (![controller isKindOfClass:[StageViewController class]]) {
        return WMError::WM_ERROR_INVALID_WINDOW;
    }
    if (status == true) {
        LOGI("isLayoutFullScreen is ture");
        controller.edgesForExtendedLayout = UIRectEdgeAll;
        controller.navigationController.navigationBar.translucent = YES;
    } else {
        LOGI("isLayoutFullScreen is false");
        controller.edgesForExtendedLayout = UIRectEdgeNone;
        controller.navigationController.navigationBar.translucent = NO;
    }
    return WMError::WM_OK;
}

WMError Window::SetSpecificBarProperty(WindowType type, const SystemBarProperty& property) {
    WMError ret = SetSpecificBar(type, property);
    if (ret == WMError::WM_OK) {
        sysBarPropMap_[type] = property;
    }
    // WINDOW_TYPE_NAVIGATION_INDICATOR
    return ret;
}

WMError Window::GetAvoidAreaByType(AvoidAreaType type, AvoidArea& avoidArea) {
    avoidArea.topRect_ = emptyRect;
    avoidArea.leftRect_ = emptyRect;
    avoidArea.rightRect_ = emptyRect;
    avoidArea.bottomRect_ = emptyRect;

    if (@available(iOS 11.0, *)) {
        StageViewController* controller = [StageApplication getApplicationTopViewController];
        if (![controller isKindOfClass:[StageViewController class]]) {
            return WMError::WM_ERROR_INVALID_WINDOW;
        }
        UIEdgeInsets insets = windowView_.safeAreaInsets;
        UIScreen *screen = [UIScreen mainScreen];
        AvoidArea area;
        CGFloat scale = screen.scale;
        insets.left = insets.left * scale;
        insets.right = insets.right * scale;
        insets.top = insets.top * scale;
        insets.bottom = insets.bottom * scale;
        CGFloat width = windowView_.bounds.size.width * scale;
        CGFloat height = windowView_.bounds.size.height * scale;
        area.topRect_ = MakeAvoidRect(0, 0, width, insets.top);
        area.leftRect_ = MakeAvoidRect(0, 0, insets.left, height);
        area.rightRect_ = MakeAvoidRect(width, 0, insets.right ,height);
        area.bottomRect_ = MakeAvoidRect(0, height, width, insets.bottom);

         LOGD("UpdateAvoidAreaNew type:%{public}d, top:{%{public}d,%{public}d,%{public}d,%{public}d}, "
        "left:{%{public}d,%{public}d,%{public}d,%{public}d}, right:{%{public}d,%{public}d,%{public}d,%{public}d}, "
        "bottom:{%{public}d,%{public}d,%{public}d,%{public}d}",
        type, area.topRect_.posX_, area.topRect_.posY_, area.topRect_.width_,
        area.topRect_.height_, area.leftRect_.posX_, area.leftRect_.posY_,
       area.leftRect_.width_,  area.leftRect_.height_,  area.rightRect_.posX_,
        area.rightRect_.posY_,  area.rightRect_.width_,  area.rightRect_.height_,
         area.bottomRect_.posX_,  area.bottomRect_.posY_,  area.bottomRect_.width_,
        area.bottomRect_.height_);

        if (type == AvoidAreaType::TYPE_CUTOUT) {
            static UIDeviceOrientation orientation = UIDeviceOrientationPortrait;
            if ([UIDevice currentDevice].orientation == UIDeviceOrientationPortrait) {
                orientation = UIDeviceOrientationPortrait;
                avoidArea.topRect_ = area.topRect_;
            } else if ([UIDevice currentDevice].orientation == UIDeviceOrientationLandscapeLeft) {
                orientation = UIDeviceOrientationLandscapeLeft;
                avoidArea.leftRect_ = area.leftRect_;
            } else if ([UIDevice currentDevice].orientation == UIDeviceOrientationLandscapeRight) {
                orientation = UIDeviceOrientationLandscapeRight;
                avoidArea.rightRect_ = area.rightRect_;
            }
            if (orientation == UIDeviceOrientationPortrait) {
                avoidArea.topRect_ = area.topRect_;
            } else if (orientation == UIDeviceOrientationLandscapeLeft) {
                avoidArea.leftRect_ = area.leftRect_;
            } else if (orientation == UIDeviceOrientationLandscapeRight) {
                avoidArea.rightRect_ = area.rightRect_;
            }
        } else if (type == AvoidAreaType::TYPE_KEYBOARD) {
            CGFloat screenHeight = windowView_.window.bounds.size.height;
            CGRect rect = [windowView_ convertRect:windowView_.bounds toView:windowView_.window];
            CGFloat windowViewMaxY = (rect.size.height + rect.origin.y) * scale;
            CGFloat avoidHeight = windowViewMaxY - (screenHeight * scale - keyBoardHieght_);
            avoidHeight = avoidHeight > 0 ? avoidHeight : 0;
            avoidArea.bottomRect_ = MakeAvoidRect(0, rect.size.height * scale - avoidHeight, width, avoidHeight);
            LOGD("GetAvoidAreaByType screenHeight=%f,windowViewMaxY = %f avoidHeight = %f recty = %f,rectH= %f",
                screenHeight * scale, windowViewMaxY,avoidHeight,rect.origin.y,rect.size.height);
        } else if (type == AvoidAreaType::TYPE_SYSTEM) {
            avoidArea.topRect_ = area.topRect_;
            avoidArea.bottomRect_ = area.bottomRect_;
        } else if (type == AvoidAreaType::TYPE_NAVIGATION_INDICATOR) {
            avoidArea.bottomRect_ = area.bottomRect_;
        } else if (type == AvoidAreaType::TYPE_SYSTEM_GESTURE) {
        } else {
            LOGE("GetAvoidAreaByType failed, AvoidAreaType is invalid");
            return WMError::WM_ERROR_INVALID_PARAM;
        }
    } else {
        return WMError::WM_ERROR_INVALID_PARAM;
        LOGE("GetAvoidAreaByType failed, iOS version less than 11");
    }
    return WMError::WM_OK;
}
} // namespace OHOS::Rosen
