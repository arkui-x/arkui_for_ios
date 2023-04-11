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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_WINDOW_VIEW_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_WINDOW_VIEW_H

#include <UIKit/UIKit.h>

#include <memory>

@class WindowView;

// @protocol WindowViewDelegate <NSObject>
// - (bool)ProcessPointerEvent(const std::vector<uint8_t>&) data;
// - (bool)ProcessKeyEvent(int32_t keyCode, int32_t keyAction, 
//                         int32_t repeatTime, int64_t timeStamp = 0,
//                         int64_t timeStampStart = 0);
// @end

// @protocol WindowViewDelegate <NSObject>
// -(bool) ProcessPointerEvent:(const std::vector<uint8_t>&) data;
// @end


@interface WindowView : UIView


// - (instancetype)init NS_UNAVAILABLE;
// + (instancetype)new NS_UNAVAILABLE;
// - (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
// - (instancetype)initWithCoder:(NSCoder*)aDecoder NS_UNAVAILABLE;

// - (instancetype)initWithDelegate:(id<FlutterViewEngineDelegate>)delegate
//                           opaque:(BOOL)opaque NS_DESIGNATED_INITIALIZER;

// - (instancetype)initWithDelegate:(std::weak_ptr<Window>)windowDelegate;
// @property(nomatic,weak)std::weak_ptr<Window> windowDelegate;

// - (void)createSurfaceNode : (CALayer*)layer;
// - (void)NotifySurfaceChanged : (int32_t)width, (int32_t)height;
// - (void)NotifySurfaceDestroyed;



@end

#endif  // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_WINDOW_VIEW_H
