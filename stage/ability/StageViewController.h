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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_STAGEVIEWCONTROLLER_H
#define FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_STAGEVIEWCONTROLLER_H

#import <UIKit/UIKit.h>

@interface StageViewController : UIViewController

@property (nonatomic, readonly) NSString *instanceName;
@property (nonatomic, assign) BOOL statusBarHidden;

@property (nonatomic, strong) NSString *params;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil NS_UNAVAILABLE;

/**
 * Initializes this StageViewController with the specified instance name.
 *
 *  instanceName(bundleName:moduleName:abilityName)
 *  This is used for pure stage application. It will combine the instanceName as the
 *  abilityDirectory.
 *
 * @param instanceName instance name.
 * @since 10
 */
- (instancetype)initWithInstanceName:(NSString *_Nonnull)instanceName;

/**
 * Get the BridgeManager of StageViewController.
 * @return The BridgeManager.
 */
- (id)getBridgeManager;

/**
 * Get the Id of StageViewController.
 * @return The InstanceId.
 * @since 10
 * @deprecated since 11
 */
- (int32_t)getInstanceId;

/**
 * processBackPress.
 * @return if uicontent handle return true ,otherwise return false.
 * @since 11
 */
- (BOOL)processBackPress;

/**
 * add ArkUI-X plugin to list for registry.
 * @param pluginName the full class name of the plugin.
 * @since 11
 */
- (void)addPlugin:(NSString *)pluginName;

@end
#endif // FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_STAGEVIEWCONTROLLER_H
