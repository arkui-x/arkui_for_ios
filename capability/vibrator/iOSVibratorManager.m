//
//  iOSVibratorManager.m
//  sources
//
//  Created by vail 王军平 on 2022/3/17.
//

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

-(void)addVibrateSingle{
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

-(void)addVibrate:(NSInteger)duration{
   self.duration = duration;
   AudioServicesAddSystemSoundCompletion(kSystemSoundID_Vibrate, NULL, NULL, vibrateCallback, NULL);
   AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

void vibrateCallback(SystemSoundID sound,void * clientData) {
  AudioServicesPlaySystemSound(kSystemSoundID_Vibrate); //震动
  [[iOSVibratorManager shareintance] removeSoundID_Vibrate];
}

-(void)removeSoundID_Vibrate{
   [self performSelector:@selector(stopVibrate) withObject:nil afterDelay:self.duration];
}

-(void)stopVibrate {
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopVibrateSound) object:nil];
  AudioServicesRemoveSystemSoundCompletion(kSystemSoundID_Vibrate);
}

@end
