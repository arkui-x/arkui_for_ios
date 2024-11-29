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

#import <UIKit/UITraitCollection.h>
#import <UIKit/UIKit.h>
#import "StageConfigurationManager.h"

#include <string>
#include <app_main.h>

#define APPLICATION_DIRECTION @"ohos.application.direction"
#define COLOR_MODE_LIGHT @"light"
#define COLOR_MODE_DARK @"dark"
#define DIRECTION_VERTICAL @"vertical"
#define DIRECTION_HORIZONTAL @"horizontal"
#define EMPTY_JSON ""
#define UNKNOWN @""
#define SYSTEM_COLORMODE @"ohos.system.colorMode"
#define APPLICATION_DENSITY @"ohos.application.densitydpi"
#define DEVICE_TYPE @"const.build.characteristics"
#define DEVICE_TYPE_PHONE @"Phone"
#define DEVICE_TYPE_TABLET @"Tablet"
using AppMain = OHOS::AbilityRuntime::Platform::AppMain;
@interface StageConfigurationManager () <UITraitEnvironment>

@property (nonatomic, strong) NSMutableDictionary *configuration;
@property (nonatomic, assign) UIInterfaceOrientation lastInterfaceOrientation;
@end

@implementation StageConfigurationManager

+ (instancetype)configurationManager {
    static StageConfigurationManager *_configurationManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"StageConfigurationManager share instance");
        _configurationManager = [[StageConfigurationManager alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:_configurationManager
                                                 selector:@selector(onDeviceOrientationChange:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
    });
    return _configurationManager;
}

- (void)registConfiguration {
    NSLog(@"initConfiguration called");
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    self.lastInterfaceOrientation = (UIInterfaceOrientation)[UIApplication sharedApplication].statusBarOrientation;
    NSLog(@"registConfiguration called, self.lastInterfaceOrientation: %d", self.lastInterfaceOrientation);
    [self setDirection:orientation];
    UIUserInterfaceIdiom deviceType = [UIDevice currentDevice].userInterfaceIdiom;
    [self setDeviceType:deviceType];
    if (@available(iOS 13.0, *)) {
        UITraitCollection *trait = [UITraitCollection currentTraitCollection];
        [self setColorMode:trait.userInterfaceStyle];
    } else {
        [self setColorMode:UIUserInterfaceStyleLight];
    }
    [self updateDensitydpi];
    std::string json = [self getJsonString:self.configuration];
    
    if (json.empty()) {
        AppMain::GetInstance()->InitConfiguration(EMPTY_JSON);
    }
    AppMain::GetInstance()->InitConfiguration(json);
}

- (void)directionUpdate:(UIDeviceOrientation)direction {
    NSLog(@"directionUpdate called");
    [self setDirection:direction];
    std::string json = [self getJsonString:self.configuration];
    if (json.empty()) {
        AppMain::GetInstance()->OnConfigurationUpdate(EMPTY_JSON);
    }
    AppMain::GetInstance()->OnConfigurationUpdate(json);
}

- (void)colorModeUpdate:(UIUserInterfaceStyle)colorMode {
    NSLog(@"colorModeUpdate called");
    [self setColorMode:colorMode];
    std::string json = [self getJsonString:self.configuration];
    if (json.empty()) {
        AppMain::GetInstance()->OnConfigurationUpdate(EMPTY_JSON);
    }
    AppMain::GetInstance()->OnConfigurationUpdate(json);
}

- (void)setDirection:(UIDeviceOrientation)direction {
    NSLog(@"setDirection, %d", direction);
    switch (direction) {
        case UIDeviceOrientationPortrait: {
            [self.configuration setObject:DIRECTION_VERTICAL forKey:APPLICATION_DIRECTION];
        }
        break;
        case UIDeviceOrientationPortraitUpsideDown: {
            [self.configuration setObject:DIRECTION_VERTICAL forKey:APPLICATION_DIRECTION];
        }
        break;
        case UIDeviceOrientationLandscapeRight: {
            [self.configuration setObject:DIRECTION_HORIZONTAL forKey:APPLICATION_DIRECTION];
        }
        break;
        case UIDeviceOrientationLandscapeLeft: {
            [self.configuration setObject:DIRECTION_HORIZONTAL forKey:APPLICATION_DIRECTION];
        }
        break;
        case UIDeviceOrientationUnknown: {
            [self.configuration setObject:UNKNOWN forKey:APPLICATION_DIRECTION];
        }
        break;
        default:
        break;
    }
}

- (void)setColorMode:(UIUserInterfaceStyle)colorMode {
    switch (colorMode) {
        case UIUserInterfaceStyleLight: {
            [self.configuration setObject:COLOR_MODE_LIGHT forKey:SYSTEM_COLORMODE];
        }
        break;
        case UIUserInterfaceStyleDark: {
            [self.configuration setObject:COLOR_MODE_DARK forKey:SYSTEM_COLORMODE];
        }
        break;
        default: {
            [self.configuration setObject:UNKNOWN forKey:APPLICATION_DIRECTION];
        }
        break;
    }
}

