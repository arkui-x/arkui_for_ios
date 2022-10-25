/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
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

#import "iOSVibratorManager.h"

#import <AudioToolbox/AudioToolbox.h>

@implementation iOSVibratorManager

+ (instancetype)shareintance{
    static dispatch_once_t onceToken;
    static iOSVibratorManager *instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [iOSVibratorManager new];
    });
    return instance;
}

- (void)addVibrateSingle{
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

- (void)addVibrate:(NSInteger)duration{
   self.duration = duration;
   AudioServicesAddSystemSoundCompletion(kSystemSoundID_Vibrate, NULL, NULL, vibrateCallback, NULL);
   AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

void vibrateCallback(SystemSoundID sound,void * clientData) {
  AudioServicesPlaySystemSound(kSystemSoundID_Vibrate); //震动
  [[iOSVibratorManager shareintance] removeSoundID_Vibrate];
}

- (void)removeSoundID_Vibrate{
   [self performSelector:@selector(stopVibrate) withObject:nil afterDelay:self.duration];
}

- (void)stopVibrate {
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopVibrateSound) object:nil];
  AudioServicesRemoveSystemSoundCompletion(kSystemSoundID_Vibrate);
}

@end
