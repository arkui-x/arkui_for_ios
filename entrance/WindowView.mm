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

#include "WindowView.h"
#include "hilog.h"

#include <__nullptr>
#include <cstddef>
#include <memory>
#include <vector>

#include "adapter/ios/capability/editing/iOSTxtInputManager.h"
#include "flutter/lib/ui/window/pointer_data_packet.h"
#include "virtual_rs_window.h"
#include "UINavigationController+StatusBar.h"
#include "core/event/key_event.h"
#import "AceWebResourcePlugin.h"
#import "AceWeb.h"
#import "StageContainerView.h"

#define ACE_ENABLE_GL
@interface WindowView()

@end

@implementation WindowView
{
    std::weak_ptr<OHOS::Rosen::Window> _windowDelegate;
    int32_t _width;
    int32_t _height;
    float _density;
    BOOL _needNotifySurfaceChangedWithWidth;
    BOOL _needCreateSurfaceNode;
    std::map<int64_t, int32_t> _deviceMap;
    int32_t _deviceId;
    BOOL _firstTouchFlag;
    std::vector<CGRect> hotAreas_;
}

+(Class)layerClass{
#ifdef ACE_ENABLE_GL
    return [CAEAGLLayer class];
#else
    return [CALayer class];
#endif
}

- (instancetype)init {
    if (self = [super init]) {
        NSLog(@"windowView init%@", self);
        _width = 0;
        _height = 0;
        self.multipleTouchEnabled = YES;
        _needNotifySurfaceChangedWithWidth = NO;
        _needCreateSurfaceNode = NO;
        _focusable = YES;
        _isFocused = NO;
        _firstTouchFlag = NO;
        [self setupNotificationCenterObservers];
        self.backgroundColor = [UIColor clearColor];
        _deviceMap = std::map<int64_t, int32_t>{};
        _deviceId = 0;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    UIScreen *screen = [UIScreen mainScreen];
    CGFloat scale = screen.scale;
    HILOG_INFO("layoutSubviews : bounds.width/height=%{public}u/%{public}u", 
        static_cast<int32_t>(self.bounds.size.width), 
        static_cast<int32_t>(self.bounds.size.height));
    int32_t width = static_cast<int32_t>(self.bounds.size.width * scale);
    int32_t height = static_cast<int32_t>(self.bounds.size.height * scale);
    if ([self.layer isKindOfClass:[CAEAGLLayer class]]) {
        CAEAGLLayer* layer = reinterpret_cast<CAEAGLLayer*>(self.layer);
        layer.allowsGroupOpacity = YES;
        CGFloat screenScale = scale;
        layer.contentsScale = screenScale;
        layer.rasterizationScale = screenScale;
    }
    [self notifySurfaceChangedWithWidth:width height:height density:scale];
}
- (void)setFullScreen:(BOOL)fullScreen {
    _fullScreen = fullScreen;
    if (fullScreen) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    } else {
        self.autoresizingMask = UIViewAutoresizingNone;
    }
}
- (BOOL)requestFocus {
    if (self.focusable) {
        [((StageContainerView*)self.superview) setActiveWindow:self];
        return YES;
    }
    return NO;
}

- (void)setTouchHotAreas:(CGRect[])rect size:(NSInteger)size{
    hotAreas_.clear();
    for (int i = 0; i < size; ++i) {
        hotAreas_.push_back(*(rect + i));
    }
}

- (BOOL)showOnView:(UIView*)rootView {
    if (rootView && [rootView isKindOfClass:[StageContainerView class]]) {
        if (self.fullScreen) {
            self.frame = rootView.bounds;
        }
        [((StageContainerView*)rootView) showWindow:self];
        return YES;
    }
    return NO;
}

- (BOOL)hide {
    if (self.superview && [self.superview isKindOfClass:[StageContainerView class]]) {
        [((StageContainerView*)self.superview) hiddenWindow:self];
        return YES;
    }
    return NO;
}

