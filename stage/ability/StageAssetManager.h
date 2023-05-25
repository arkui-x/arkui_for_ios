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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_ASSET_MANAGER_H
#define FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_ASSET_MANAGER_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface StageAssetManager : NSObject

+ (instancetype)assetManager;

- (void)moduleFilesWithbundleDirectory:(NSString *_Nonnull)bundleDirectory;

- (void)launchAbility;

- (NSString *_Nullable)getBundlePath;

- (NSArray *_Nullable)getAssetAllFilePathList;

- (NSArray *_Nullable)getModuleJsonFileList;

- (NSString *_Nullable)getAbilityStageABCWithModuleName:(NSString *)moduleName
                                             modulePath:(NSString **)modulePath
                                             esmodule:(BOOL)esmodule;

- (void)getModuleResourcesWithModuleName:(NSString *)moduleName
                         appResIndexPath:(NSString **)appResIndexPath
                         sysResIndexPath:(NSString **)sysResIndexPath;

- (NSString *_Nullable)getModuleAbilityABCWithModuleName:(NSString *)moduleName
                                             abilityName:(NSString *)abilityName
                                              modulePath:(NSString **)modulePath
                                              esmodule:(BOOL)esmodule;

@end

NS_ASSUME_NONNULL_END

#endif // FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_ASSET_MANAGER_H