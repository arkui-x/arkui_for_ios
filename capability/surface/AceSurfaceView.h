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

#ifndef FOUNDATION_ADAPTER_CAPABILITY_SURFACE_ACESURFACEVIEW_H
#define FOUNDATION_ADAPTER_CAPABILITY_SURFACE_ACESURFACEVIEW_H

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "IAceOnResourceEvent.h"
#import "IAceOnCallResourceMethod.h"
NS_ASSUME_NONNULL_BEGIN

@interface AceSurfaceView : UIView
- (instancetype)initWithId:(int64_t)incId callback:(IAceOnResourceEvent)callback
    param:(NSDictionary*)initParam superTarget:(id)target abilityInstanceId:(int32_t)abilityInstanceId;

/**
 * Get the call method map.
 *
 * @return Map
 */
- (NSDictionary<NSString*, IAceOnCallSyncResourceMethod>*)getCallMethod;

/**
 * Set the size of the texture
 *
 * @param params size params
 * @return result of setting texture size
 */
- (NSString*)setSurfaceBounds:(NSDictionary*)params;

/**
 * Get the surface.
 *
 * @return Surface
 */
- (AVPlayerLayer*)getSurface;

/**
 * Release the surface.
 *
 */
- (void)releaseObject;

/**
 * take surface front
 *
 */
- (void)bringSubviewToFront;
@end

NS_ASSUME_NONNULL_END

#endif // FOUNDATION_ADAPTER_CAPABILITY_SURFACE_ACESURFACEVIEW_H