//invoked twice when hit,so need a flag to ensure only one touch outside callback
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event{
    _firstTouchFlag = !_firstTouchFlag;
    BOOL inside = NO;
    BOOL inHotArea = NO;
    if (hotAreas_.empty()) {
        inHotArea = YES;
    }
    for (std::vector<CGRect>::iterator it = hotAreas_.begin(); it != hotAreas_.end(); ++it) {
        if (!CGRectIsEmpty(*it) && CGRectContainsPoint(*it, point)) {
            inHotArea = YES;
        }
    }
    inside = [self.layer containsPoint:point] && inHotArea;

    if (!inside && _firstTouchFlag){
        [self touchOutside];
    }
    return inside;
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    __block bool isPointWebView = false;
    [AceWebResourcePlugin.getObjectMap enumerateKeysAndObjectsUsingBlock:^(
        NSString * _Nonnull key, AceWeb * _Nonnull aceWeb, BOOL * _Nonnull stop) {
        UIView *uiview = [aceWeb getWeb];
        CGPoint webPoint = [self convertPoint:point toView:uiview];
        if ([uiview pointInside:webPoint withEvent:event]) {
            isPointWebView = true;
        }
    }];

    return isPointWebView?nil:view;
}

- (void)setWindowDelegate:(std::shared_ptr<OHOS::Rosen::Window>)window {
    _windowDelegate = window;
    if (_needCreateSurfaceNode) {
        _needCreateSurfaceNode = NO;
        [self createSurfaceNode];
    }
    if (_needNotifySurfaceChangedWithWidth) {
        _needNotifySurfaceChangedWithWidth = NO;
        [self notifySurfaceChangedWithWidth:_width height:_height density:_density];
    }
}

- (std::shared_ptr<OHOS::Rosen::Window>)getWindow {
    return _windowDelegate.lock();
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self dispatchKeys:presses];
}

- (void)pressesChanged:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self dispatchKeys:presses];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self dispatchKeys:presses];
}

- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self dispatchKeys:presses];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self dispatchTouches:touches withEvent: event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self dispatchTouches:touches withEvent: event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self dispatchTouches:touches withEvent: event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self dispatchTouches:touches withEvent: event];
}

- (float)updateBrightness {
    if (_windowDelegate.lock() != nullptr) {
        [UIScreen mainScreen].brightness = _windowDelegate.lock()->GetBrightness();
    }
}

- (void)touchOutside {
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->NotifyTouchOutside();
    }
}

- (void)setIsFocused:(BOOL)isFocused {
    if (self.focusable && _isFocused != isFocused) {
        _isFocused = isFocused;
        [self notifyFocusChanged:isFocused];
    }
}
#pragma mark - Touch event handling

static flutter::PointerData::Change PointerDataChangeFromUITouchPhase(UITouchPhase phase) {
    switch (phase) {
        case UITouchPhaseBegan:
            return flutter::PointerData::Change::kDown;
        case UITouchPhaseMoved:
        case UITouchPhaseStationary:
            // There is no EVENT_TYPE_POINTER_STATIONARY. So we just pass a move type
            // with the same coordinates
            return flutter::PointerData::Change::kMove;
        case UITouchPhaseEnded:
            return flutter::PointerData::Change::kUp;
        case UITouchPhaseCancelled:
            return flutter::PointerData::Change::kCancel;
    }
    
    return flutter::PointerData::Change::kCancel;
}

static flutter::PointerData::DeviceKind DeviceKindFromTouchType(UITouch *touch) {
    if (@available(iOS 9, *)) {
        switch (touch.type) {
            case UITouchTypeDirect:
            case UITouchTypeIndirect:
                return flutter::PointerData::DeviceKind::kTouch;
            case UITouchTypeStylus:
                return flutter::PointerData::DeviceKind::kStylus;
        }
    } else {
        return flutter::PointerData::DeviceKind::kTouch;
    }
    
    return flutter::PointerData::DeviceKind::kTouch;
}

