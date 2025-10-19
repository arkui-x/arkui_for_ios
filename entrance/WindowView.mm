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

#include "WindowView.h"
#include "hilog.h"

#include <__nullptr>
#include <cstddef>
#include <memory>
#include <vector>

#include "adapter/ios/capability/editing/iOSTxtInputManager.h"
#include "ace_pointer_data_packet.h"
#include "virtual_rs_window.h"
#include "UINavigationController+StatusBar.h"
#include "core/event/key_event.h"
#import "AceWebResourcePlugin.h"
#import "AcePlatformViewPlugin.h"
#import "AceWeb.h"
#import "StageContainerView.h"
#define HIT_TEST_TARGET_WEB  @"Web"
#define HIT_TEST_TARGET_PLATFORMVIEW @"PlatformView"

#define ACE_ENABLE_GL

static bool g_isPointInsideWebForceResult = false;
static bool g_isPointInsideWebForceEnable = false;
extern "C" void SetIsPointInsideWebForceResult(bool enable, bool result)
{
    g_isPointInsideWebForceEnable = enable;
    g_isPointInsideWebForceResult = result;
}

@interface WindowView()

@property (nonatomic, strong) CADisplayLink *displayLinkTouch;

@end

@implementation WindowView
{
    std::weak_ptr<OHOS::Rosen::Window> _windowDelegate;
    int32_t _width;
    int32_t _height;
    float _density;
    BOOL _needNotifySurfaceChangedWithWidth;
    BOOL _needCreateSurfaceNode;
    BOOL _needNotifyForground;
    BOOL _needNotifyFocus;
    std::map<int64_t, int32_t> _deviceMap;
    std::map<int64_t, int32_t> _pointerMap;
    int32_t _deviceId;
    int32_t _pointerId;
    BOOL _firstTouchFlag;
    std::vector<CGRect> hotAreas_;
    float _oldBrightness;
    NSTimer *_autoPausedTimer;
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
        _pointerMap = std::map<int64_t, int32_t>{};
        _deviceId = 0;
        _pointerId = 0;
        _oldBrightness = - 1;
        _brightness = [UIScreen mainScreen].brightness;
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
        layer.drawableProperties = @{
            kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8,
            kEAGLDrawablePropertyRetainedBacking : @(NO),
        };
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
    BOOL isTouchArkWeb = [self isPointInsideWeb:point withEvent:event];
    BOOL isTouchPlatfomrview = [self isPointInsidePlatformview: point withEvent:event];
    return (isTouchArkWeb || isTouchPlatfomrview)? nil : view;
}

- (BOOL)isPointInsidePlatformview:(CGPoint)point withEvent:(UIEvent *)event {
     __block bool isPointPlatformView = false;
    [AcePlatformViewPlugin.getObjectMap enumerateKeysAndObjectsUsingBlock:^(
        NSString * _Nonnull key, AcePlatformView * _Nonnull aceplatformview, BOOL * _Nonnull stop) {
        UIView *uiview = [aceplatformview getPlatformView];
        CGPoint platformPoint = [self convertPoint:point toView:uiview];
        if ([uiview pointInside:platformPoint withEvent:event]) {
            isPointPlatformView = true;
        }
    }];

    bool isTouchPlatfomrview = false;
    if (isPointPlatformView) {
        isTouchPlatfomrview = [self touchHitTestTarget:point targetName:HIT_TEST_TARGET_PLATFORMVIEW];
    }
    return isTouchPlatfomrview;
}

- (BOOL)isPointInsideWeb:(CGPoint)point withEvent:(UIEvent *)event {
     __block BOOL isNeedTouchTestArkWeb = NO;
    [AceWebResourcePlugin.getObjectMap enumerateKeysAndObjectsUsingBlock:^(
        NSString * _Nonnull key, AceWeb * _Nonnull aceWeb, BOOL * _Nonnull stop) {
        UIView *uiview = [aceWeb getWeb];
        CGPoint webPoint = [self convertPoint:point toView:uiview];
        if ([uiview pointInside:webPoint withEvent:event]) {
            isNeedTouchTestArkWeb = YES;
        }
    }];
    BOOL isTouchArkWeb = NO;
    if (isNeedTouchTestArkWeb) {
        isTouchArkWeb = [self touchHitTestTarget:point targetName:HIT_TEST_TARGET_WEB];
    }
    return isTouchArkWeb && g_isPointInsideWebForceEnable && !g_isPointInsideWebForceResult;
}

