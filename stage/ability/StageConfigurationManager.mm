/*
 * Copyright (c) 2023-2025 Huawei Device Co., Ltd.
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

#import <UIKit/UIKit.h>
#import <UIKit/UITraitCollection.h>
#import <sys/utsname.h>
#import "StageConfigurationManager.h"

#include <string>
#include <app_main.h>

#include "capability_registry.h"

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
#define SYSTEM_LANGUAGE @"ohos.system.language"
#define SYSTEM_FONT_SIZE_SCALE @"system.font.size.scale"
#define PPI_326 326
#define PPI_401 401
#define PPI_458 458
#define PPI_460 460
#define PPI_476 476
using AppMain = OHOS::AbilityRuntime::Platform::AppMain;
@interface StageConfigurationManager () <UITraitEnvironment>

@property (nonatomic, strong) NSMutableDictionary *configuration;

@end

@implementation StageConfigurationManager

+ (instancetype)configurationManager {
    static StageConfigurationManager *_configurationManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"StageConfigurationManager share instance");
        _configurationManager = [[StageConfigurationManager alloc] init];
        NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
        [center addObserver:_configurationManager
                   selector:@selector(onfontSizeScale:)
                       name:UIContentSizeCategoryDidChangeNotification
                     object:nil];
    });
    return _configurationManager;
}

- (void)registConfiguration {
    NSLog(@"initConfiguration called");
    UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
    [self setDirection:currentOrientation];
    UIUserInterfaceIdiom deviceType = [UIDevice currentDevice].userInterfaceIdiom;
    [self setDeviceType:deviceType];
    if (@available(iOS 13.0, *)) {
        UITraitCollection *trait = [UITraitCollection currentTraitCollection];
        [self setColorMode:trait.userInterfaceStyle];
    } else {
        [self setColorMode:UIUserInterfaceStyleLight];
    }
    [self setDensitydpi];
    [self setLanguage:[self getCurrentLanguage]];
    [self setfontSizeScale:[self getCurrentFontScale]];
    std::string json = [self getJsonString:self.configuration];

    if (json.empty()) {
        AppMain::GetInstance()->InitConfiguration(EMPTY_JSON);
    }
    AppMain::GetInstance()->InitConfiguration(json);
    OHOS::Ace::Platform::CapabilityRegistry::Register();
}

- (void)directionUpdate:(UIInterfaceOrientation)direction {
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

- (void)fontSizeScaleUpdate:(CGFloat)fontSizeScale {
    NSLog(@"fontSizeScaleUpdate called");
    [self setfontSizeScale:fontSizeScale];
    std::string json = [self getJsonString:self.configuration];
    if (json.empty()) {
        AppMain::GetInstance()->OnConfigurationUpdate(EMPTY_JSON);
    }
    else {
        AppMain::GetInstance()->OnConfigurationUpdate(json);
    }
}

- (void)setDirection:(UIInterfaceOrientation)direction {
    NSLog(@"setDirection, %d", direction);
    switch (direction) {
        case UIInterfaceOrientationPortrait:
            [self.configuration setObject:DIRECTION_VERTICAL forKey:APPLICATION_DIRECTION];
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            [self.configuration setObject:DIRECTION_VERTICAL forKey:APPLICATION_DIRECTION];
            break;
        case UIInterfaceOrientationLandscapeRight:
            [self.configuration setObject:DIRECTION_HORIZONTAL forKey:APPLICATION_DIRECTION];
            break;
        case UIInterfaceOrientationLandscapeLeft:
            [self.configuration setObject:DIRECTION_HORIZONTAL forKey:APPLICATION_DIRECTION];
            break;
        case UIInterfaceOrientationUnknown:
            [self.configuration setObject:UNKNOWN forKey:APPLICATION_DIRECTION];
            break;
        default:
            break;
    }
}

- (void)setLanguage:(NSString*)language {
    [self.configuration setObject:language forKey:SYSTEM_LANGUAGE];
}

- (void)setfontSizeScale:(CGFloat)fontScale {
    [self.configuration setObject:[NSString stringWithFormat:@"%.2f", fontScale] forKey:SYSTEM_FONT_SIZE_SCALE];
}

- (NSString*)getCurrentLanguage {
    NSString* preferredLanguage = [[NSLocale preferredLanguages] firstObject];
    return preferredLanguage;
}

- (CGFloat)getCurrentFontScale {
    UIFontTextStyle textStyle = UIFontTextStyleBody;
    UIFont* font = [UIFont preferredFontForTextStyle:textStyle];
    UIFontMetrics* fontMetrics = [UIFontMetrics metricsForTextStyle:textStyle];
    if (font.pointSize > 0) {
        CGFloat scaleFactor = [fontMetrics scaledValueForValue:font.pointSize] / font.pointSize;
        return scaleFactor;
    } else {
        return 1.0;
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

- (void)onfontSizeScale:(NSNotification *)notification {
    [self fontSizeScaleUpdate:[self getCurrentFontScale]];
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

- (void)setDensitydpi {
    NSInteger densityDpi = [self getCurrentDensityDpi];
    if (densityDpi != 0) {
        [self.configuration setObject:[NSString stringWithFormat:@"%ld", densityDpi] forKey:APPLICATION_DENSITY];
    }
}

- (NSInteger )getCurrentDensityDpi {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString* deviceString = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    NSDictionary* devicePpi = @{
        @"iPhone5,1": @PPI_326,
        @"iPhone5,2": @PPI_326,
        @"iPhone5,3": @PPI_326,
        @"iPhone5,4": @PPI_326,
        @"iPhone6,1": @PPI_326,
        @"iPhone6,2": @PPI_326,
        @"iPhone7,1": @PPI_401,
        @"iPhone7,2": @PPI_326,
        @"iPhone8,1": @PPI_326,
        @"iPhone8,2": @PPI_401,
        @"iPhone8,4": @PPI_326,
        @"iPhone9,1": @PPI_326,
        @"iPhone9,2": @PPI_401,
        @"iPhone9,3": @PPI_326,
        @"iPhone9,4": @PPI_401,
        @"iPhone10,1": @PPI_326,
        @"iPhone10,2": @PPI_401,
        @"iPhone10,3": @PPI_458,
        @"iPhone10,4": @PPI_326,
        @"iPhone10,5": @PPI_401,
        @"iPhone10,6": @PPI_458,
        @"iPhone11,8": @PPI_326,
        @"iPhone11,2": @PPI_458,
        @"iPhone11,6": @PPI_458,
        @"iPhone11,4": @PPI_458,
        @"iPhone12,1": @PPI_326,
        @"iPhone12,3": @PPI_458,
        @"iPhone12,5": @PPI_458,
        @"iPhone12,8": @PPI_326,
        @"iPhone13,1": @PPI_476,
        @"iPhone13,2": @PPI_460,
        @"iPhone13,3": @PPI_460,
        @"iPhone13,4": @PPI_460,
        @"iPhone14,2": @PPI_460,
        @"iPhone14,3": @PPI_460,
        @"iPhone14,4": @PPI_476,
        @"iPhone14,5": @PPI_460,
        @"iPhone14,6": @PPI_326,
        @"iPhone14,7": @PPI_460,
        @"iPhone14,8": @PPI_460,
        @"iPhone15,2": @PPI_460,
        @"iPhone15,3": @PPI_460,
        @"iPhone15,4": @PPI_460,
        @"iPhone15,5": @PPI_460,
        @"iPhone16,1": @PPI_460,
        @"iPhone16,2": @PPI_460,
        @"iPhone17,3": @PPI_460,
        @"iPhone17,4": @PPI_460,
        @"iPhone17,1": @PPI_460,
        @"iPhone17,2": @PPI_460,
    };
    NSNumber *ppi = devicePpi[deviceString];
    return ppi ? [ppi integerValue] : 0;
}

#pragma mark - lazy load
- (NSMutableDictionary *)configuration {
    if (!_configuration) {
        _configuration = [[NSMutableDictionary alloc] init];
    }
    return _configuration;
}
@end