- (int32_t)getTouchDevice:(UITouch *)touch {
    UITouchPhase phase = touch.phase;
    int64_t device = reinterpret_cast<int64_t>(touch);

    int32_t deviceId;
    auto iter = _deviceMap.find(device);
    if (iter == _deviceMap.end()) {
        if (phase == UIPressPhaseBegan) {
            _deviceMap[device] = _deviceId;
            deviceId = _deviceId;
            _deviceId++;
        } else {
            return -1;
        }
    } else {
        deviceId = _deviceMap[device];
        if (phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled) {
            _deviceMap.erase(iter);
        }
        if (_deviceMap.size() == 0) {
            _deviceId = 0;
        }
    }
    return deviceId;
}

- (void)dispatchTouches:(NSSet *)touches withEvent:(UIEvent *) event {
    NSSet<UITouch *> *allTouches = [event allTouches];
    const CGFloat scale = [UIScreen mainScreen].scale;
    std::unique_ptr<flutter::PointerDataPacket> packet = std::make_unique<flutter::PointerDataPacket>(allTouches.count);

    size_t pointer_index = 0;
    for (UITouch *touch in allTouches) {
        CGPoint windowCoordinates = [touch locationInView:self];
        
        flutter::PointerData pointer_data;
        pointer_data.Clear();

        int64_t sysTimeStamp = OHOS::Ace::GetSysTimestamp();
        pointer_data.time_stamp = sysTimeStamp;
        pointer_data.size = allTouches.count;
        pointer_data.change = PointerDataChangeFromUITouchPhase(touch.phase);
        
        pointer_data.kind = DeviceKindFromTouchType(touch);
        
        int32_t device = [self getTouchDevice:touch];
        pointer_data.device = device;
        
        pointer_data.physical_x = windowCoordinates.x * scale;
        pointer_data.physical_y = windowCoordinates.y * scale;
        
        NSNumber *deviceKey = [NSNumber numberWithLongLong:pointer_data.device];
       
        if (@available(iOS 9, *)) {
            // These properties were introduced in iOS 9.0.
            pointer_data.pressure = touch.force;
            pointer_data.pressure_max = touch.maximumPossibleForce;
        } else {
            pointer_data.pressure = 1.0;
            pointer_data.pressure_max = 1.0;
        }
        
        pointer_data.radius_major = touch.majorRadius;
        pointer_data.radius_min = touch.majorRadius - touch.majorRadiusTolerance;
        pointer_data.radius_max = touch.majorRadius + touch.majorRadiusTolerance;
        
        // These properties were introduced in iOS 9.1
        if (@available(iOS 9.1, *)) {

            pointer_data.tilt = M_PI_2 - touch.altitudeAngle;

            pointer_data.orientation = [touch azimuthAngleInView:nil] - M_PI_2;
        }
        
        packet->SetPointerData(pointer_index++, pointer_data);
    }
    if (_windowDelegate.lock() != nullptr) {
        
        _windowDelegate.lock()->ProcessPointerEvent(packet->data());
    }
}

#pragma mark - Key event handling

static OHOS::Ace::KeyAction KeyActionChangeFromUIPressPhase(UIPressPhase phase) {
    switch (phase) {
        case UIPressPhaseBegan:
            return OHOS::Ace::KeyAction::DOWN;
        case UIPressPhaseChanged:
        case UIPressPhaseStationary:
        case UIPressPhaseEnded:
        case UIPressPhaseCancelled:
            return OHOS::Ace::KeyAction::UP;
    }
    return OHOS::Ace::KeyAction::UNKNOWN;
}

static int32_t GetModifierKeys(UIKeyModifierFlags modifierFlags) {
    int32_t ctrlKeysBit = 0;
    static enum CtrlKeysBit {
        ctrl = 1,
        shift = 2,
        alt = 4,
        meta = 8,
    };
    if (modifierFlags & UIKeyModifierControl) {
        ctrlKeysBit |= CtrlKeysBit::ctrl;
    }
    if (modifierFlags & UIKeyModifierShift) {
        ctrlKeysBit |= CtrlKeysBit::shift;
    }
    if (modifierFlags & UIKeyModifierAlternate) {
        ctrlKeysBit |= CtrlKeysBit::alt;
    }
    if (modifierFlags & UIKeyModifierCommand) {
        ctrlKeysBit |= CtrlKeysBit::meta;
    }
    return ctrlKeysBit;
}

