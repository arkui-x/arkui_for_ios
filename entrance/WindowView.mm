// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <__nullptr>
#include <cstddef>
#include <memory>
#include <vector>
#include "WindowView.h"
#include "virtual_rs_window.h"
#include "flutter/lib/ui/window/pointer_data_packet.h"

@interface WindowView()

@end

@implementation WindowView

std::weak_ptr<OHOS::Rosen::Window> _windowDelegate;
- (instancetype)init {
    if (self = [super init]) {
    }
    return self;
}
- (void)setWindowDelegate:(std::shared_ptr<OHOS::Rosen::Window>)window{
    std::weak_ptr<OHOS::Rosen::Window> _windowDelegate(window);
}
   
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self dispatchTouches:touches];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self dispatchTouches:touches];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self dispatchTouches:touches];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self dispatchTouches:touches];
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

- (void)dispatchTouches:(NSSet *)touches{
    const CGFloat scale = [UIScreen mainScreen].scale;
    std::unique_ptr<flutter::PointerDataPacket> packet = std::make_unique<flutter::PointerDataPacket>(touches.count);
    
    size_t pointer_index = 0;
    
    for (UITouch *touch in touches) {
        CGPoint windowCoordinates = [touch locationInView:self];
        
        flutter::PointerData pointer_data;
        pointer_data.Clear();
        
        constexpr int kMicrosecondsPerSecond = 1000 * 1000;
        pointer_data.time_stamp = touch.timestamp * kMicrosecondsPerSecond;
        
        pointer_data.change = PointerDataChangeFromUITouchPhase(touch.phase);
        
        pointer_data.kind = DeviceKindFromTouchType(touch);
        
        pointer_data.device = reinterpret_cast<int64_t>(touch);
        
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
    auto window = _windowDelegate.lock();
    if (window != nullptr) {
        window->ProcessPointerEvent(packet->data());
    }
    
}
- (void)createSurfaceNode {
    auto window = _windowDelegate.lock();
    if (window != nullptr) {
        window->CreateSurfaceNode(self.layer);
    }
}
- (void)notifySurfaceChangedWithWidth:(int32_t)width height:(int32_t)height {
    auto window = _windowDelegate.lock();
    if (window != nullptr) {
        window->NotifySurfaceChanged(width,height);
    }
}
- (void)notifySurfaceDestroyed {
    auto window = _windowDelegate.lock();
    if (window != nullptr) {
        window->NotifySurfaceDestroyed();
    }
}

@end
