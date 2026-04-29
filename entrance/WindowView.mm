/*
 * Copyright (c) 2023-2026 Huawei Device Co., Ltd.
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
#include <atomic>
#include <cstddef>
#include <map>
#include <memory>
#include <vector>
#include "base/utils/time_util.h"

#include "adapter/ios/entrance/interaction/interaction_impl.h"
#include "adapter/ios/capability/editing/iOSTxtInputManager.h"
#include "ace_pointer_data_packet.h"
#include "virtual_rs_window.h"
#include "UINavigationController+StatusBar.h"
#include "core/event/key_event.h"
#import <Foundation/Foundation.h>
#import "AceWebResourcePlugin.h"
#import "AcePlatformViewPlugin.h"
#import "AceWeb.h"
#import "StageContainerView.h"
#define HIT_TEST_TARGET_WEB  @"Web"
#define HIT_TEST_TARGET_PLATFORMVIEW @"PlatformView"

#define ACE_ENABLE_GL

static bool g_isPointInsideWebForceResult = false;
static bool g_isPointInsideWebForceEnable = false;
static const uint64_t KEY_REPEAT_INITIAL_DELAY_MS = 500;
static const uint64_t KEY_REPEAT_INTERVAL_MS = 100;
static const uint64_t KEY_REPEAT_LEEWAY_MS = 5;
static const int64_t MILLISECONDS_PER_SECOND = 1000;
static const char* KEY_REPEAT_QUEUE_NAME = "com.ohos.ace.keyrepeat";
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

    dispatch_source_t _keyRepeatTimer;
    dispatch_queue_t _keyRepeatQueue;
    int32_t _currentKeyCode;
    int32_t _currentModifierKeys;
    int32_t _keyRepeatCount;
    BOOL _isInitialDelay;
    std::atomic<uint64_t> _keyRepeatGeneration;
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
        LOGI("windowView init");
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

        _keyRepeatQueue = dispatch_queue_create(KEY_REPEAT_QUEUE_NAME, DISPATCH_QUEUE_SERIAL);
        _keyRepeatTimer = NULL;
        _keyRepeatCount = 0;
        _isInitialDelay = NO;
        _keyRepeatGeneration = 0;
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
    [self stopKeyRepeatTimer];
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

static const char* SyntheticPhaseToString(UITouchPhase phase)
{
    switch (phase) {
        case UITouchPhaseBegan:
            return "BEGAN";
        case UITouchPhaseMoved:
            return "MOVED";
        case UITouchPhaseStationary:
            return "STATIONARY";
        case UITouchPhaseEnded:
            return "ENDED";
        case UITouchPhaseCancelled:
            return "CANCELLED";
        default:
            return "UNKNOWN";
    }
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

static bool IsSyntheticTouchActive(UITouchPhase phase)
{
    return phase == UITouchPhaseBegan || phase == UITouchPhaseMoved || phase == UITouchPhaseStationary;
}

static void UpdateSyntheticTouchDisplayLink(WindowView *view, UITouchPhase phase)
{
    if (!view.displayLinkTouch) {
        return;
    }
    if (IsSyntheticTouchActive(phase)) {
        view.displayLinkTouch.paused = NO;
        [view stopPausedTimer];
        return;
    }
    if (phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled) {
        [view startPausedTimer];
    }
}

struct SyntheticPointerDataParams {
    UITouchPhase phase;
    CGFloat scale;
    CGPoint windowCoordinates;
    CGPoint displayCoordinates;
    int32_t pointerId;
    int64_t timeStamp;
};

static OHOS::Ace::Platform::AcePointerData CreateSyntheticPointerData(
    const SyntheticPointerDataParams& params)
{
    OHOS::Ace::Platform::AcePointerData pointerData;
    pointerData.Clear();
    pointerData.pointer_id = params.pointerId >= 0 ? params.pointerId : 0;
    pointerData.device_id = 0;
    pointerData.time_stamp =
        params.timeStamp > 0 ? params.timeStamp : OHOS::Ace::GetMicroTickCount();
    pointerData.finger_count = 1;
    pointerData.pointer_action = PointerDataChangeFromUITouchPhase(params.phase);
    pointerData.tool_type = OHOS::Ace::Platform::AcePointerData::ToolType::Touch;
    pointerData.display_x = params.displayCoordinates.x * params.scale;
    pointerData.display_y = params.displayCoordinates.y * params.scale;
    pointerData.window_x = params.windowCoordinates.x * params.scale;
    pointerData.window_y = params.windowCoordinates.y * params.scale;
    pointerData.pressure =
        (params.phase == UITouchPhaseEnded || params.phase == UITouchPhaseCancelled) ? 0.0f : 1.0f;
    pointerData.radius_major = 0.0;
    pointerData.radius_min = 0.0;
    pointerData.radius_max = 0.0;
    pointerData.tilt = 0.0;
    pointerData.orientation = 0.0;
    pointerData.actionPoint = true;
    return pointerData;
}

- (int32_t)getTouchDevice:(UITouch *)touch {
    UITouchPhase phase = touch.phase;
    int64_t device = reinterpret_cast<int64_t>(touch);

    int32_t deviceId;
    auto iter = _deviceMap.find(device);
    if (iter == _deviceMap.end()) {
        if (phase == UITouchPhaseBegan) {
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
        if (phase == UITouchPhaseBegan) {
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

- (BOOL)dispatchSyntheticTouchWithPhase:(UITouchPhase)phase
                                pixelX:(CGFloat)pixelX
                                pixelY:(CGFloat)pixelY
                             pointerId:(int32_t)pointerId
                             timeStamp:(int64_t)timeStamp
{
    UpdateSyntheticTouchDisplayLink(self, phase);

    auto window = [self getWindow];
    if (window == nullptr) {
        return NO;
    }

    CGFloat scale = [UIScreen mainScreen].scale;
    if (scale <= 0.0) {
        scale = 1.0;
    }
    UIView *displayView = self.superview ?: self;
    CGPoint windowCoordinates = CGPointMake(pixelX / scale, pixelY / scale);
    CGPoint displayCoordinates = displayView == self ? windowCoordinates :
        [self convertPoint:windowCoordinates toView:displayView];

    const SyntheticPointerDataParams pointerParams {
        phase, scale, windowCoordinates, displayCoordinates, pointerId, timeStamp
    };
    auto pointerData = CreateSyntheticPointerData(pointerParams);

    const bool syntheticActive = IsSyntheticTouchActive(phase);
    OHOS::Ace::UpdateSyntheticDragTouchState(pointerData.pointer_id, syntheticActive);
    OHOS::Ace::PrepareSyntheticDragCompensationContext(pointerData.pointer_id, syntheticActive,
        phase == UITouchPhaseBegan, pointerData.time_stamp);

    OHOS::Ace::Platform::AcePointerDataPacket packet(1);
    packet.SetPointerData(0, pointerData);
    const bool result = window->ProcessSyntheticPointerEvent(packet.data());
    OHOS::Ace::CompleteSyntheticDragTouchState(pointerData.pointer_id, syntheticActive);
    return result;
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

- (void)stopKeyRepeatTimer {
    _keyRepeatGeneration.fetch_add(1, std::memory_order_relaxed);
    if (_keyRepeatTimer) {
        dispatch_source_cancel(_keyRepeatTimer);
        dispatch_release(_keyRepeatTimer);
        _keyRepeatTimer = NULL;
    }
    _keyRepeatCount = 0;
    _isInitialDelay = NO;
}

- (void)handleKeyRepeatForGeneration:(uint64_t)generation {
    if (_keyRepeatGeneration.load(std::memory_order_relaxed) != generation) {
        return;
    }

    int32_t repeatCount = ++_keyRepeatCount;
    int32_t keyCode = _currentKeyCode;
    int32_t modifierKeys = _currentModifierKeys;
    int64_t timestamp =
        static_cast<int64_t>([[NSDate date] timeIntervalSince1970] * MILLISECONDS_PER_SECOND);

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_keyRepeatGeneration.load(std::memory_order_relaxed) != generation) {
            return;
        }
        auto window = self->_windowDelegate.lock();
        if (window != nullptr) {
            window->ProcessKeyEvent(
                keyCode,
                static_cast<int32_t>(OHOS::Ace::KeyAction::DOWN),
                repeatCount,
                timestamp,
                timestamp,
                modifierKeys);
        }
    });

    if (_keyRepeatGeneration.load(std::memory_order_relaxed) != generation) {
        return;
    }
    if (_isInitialDelay) {
        _isInitialDelay = NO;
        [self stopKeyRepeatTimer];
        [self startKeyRepeatTimerWithInterval:KEY_REPEAT_INTERVAL_MS];
    }
}

- (void)startKeyRepeatTimerWithInterval:(uint64_t)intervalMs {
    if (_keyRepeatTimer) {
        [self stopKeyRepeatTimer];
    }

    _keyRepeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _keyRepeatQueue);
    if (!_keyRepeatTimer) {
        return;
    }

    uint64_t intervalNs = intervalMs * NSEC_PER_MSEC;
    dispatch_source_set_timer(_keyRepeatTimer,
                              dispatch_time(DISPATCH_TIME_NOW, intervalNs),
                              intervalNs,
                              KEY_REPEAT_LEEWAY_MS * NSEC_PER_MSEC);

    uint64_t generation = _keyRepeatGeneration.load(std::memory_order_relaxed);
    __weak WindowView *weakSelf = self;
    dispatch_source_set_event_handler(_keyRepeatTimer, ^{
        WindowView *strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf handleKeyRepeatForGeneration:generation];
        }
    });

    dispatch_resume(_keyRepeatTimer);
}

- (void)dispatchKeys:(NSSet<UIPress *> *)presses {
    for (UIPress *press in presses) {
        UIKey *pressKey = press.key;
        if (!pressKey) {
            continue;
        }

        UIKeyboardHIDUsage pressKeyCode = [pressKey keyCode];
        OHOS::Ace::KeyAction keyAction = KeyActionChangeFromUIPressPhase(press.phase);
        UIKeyModifierFlags modifierFlags = [pressKey modifierFlags];
        int32_t modifierKeys = GetModifierKeys(modifierFlags);

        int32_t keyCode = static_cast<int32_t>(pressKeyCode);
        int64_t timestamp = static_cast<int64_t>(press.timestamp * MILLISECONDS_PER_SECOND);

        auto window = _windowDelegate.lock();
        if (press.phase == UIPressPhaseBegan) {
            [self stopKeyRepeatTimer];
            if (window != nullptr) {
                window->ProcessKeyEvent(
                    keyCode, static_cast<int32_t>(keyAction), 0, timestamp, timestamp, modifierKeys);
            }
            _currentKeyCode = keyCode;
            _currentModifierKeys = modifierKeys;
            _keyRepeatCount = 0;
            _isInitialDelay = YES;
            [self startKeyRepeatTimerWithInterval:KEY_REPEAT_INITIAL_DELAY_MS];
        } else if (press.phase == UIPressPhaseChanged) {
            if (window != nullptr) {
                window->ProcessKeyEvent(
                    keyCode, static_cast<int32_t>(keyAction), 0, timestamp, timestamp, modifierKeys);
            }
        } else if (press.phase == UIPressPhaseEnded || press.phase == UIPressPhaseCancelled) {
            [self stopKeyRepeatTimer];
            if (window != nullptr) {
                window->ProcessKeyEvent(
                    keyCode, static_cast<int32_t>(keyAction), 0, timestamp, timestamp, modifierKeys);
            }
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
        LOGI("WindowView notifyWindowDestroyed in");
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
    LOGI("WindowView dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopKeyRepeatTimer];
    if (_keyRepeatQueue) {
        dispatch_release(_keyRepeatQueue);
        _keyRepeatQueue = NULL;
    }
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
        LOGI("startBaseDisplayLink maxFrameRate = %{public}f", maxFrameRate);
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