- (void)dispatchKeys:(NSSet<UIPress *> *)presses {
    for (UIPress *press in presses) {
        UIKey *pressKey = press.key;
        UIKeyboardHIDUsage pressKeyCode = [pressKey keyCode];
        OHOS::Ace::KeyAction keyAction = KeyActionChangeFromUIPressPhase(press.phase);
        UIKeyModifierFlags modifierFlags = [pressKey modifierFlags];
        int32_t modifierKeys = GetModifierKeys(modifierFlags);
        int32_t repeatTime = 0;
        // trans NSTimeInterval(double) to int64_t
        int64_t timestamp = static_cast<int64_t>(press.timestamp * 1000);
        if (_windowDelegate.lock() != nullptr) {
            _windowDelegate.lock()->ProcessKeyEvent(
                static_cast<int32_t>(pressKeyCode), static_cast<int32_t>(keyAction), repeatTime, timestamp, timestamp, modifierKeys);
        }
    }
}

- (void)createSurfaceNode {
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->CreateSurfaceNode(self.layer);
    } else {
        _needCreateSurfaceNode = YES;
    }
}

- (void)notifySurfaceChangedWithWidth:(int32_t)width height:(int32_t)height density:(float)density {
    _width = width;
    _height = height;
    _density = density;
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->NotifySurfaceChanged(width, height, density);
    } else {
        _needNotifySurfaceChangedWithWidth = YES;
    }
}

- (void)notifySurfaceDestroyed {
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->NotifySurfaceDestroyed();
    }
}

- (void)notifyWindowDestroyed {
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->Destroy();
    }
}

- (void)setupNotificationCenterObservers {
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];

    [center addObserver:self
               selector:@selector(keyboardWillChangeFrame:)
                   name:UIKeyboardWillChangeFrameNotification
                 object:nil];

    [center addObserver:self
               selector:@selector(keyboardWillBeHidden:)
                   name:UIKeyboardWillHideNotification
                 object:nil];
}

// #pragma mark - Application lifecycle notifications

- (void)notifyForeground {
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->Foreground();
    }
}
- (void)notifyBackground {
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->Background();
    }
}

- (void)notifyActiveChanged:(BOOL)isActive {
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->WindowActiveChanged(isActive);
    }
}
- (void)notifyFocusChanged:(BOOL)focus {
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->WindowFocusChanged(focus);
    }
}

- (void)keyboardWillChangeFrame:(NSNotification*)notification {
    NSDictionary* info = [notification userInfo];
    CGFloat keyboardHeight = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
    CGFloat scale = [UIScreen mainScreen].scale;
    keyboardHeight = keyboardHeight * scale;
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->NotifyKeyboardHeightChanged(keyboardHeight);
    }
}

- (void)keyboardWillBeHidden:(NSNotification*)notification {
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->NotifyKeyboardHeightChanged(0);
    }
}

- (void)notifyHandleWillTerminate {
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->NotifyWillTeminate();
    }
}

- (BOOL)processBackPressed {
    if (_windowDelegate.lock() != nullptr) {
        return _windowDelegate.lock()->ProcessBackPressed();
    }
    return false;
}

- (void)dealloc {
    NSLog(@"WindowView->%@ dealloc",self);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)setNewOrientation:(UIInterfaceOrientation)Orientation {
    NSNumber *resetOrientationTarget = [NSNumber numberWithInt:UIInterfaceOrientationUnknown];
    [[UIDevice currentDevice] setValue:resetOrientationTarget forKey:@"orientation"];
    NSNumber *orientationTarget = [NSNumber numberWithInt:Orientation];
    [[UIDevice currentDevice] setValue:orientationTarget forKey:@"orientation"];
}

- (UIViewController*)getViewController {
    UIResponder *responder = self;
    while ((responder = [responder nextResponder])) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
    }
    return nil;
}

@end