- (void)setDeviceType:(UIUserInterfaceIdiom)deviceType {
    switch (deviceType) {
        case UIUserInterfaceIdiomPhone: {
            [self.configuration setObject:DEVICE_TYPE_PHONE forKey:DEVICE_TYPE];
        }
        break;
        case UIUserInterfaceIdiomPad: {
            [self.configuration setObject:DEVICE_TYPE_TABLET forKey:DEVICE_TYPE];
        }
        break;
    }
}

- (void)updateDensitydpi {
    CGFloat screenScale = [UIScreen mainScreen].scale;
    if (screenScale != 0) {
         [self.configuration setObject:[NSString stringWithFormat:@"%f",screenScale] forKey:APPLICATION_DENSITY];
    }
}

- (BOOL)checkInterfaceOrientationMask {
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    UIInterfaceOrientation interfaceOrientation = [self interfaceOrientationFromDeviceOrientation:orientation];
    if (interfaceOrientation == UIInterfaceOrientationUnknown) {
        return false;
    }
    id ad = [UIApplication sharedApplication].delegate;
    if ([ad respondsToSelector:@selector(application:supportedInterfaceOrientationsForWindow:)]) {
        UIInterfaceOrientationMask mask = [ad application:[UIApplication sharedApplication] supportedInterfaceOrientationsForWindow:nil];
        NSLog(@"supportedInterfaceOrientationsForWindow mask: %d", mask);
        return (mask & (1 << interfaceOrientation)) != 0;
    } else {
        NSArray *supportedOrientations = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UISupportedInterfaceOrientations"];
        return [self isInterfaceOrientation:interfaceOrientation supportedInArray:supportedOrientations];
    }
    return true;
}

- (BOOL)isInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation supportedInArray:(NSArray *)supportedOrientationsArray {
    NSString *interfaceOrientationString;
    switch (interfaceOrientation) {
        case UIInterfaceOrientationPortrait:
            interfaceOrientationString = @"UIInterfaceOrientationPortrait";
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            interfaceOrientationString = @"UIInterfaceOrientationPortraitUpsideDown";
            break;
        case UIInterfaceOrientationLandscapeLeft:
            interfaceOrientationString = @"UIInterfaceOrientationLandscapeLeft";
            break;
        case UIInterfaceOrientationLandscapeRight:
            interfaceOrientationString = @"UIInterfaceOrientationLandscapeRight";
            break;
        default:
            return NO;
    }
    return [supportedOrientationsArray containsObject:interfaceOrientationString];
}

- (UIInterfaceOrientation)interfaceOrientationFromDeviceOrientation:(UIDeviceOrientation)deviceOrientation {
    switch (deviceOrientation) {
        case UIDeviceOrientationPortrait:
            return UIInterfaceOrientationPortrait;
        case UIDeviceOrientationPortraitUpsideDown:
            return UIInterfaceOrientationPortraitUpsideDown;
        case UIDeviceOrientationLandscapeLeft:
            return UIInterfaceOrientationLandscapeLeft;
        case UIDeviceOrientationLandscapeRight:
            return UIInterfaceOrientationLandscapeRight;
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        {
            UIInterfaceOrientation currentInterfaceOrientation = (UIInterfaceOrientation)[UIApplication sharedApplication].statusBarOrientation;
            NSLog(@"interfaceOrientationFromDeviceOrientation statusBarOrientation: %d", currentInterfaceOrientation);
            if (currentInterfaceOrientation == UIInterfaceOrientationPortrait || currentInterfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
                currentInterfaceOrientation == UIInterfaceOrientationLandscapeRight) {
                return currentInterfaceOrientation;
            }
        }
        default:
            return UIInterfaceOrientationUnknown;
    }
}

- (void)onDeviceOrientationChange:(NSNotification *)notification {
    if ([self checkInterfaceOrientationMask]) {
        UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
        UIInterfaceOrientation tempOrientation = (UIInterfaceOrientation)[UIApplication sharedApplication].statusBarOrientation;
        if (self.lastInterfaceOrientation != tempOrientation) {
            NSLog(@"onDeviceOrientationChange, call directionUpdate, lastInterfaceOrientation: %d, curInterfaceOrientation: %d",
                self.lastInterfaceOrientation, tempOrientation);
            self.lastInterfaceOrientation = tempOrientation;
            [self directionUpdate:orientation];
            return;
        }
    }
    NSLog(@"onDeviceOrientationChange, not call directionUpdate.");
}

- (std::string)getJsonString:(id)object {
    if (!object) {
        return EMPTY_JSON;
    }
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:object
                                                       options:kNilOptions
                                                         error:&parseError];
    if (parseError) {
        NSLog(@"parsing failed, code: %ld, message: %@", (long)parseError.code, parseError.userInfo);
        return EMPTY_JSON;
    }
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return [jsonString UTF8String];
}

#pragma mark - lazy load
- (NSMutableDictionary *)configuration {
    if (!_configuration) {
        _configuration = [[NSMutableDictionary alloc] init];
    }
    return _configuration;
}
@end