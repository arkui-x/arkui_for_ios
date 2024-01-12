/**
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
#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_PLUGINLIFECYCLE_PLUGINCONTEXT_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_PLUGINLIFECYCLE_PLUGINCONTEXT_H

#import <Foundation/Foundation.h>

#import "BridgePluginManager.h"

/**
 * Plugin Context.
 *
 * provides the resources that the plugin might need.
 *
 * @since 11
 */
@interface PluginContext : NSObject 

 /**
 * Constructor of PluginContext.
 *
 * @param bridgePluginManager bridgePluginManager of the stageViewController.
 * @since 11
 */
- (instancetype)initPluginContext:(BridgePluginManager *)bridgePluginManager moduleName:(NSString *)moduleName;

/**
 * get BridgePluginManager of the stageViewController.
 *
 * @since 11
 */
- (BridgePluginManager *)getBridgePluginManager;

/**
 * get absolute path of rawfile.
 * 
 * @param name name of hsp.
 * @param filePath relative path of rawfile.
 * @return absolute path of rawfile.
 * @since 11
 */
- (NSString *)getRawFilePath:(NSString *)name filePath:(NSString *)filePath;

/**
 * get absolute path of rawfile.
 * 
 * @param filePath relative path of rawfile.
 * @return absolute path of rawfile.
 * @since 11
 */
- (NSString *)getRawFilePath:(NSString *)filePath;

@end

#endif // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_PLUGINLIFECYCLE_PLUGINCONTEXT_H
