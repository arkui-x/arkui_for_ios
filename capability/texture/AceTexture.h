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
#ifndef FOUNDATION_ADAPTER_CAPABILITY_TEXTURE_ACETEXTURE_H
#define FOUNDATION_ADAPTER_CAPABILITY_TEXTURE_ACETEXTURE_H

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import "IAceOnCallResourceMethod.h"
#import "IAceOnResourceEvent.h"

NS_ASSUME_NONNULL_BEGIN

@interface AceTexture : NSObject
@property (nonatomic, strong) AVPlayerItemVideoOutput *videoOutput;
- (instancetype)initWithEvents:(IAceOnResourceEvent)callback
    textureId:(int64_t)textureId abilityInstanceId:(int32_t)abilityInstanceId;
- (NSDictionary<NSString*, IAceOnCallSyncResourceMethod>*)getCallMethod;
- (void)refreshPixelBuffer;
- (void)releaseObject;
@end

NS_ASSUME_NONNULL_END

#endif // FOUNDATION_ADAPTER_CAPABILITY_TEXTURE_ACETEXTURE_H