- (BOOL)touchHitTestTarget:(CGPoint)point targetName:(NSString*)target{
    std::unique_ptr<OHOS::Ace::Platform::AcePointerDataPacket> packet = 
        std::make_unique<OHOS::Ace::Platform::AcePointerDataPacket>(1);

    OHOS::Ace::Platform::AcePointerData  pointer_data;
    const CGFloat scale = [UIScreen mainScreen].scale;
    CGPoint windowCoordinates = point;
    pointer_data.window_x = windowCoordinates.x * scale;
    pointer_data.window_y = windowCoordinates.y * scale;
    pointer_data.pointer_id = 0;
    pointer_data.device_id = 0;
    auto now = std::chrono::high_resolution_clock::now();
    pointer_data.time_stamp = std::chrono::duration_cast<std::chrono::nanoseconds>(now.time_since_epoch()).count();
    pointer_data.pointer_action = OHOS::Ace::Platform::AcePointerData::PointerAction::kDowned;
    if (_windowDelegate.lock() != nullptr) {
        packet->SetPointerData(0, pointer_data);
        bool isTouchTarget =  _windowDelegate.lock()->ProcessPointerEventTargetHitTest(packet->data(),
        std::string([target UTF8String]));
        return isTouchTarget;
    }
    return false;
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
    if (_needNotifyForground) {
        _needNotifyForground = NO;
        [self notifyForeground];
    }
    if (_needNotifyFocus) {
        _needNotifyFocus = NO;
        [self notifyFocusChanged:_isFocused];
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
    if (self.displayLinkTouch) {
        self.displayLinkTouch.paused = NO;
        [self stopPausedTimer];
    }
    [self dispatchTouches:touches];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.displayLinkTouch) {
        self.displayLinkTouch.paused = NO;
        [self stopPausedTimer];
    }
    [self dispatchTouches:touches];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.displayLinkTouch) {
        [self startPausedTimer];
    }
    [self dispatchTouches:touches];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.displayLinkTouch) {
        [self startPausedTimer];
    }
    [self dispatchTouches:touches];
}

- (void)setBrightness:(float)brightness {
    _oldBrightness = _brightness;
    _brightness = brightness;
}

- (float)getBrightness {
    return _brightness;
}

- (void)updateBrightness:(BOOL)isShow {
    if (_oldBrightness == -1) {
        return;
    }
    float brightness = _oldBrightness;
    if (isShow) {
         brightness = _brightness;
    }
    [UIScreen mainScreen].brightness = brightness;
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

static OHOS::Ace::Platform::AcePointerData::PointerAction PointerDataChangeFromUITouchPhase(UITouchPhase phase) {
    auto action = OHOS::Ace::Platform::AcePointerData::PointerAction::kCanceled;
    switch (phase) {
        case UITouchPhaseBegan:
            action = OHOS::Ace::Platform::AcePointerData::PointerAction::kDowned;
            break;
        case UITouchPhaseMoved:
        case UITouchPhaseStationary:
            // There is no EVENT_TYPE_POINTER_STATIONARY. So we just pass a move type
            // with the same coordinates
            action = OHOS::Ace::Platform::AcePointerData::PointerAction::kMoved;
            break;
        case UITouchPhaseEnded:
            action = OHOS::Ace::Platform::AcePointerData::PointerAction::kUped;
            break;
        case UITouchPhaseCancelled:
            action = OHOS::Ace::Platform::AcePointerData::PointerAction::kCanceled;
            break;
        default:
            action = OHOS::Ace::Platform::AcePointerData::PointerAction::kCanceled;
            break;
    }

    return action;
}

static OHOS::Ace::Platform::AcePointerData::ToolType DeviceKindFromTouchType(UITouch *touch) {
    switch (touch.type) {
        case UITouchTypeDirect:
        case UITouchTypeIndirect:
            return OHOS::Ace::Platform::AcePointerData::ToolType::Touch;
        case UITouchTypeStylus:
            return OHOS::Ace::Platform::AcePointerData::ToolType::Stylus;
        case UITouchTypeIndirectPointer:
            return OHOS::Ace::Platform::AcePointerData::ToolType::Mouse;
        default:
        break;
    }
    return OHOS::Ace::Platform::AcePointerData::ToolType::Touch;
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

- (int32_t)getTouchPointer:(UITouch *)touch {
    UITouchPhase phase = touch.phase;
    int64_t pointer = reinterpret_cast<int64_t>(touch);

    int32_t pointerId;
    auto iter = _pointerMap.find(pointer);
    if (iter == _pointerMap.end()) {
        if (phase == UIPressPhaseBegan) {
            _pointerMap[pointer] = _pointerId;
            pointerId = _pointerId;
            _pointerId++;
        } else {
            return -1;
        }
    } else {
        pointerId = _pointerMap[pointer];
        if (phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled) {
            _pointerMap.erase(iter);
        }
        if (_pointerMap.size() == 0) {
            _pointerId = 0;
        }
    }
    return pointerId;
}

- (void)dispatchTouches:(NSSet *)touches {
    const CGFloat scale = [UIScreen mainScreen].scale;
    std::unique_ptr<OHOS::Ace::Platform::AcePointerDataPacket> packet = 
        std::make_unique<OHOS::Ace::Platform::AcePointerDataPacket>(touches.count);
    size_t pointer_index = 0;
    UIView *rootView = self.superview;
    for (UITouch *touch in touches) {
        CGPoint windowCoordinates = [touch locationInView:self];
        CGPoint screenCoordinates = [self convertPoint:windowCoordinates toView:rootView];

        OHOS::Ace::Platform::AcePointerData pointer_data;
        pointer_data.Clear();
        pointer_data.pointer_id = [self getTouchPointer:touch];
        pointer_data.device_id = [self getTouchDevice:touch];

        pointer_data.time_stamp = OHOS::Ace::GetMicroTickCount();
        pointer_data.finger_count = touches.count;

        pointer_data.pointer_action = PointerDataChangeFromUITouchPhase(touch.phase);
        pointer_data.tool_type = DeviceKindFromTouchType(touch);

        pointer_data.display_x = screenCoordinates.x * scale;
        pointer_data.display_y = screenCoordinates.y * scale;
        pointer_data.window_x = windowCoordinates.x * scale;
        pointer_data.window_y = windowCoordinates.y * scale;

        pointer_data.pressure = touch.force;
        pointer_data.radius_major = touch.majorRadius;
        pointer_data.radius_min = touch.majorRadius - touch.majorRadiusTolerance;
        pointer_data.radius_max = touch.majorRadius + touch.majorRadiusTolerance;
        pointer_data.actionPoint = true;
        pointer_data.tilt = M_PI_2 - touch.altitudeAngle;
        pointer_data.orientation = [touch azimuthAngleInView:nil] - M_PI_2;

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
    if (self.displayLinkTouch) {
        NSLog(@"WindowView notifyWindowDestroyed in");
        [self stopPausedTimer];
        [self.displayLinkTouch invalidate];
        self.displayLinkTouch = nil;
    }
}

- (void)notifySafeAreaChanged {
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->NotifySafeAreaChanged();
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
    } else {
        _needNotifyForground = YES;
    }
}
- (void)notifyBackground {
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->Background();
    }
}

- (void)notifyActiveChanged:(BOOL)isActive {
    [self updateBrightness:isActive];
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->WindowActiveChanged(isActive);
    }
}
- (void)notifyFocusChanged:(BOOL)focus {
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->WindowFocusChanged(focus);
    } else {
        _needNotifyFocus = YES;
    }
}

