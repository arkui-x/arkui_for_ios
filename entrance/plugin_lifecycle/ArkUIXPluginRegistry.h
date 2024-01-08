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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_PLUGINLIFECYCLE_ARKUIXPLUGINREGISTRY_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_PLUGINLIFECYCLE_ARKUIXPLUGINREGISTRY_H

#import <Foundation/Foundation.h>

#import "IPluginRegistry.h"

@interface ArkUIXPluginRegistry : NSObject <IPluginRegistry>

- (instancetype)initArkUIXPluginRegistry:(PluginContext *)pluginContext;

/**
 * add a ArkUI-X plugin to ArkUI-X PluginRegistry.
 *
 * @param name name the full class name of the plugin.
 */
- (void)registryPlugin:(NSString *)name;

/**
 * add ArkUI-X plugins to ArkUI-X PluginRegistry.
 *
 * @param pluginList A set of ArkUI-X plugins that need to be added.
 */
- (void)registryPlugins:(NSArray *)pluginList;

/**
 * remove a ArkUI-X plugin from ArkUI-X PluginRegistry.
 *
 * @param name name the full class name of the plugin.
 */
- (void)unRegistryPlugin:(NSString *)name;

/**
 * remove ArkUI-X plugins to ArkUI-X PluginRegistry.
 *
 * @param pluginList A set of ArkUI-X plugins that need to be removed.
 */
- (void)unRegistryPlugins:(NSArray *)pluginList;

/**
 * remove all plugins ArkUI-X from PluginRegistry.
 */
- (void)unRegistryAllPlugins;

/**
 * Check whether a ArkUI-X plugin has been added to ArkUI-X PluginRegistry.
 *
 * @param name the full class name of the plugin.
 * @return return true if the plugin has been added to ArkUI-X PluginRegistry.
 */
- (Boolean)hasPlugin:(NSString *)name;

/**
 * get a ArkUI-X plugin instance that has been added to ArkUI-X PluginRegistry.
 *
 * @param name the full class name of the plugin.
 * @return return plugin if the plugin has been added to ArkUI-X PluginRegistry.
 */
- (id<IArkUIXPlugin>)getPlugin:(NSString *)name;

@end

#endif // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_PLUGINLIFECYCLE_ARKUIXPLUGINREGISTRY_H