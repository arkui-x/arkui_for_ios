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

#import "adapter/ios/capability/vibrator/iOSAudioHapticPlayer.h"

#import <AudioToolbox/AudioToolbox.h>
#import <CoreHaptics/CoreHaptics.h>
#import <UIKit/UIKit.h>

#include "base/log/log.h"

namespace {
constexpr int32_t slideDurationMs = 10;
constexpr int32_t longPressDurationMs = 80;
constexpr int32_t dragDurationMs = 3;
constexpr NSTimeInterval millisecondsPerSecond = 1000.0;

NSURL* ToFileUrl(NSString* path)
{
    if (path == nil || path.length == 0) {
        return nil;
    }
    if ([path hasPrefix:@"file://"]) {
        return [NSURL URLWithString:path];
    }
    return [NSURL fileURLWithPath:path];
}
} // namespace

@interface iOSAudioHapticPlayer ()
@property (nonatomic, strong) UIImpactFeedbackGenerator* impactLightGenerator;
@property (nonatomic, strong) UIImpactFeedbackGenerator* impactMediumGenerator;
@property (nonatomic, strong) UISelectionFeedbackGenerator* selectionGenerator;
@property (nonatomic, copy, nullable) NSURL* effectiveUri;
@property (nonatomic, copy, nullable) NSString* effectId;
@property (nonatomic, assign) float intensity;
@property (atomic, strong, nullable) CHHapticEngine* hapticEngine;
@property (atomic, assign) BOOL isSupportsCoreHaptics;
@property (atomic, assign) BOOL isHapticEngineRunning;
@property (nonatomic, assign) dispatch_queue_t hapticsQueue;
@property (nonatomic, assign) SystemSoundID soundId;
@end

@implementation iOSAudioHapticPlayer

- (instancetype)init
{
    self = [super init];
    if (self) {
        _isSupportsCoreHaptics = [CHHapticEngine.capabilitiesForHardware supportsHaptics];
        _hapticsQueue = dispatch_queue_create("com.arkuix.audiohaptic.queue", DISPATCH_QUEUE_SERIAL);
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(appDidEnterBackground:)
            name:UIApplicationDidEnterBackgroundNotification
            object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(appWillEnterForeground:)
            name:UIApplicationWillEnterForegroundNotification
            object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self releaseResources];
}

- (void)appWillEnterForeground:(NSNotification*)notification
{
    [self startHapticEngine];
}

- (void)appDidEnterBackground:(NSNotification*)notification
{
    [self stopHapticEngine];
}

- (void)initializeFeedbackGenerators
{
    if (!@available(iOS 13.0, *) || !self.isSupportsCoreHaptics) {
        _impactLightGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        _impactMediumGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        _selectionGenerator = [[UISelectionFeedbackGenerator alloc] init];

        [_impactLightGenerator prepare];
        [_impactMediumGenerator prepare];
        [_selectionGenerator prepare];
    }
}

- (void)initializeHapticEngine
{
    if (!@available(iOS 13.0, *)) {
        return;
    }
    if (self.hapticEngine) {
        if (!self.isHapticEngineRunning) {
            [self startHapticEngine];
        }
        return;
    }

    NSError* error = nil;
    self.hapticEngine = [[CHHapticEngine alloc] initAndReturnError:&error];
    if (error != nil || self.hapticEngine == nil) {
        self.hapticEngine = nil;
        return;
    }

    __weak __typeof(self) weakSelf = self;
    self.hapticEngine.playsHapticsOnly = YES;
    self.hapticEngine.resetHandler = ^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        [strongSelf startHapticEngine];
    };

    [self startHapticEngine];
}

- (void)initializeSound
{
    if (self.effectiveUri == nil || !self.effectiveUri.isFileURL) {
        return;
    }
    NSString* filePath = self.effectiveUri.path;
    if (filePath.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        return;
    }

    SystemSoundID newSoundId = 0;
    OSStatus status = AudioServicesCreateSystemSoundID((__bridge CFURLRef)self.effectiveUri, &newSoundId);
    if (status != kAudioServicesNoError || newSoundId == 0) {
        return;
    }

    self.soundId = newSoundId;
}

- (void)releaseSound
{
    if (self.soundId != 0) {
        AudioServicesDisposeSystemSoundID(self.soundId);
        self.soundId = 0;
    }
}

- (void)registerSourceWithEffectId:(NSString*)effectiveUri effectId:(NSString*)effectId
{
    self.effectiveUri = ToFileUrl(effectiveUri);
    self.effectId = effectId;
}