- (void)notifyApplicationForeground:(BOOL)isForeground {
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->NotifyApplicationForeground(isForeground);
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

- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange];
    [self notifySafeAreaChanged];
}

- (void)keyboardWillBeHidden:(NSNotification*)notification {
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->NotifyKeyboardHeightChanged(0);
    }
}

- (void)notifyTraitCollectionDidChange:(BOOL)isSplitScreen {
    if (_windowDelegate.lock() != nullptr) {
        _windowDelegate.lock()->NotifyTraitCollectionDidChange(isSplitScreen);
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

- (UIViewController*)getViewController {
    UIResponder *responder = self;
    while ((responder = [responder nextResponder])) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
    }
    return nil;
}

- (void)startBaseDisplayLink {
    float mainMaxFrameRate = [UIScreen mainScreen].maximumFramesPerSecond;
     const double epsilon = 0.1;
    if (mainMaxFrameRate < 60.0 + epsilon) {
        return;
    }
    self.displayLinkTouch = [CADisplayLink displayLinkWithTarget:self selector:@selector(onDisplayLinkTouch:)];
    self.displayLinkTouch.paused = YES;
    if (@available(iOS 15.0,*)) {
        float maxFrameRate = fmax(mainMaxFrameRate, 60);
        NSLog(@"startBaseDisplayLink maxFrameRate = %f",maxFrameRate);
        self.displayLinkTouch.preferredFrameRateRange = CAFrameRateRangeMake(maxFrameRate, maxFrameRate, maxFrameRate);
    } else {
        self.displayLinkTouch.preferredFramesPerSecond = mainMaxFrameRate;
    }
    [self.displayLinkTouch addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)onDisplayLinkTouch:(CADisplayLink*)link {}

- (void)startPausedTimer {
    if (_autoPausedTimer) {
        [_autoPausedTimer invalidate];
        _autoPausedTimer = nil;
    }
    _autoPausedTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                    target:self
                                  selector:@selector(autoPausedTimerFun)
                                  userInfo:nil
                                   repeats:NO];
}

- (void)stopPausedTimer {
    if (_autoPausedTimer) {
        [_autoPausedTimer invalidate];
        _autoPausedTimer = nil;
    }
}

- (void)autoPausedTimerFun {
    self.displayLinkTouch.paused = YES;
    if (_autoPausedTimer) {
        [_autoPausedTimer invalidate];
        _autoPausedTimer = nil;
    }
}
@end
