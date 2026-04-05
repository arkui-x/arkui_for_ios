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

#import "adapter/ios/capability/vibrator/iOSHapticVibrator.h"

#import "adapter/ios/capability/vibrator/iOSAudioHapticPlayer.h"

@interface iOSHapticVibrator ()
@property (nonatomic, strong) iOSAudioHapticPlayer* audioHapticPlayer;
@end

@implementation iOSHapticVibrator

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    static iOSHapticVibrator* instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [iOSHapticVibrator new];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _audioHapticPlayer = [[iOSAudioHapticPlayer alloc] init];
        [_audioHapticPlayer prepare];
    }
    return self;
}

- (void)dealloc
{
    [_audioHapticPlayer releaseResources];
}

- (void)startVibrator:(NSString *)effectId
{
    if (effectId != nil && effectId.length != 0) {
        [self.audioHapticPlayer startVibratorWithEffectId:effectId];
    }
}

@end
