/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

#ifndef FOUNDATION_ADAPTER_CAPABILITY_TEXTURE_ACEXCOMPONENTTEXTUREVIEW_H
#define FOUNDATION_ADAPTER_CAPABILITY_TEXTURE_ACEXCOMPONENTTEXTUREVIEW_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "AcePlatformViewDelegate.h"
#import "AceTexture.h"
#import "IAceOnResourceEvent.h"
#import "IAceOnCallResourceMethod.h"
#import "IAceSurface.h"

NS_ASSUME_NONNULL_BEGIN

#ifndef dispatch_main_async_safe
#define dispatch_main_async_safe(block)             \
    if ([NSThread isMainThread]) {                  \
        block();                                    \
    } else {                                        \
        dispatch_async(dispatch_get_main_queue(), block); \
    }
#endif

@interface AceXcomponentWeakProxy : NSProxy

@property (nonatomic, weak, readonly) id target;

+ (instancetype)proxyWithTarget:(id)target;

@end

@interface AceXcomponentTextureView : NSObject

@property (nonatomic, strong, readonly) AceTexture *renderTexture;

- (instancetype)initWithId:(int64_t)textureId
                instanceId:(int32_t)instanceId
                callback:(IAceOnResourceEvent)callback
                param:(NSDictionary *)initParam
                superTarget:(UIViewController *)target
                viewdelegate:(NSObject<AcePlatformViewDelegate> *)viewdelegate
                surfaceDelegate:(id<IAceSurface>)surfaceDelegate;

- (NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *)getCallMethod;
- (void)releaseObject;

@end

NS_ASSUME_NONNULL_END

#endif // FOUNDATION_ADAPTER_CAPABILITY_TEXTURE_ACEXCOMPONENTTEXTUREVIEW_H