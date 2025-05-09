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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_CONFIGURATION_MANAGER_H
#define FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_CONFIGURATION_MANAGER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIInterface.h>
#import <UIKit/UIDevice.h>
#import <UIKit/UIScreen.h>

NS_ASSUME_NONNULL_BEGIN

@interface StageConfigurationManager : NSObject

+ (instancetype)configurationManager;

- (void)setDirection:(UIInterfaceOrientation)direction;

- (void)directionUpdate:(UIInterfaceOrientation)direction;

- (void)setColorMode:(UIUserInterfaceStyle)colorMode;

- (void)colorModeUpdate:(UIUserInterfaceStyle)colorMode;

- (void)setDeviceType:(UIUserInterfaceIdiom)deviceType;

- (void)registConfiguration;
@end

NS_ASSUME_NONNULL_END
#endif // FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_CONFIGURATION_MANAGER_H