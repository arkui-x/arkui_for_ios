/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_CAPABILITY_ACE_SURFACE_CAPTURE_HELPER_H
#define FOUNDATION_ACE_ADAPTER_IOS_CAPABILITY_ACE_SURFACE_CAPTURE_HELPER_H

#ifdef __OBJC__

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

typedef CALayer* (^HostLayerBlock)(void);
typedef void (^SurfaceFallbackDrawBlock)(CGRect bounds);

@interface AceSurfaceCaptureConfig : NSObject

@property (nonatomic, copy, readonly) NSString* widthKey;
@property (nonatomic, copy, readonly) NSString* heightKey;
@property (nonatomic, assign, readonly) const char* logTag;
@property (nonatomic, copy, readonly) HostLayerBlock hostLayerBlock;
@property (nonatomic, copy, readonly) SurfaceFallbackDrawBlock drawFallbackBlock;

- (instancetype)initWithWidthKey:(NSString*)widthKey
                       heightKey:(NSString*)heightKey
                          logTag:(const char*)logTag
                   hostLayerBlock:(HostLayerBlock)hostLayerBlock
               drawFallbackBlock:(SurfaceFallbackDrawBlock)drawFallbackBlock;

@end

@interface AceSurfaceCaptureHelper : NSObject

- (instancetype)initWithConfig:(AceSurfaceCaptureConfig*)config;
- (NSString*)captureSurface:(NSDictionary*)params bounds:(CGRect)bounds;

@end

#endif

#endif