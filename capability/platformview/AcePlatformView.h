/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

#ifndef FOUNDATION_ADAPTER_CAPABILITY_PLATFORMVIEW_ACEPLATFORMVIEW_H
#define FOUNDATION_ADAPTER_CAPABILITY_PLATFORMVIEW_ACEPLATFORMVIEW_H

#include <map>

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "AceTexture.h"
#import "IAceOnCallResourceMethod.h"
#import "IAceOnResourceEvent.h"
#import "IPlatformView.h"
#import "AcePlatformViewDelegate.h"

NS_ASSUME_NONNULL_BEGIN

#ifndef dispatch_main_async_safe
#define dispatch_main_async_safe(block) \
if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(dispatch_get_main_queue())) { \
    block(); \
} else { \
    dispatch_async(dispatch_get_main_queue(), block); \
}
#endif

@interface AcePlatformView : NSObject
@property (nonatomic) CVPixelBufferRef textureOutput;
- (instancetype)initWithEvents:(IAceOnResourceEvent)callback
    id:(int64_t)id abilityInstanceId:(int32_t)abilityInstanceId
    viewdelegate:(NSObject<AcePlatformViewDelegate>*)viewdelegate;
- (NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *)getSyncCallMethod;
- (void)refreshPixelBuffer;
- (void)releaseObject;
- (void)setPlatformView:(NSObject<IPlatformView>*)platformView;
- (UIView*)getPlatformView;
- (void)onActivityResume;
- (void)onActivityPause;

@end

NS_ASSUME_NONNULL_END

#endif // FOUNDATION_ADAPTER_CAPABILITY_PLATFORMVIEW_ACEPLATFORMVIEW_H