- (void)setHapticIntensity:(float)intensity
{
    _intensity = intensity;
}

- (void)prepare
{
    [self initializeHapticEngine];
    [self initializeFeedbackGenerators];
    [self initializeSound];
}

- (void)startHapticEngine
{
    if (!@available(iOS 13.0, *)) {
        return;
    }
    if (self.hapticEngine == nil || self.isHapticEngineRunning) {
        return;
    }
    NSError* error = nil;
    [self.hapticEngine startAndReturnError:&error];

    if (error) {
        LOGE("Error starting haptic engine: %{public}s", error.localizedDescription.UTF8String);
    } else {
        self.isHapticEngineRunning = YES;
    }
}

- (void)stopHapticEngine
{
    if (!@available(iOS 13.0, *)) {
        return;
    }
    if (self.hapticEngine == nil || !self.isHapticEngineRunning) {
        return;
    }
    [self.hapticEngine stopWithCompletionHandler:^(NSError* error) {
        if (error) {
            LOGE("Error stopping haptic engine: %{public}s", error.localizedDescription.UTF8String);
        } else {
            self.isHapticEngineRunning = NO;
        }
    }];
}

- (void)startLightGenerator
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.impactLightGenerator impactOccurred];
        [self.impactLightGenerator prepare];
    });
}

- (void)startMediumGenerator
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.impactMediumGenerator impactOccurred];
        [self.impactMediumGenerator prepare];
    });
}

- (void)startSelectionGenerator
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.selectionGenerator selectionChanged];
        [self.selectionGenerator prepare];
    });
}

- (void)startVibratorWithEffectId:(NSString *)effectId
{
    if ([effectId isEqualToString:@"haptic.slide"]) {
        if (@available(iOS 13.0, *) && self.isSupportsCoreHaptics) {
            [self startVibratorWithParams:1.0f durationMs:slideDurationMs];
        } else {
            [self startLightGenerator];
        }
    } else if ([effectId isEqualToString:@"haptic.long_press_light"] ||
        [effectId isEqualToString:@"haptic.long_press_medium"]) {
        if (@available(iOS 13.0, *) && self.isSupportsCoreHaptics) {
            [self startVibratorWithParams:1.0f durationMs:longPressDurationMs];
        } else {
            [self startMediumGenerator];
        }
    } else if ([effectId isEqualToString:@"haptic.drag"]) {
        if (@available(iOS 13.0, *) && self.isSupportsCoreHaptics) {
            [self startVibratorWithParams:1.0f durationMs:dragDurationMs];
        } else {
            [self startSelectionGenerator];
        }
    }
}

- (void)startVibratorWithParams:(float)intensity durationMs:(int32_t)durationMs
{
    if (durationMs <= 0) {
        return;
    }
    if (@available(iOS 13.0, *) && self.isSupportsCoreHaptics) {
        const NSTimeInterval durationS = (NSTimeInterval)durationMs / millisecondsPerSecond;
        dispatch_async(self.hapticsQueue, ^{
            if (self.hapticEngine == nil || !self.isHapticEngineRunning) {
                return;
            }
            NSError* error = nil;
            CHHapticEventParameter* intensityParam = [[CHHapticEventParameter alloc]
                initWithParameterID:CHHapticEventParameterIDHapticIntensity value:intensity];
            CHHapticEvent* event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous
                parameters:@[ intensityParam ]
                relativeTime:0
                duration:durationS];

            CHHapticPattern* pattern = [[CHHapticPattern alloc] initWithEvents:@[ event ] parameters:@[] error:&error];
            if (error || !pattern) {
                return;
            }
            id<CHHapticPatternPlayer> player = [self.hapticEngine createPlayerWithPattern:pattern error:&error];
            if (error != nil || player == nil) {
                return;
            }

            [player startAtTime:0 error:&error];
        });
    }
}

- (void)start
{
    if ([self.effectId isEqualToString:@"haptic.slide"]) {
        if (@available(iOS 13.0, *) && self.isSupportsCoreHaptics) {
            [self startVibratorWithParams:self.intensity durationMs:slideDurationMs];
        } else {
            [self startLightGenerator];
        }
    }

    dispatch_async(self.hapticsQueue, ^{
        if (self.soundId != 0) {
            AudioServicesPlaySystemSound(self.soundId);
        }
    });
}

- (void)releaseResources
{
    [self releaseSound];
    [self stopHapticEngine];
    self.hapticEngine = nil;
    self.effectiveUri = nil;
    self.effectId = nil;
    self.intensity = 0.0f;
}

@end
