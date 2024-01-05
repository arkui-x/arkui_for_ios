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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_APPLICATION_H
#define FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_APPLICATION_H

#import <Foundation/Foundation.h>
#import "StageViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface StageApplication : NSObject

+ (void)configModuleWithBundleDirectory:(NSString *_Nonnull)bundleDirectory;

+ (void)launchApplication;

+ (void)callCurrentAbilityOnForeground;

+ (void)callCurrentAbilityOnBackground;

+ (BOOL)handleSingleton:(NSString *)bundleName moduleName:(NSString *)moduleName abilityName:(NSString *)abilityName;

+ (void)releaseViewControllers;

+ (StageViewController *)getApplicationTopViewController;

+ (void)setLocaleWithLanguage:(NSString *)language country:(NSString *)country script:(NSString *)script;

- (NSString *)getTopAbility;

- (void)doAbilityForeground:(NSString *)fullname;

- (void)doAbilityBackground:(NSString *)fullname;

- (void)print:(NSString *)msg;

- (void)printSync:(NSString *)msg;

- (int)finishTest;

@end

NS_ASSUME_NONNULL_END
#endif // FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_APPLICATION_H