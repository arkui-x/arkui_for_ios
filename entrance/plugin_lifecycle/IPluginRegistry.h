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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_PLUGINLIFECYCLE_IPLUGINREGISTRY_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_PLUGINLIFECYCLE_IPLUGINREGISTRY_H

#import <Foundation/Foundation.h>

#import "IArkUIXPlugin.h"

/**
 * Plugin Registry.
 *
 * Interface to be implemented by Plugin Registry.
 */
@protocol IPluginRegistry <NSObject>
@required

/**
 * add a plugin to PluginRegistry.
 *
 * @param name name the full class name of the plugin.
 */
- (void)registryPlugin:(NSString *)name;

/**
 * add plugins to PluginRegistry.
 *
 * @param pluginList A set of plugins that need to be added.
 */
- (void)registryPlugins:(NSArray *)pluginList;

/**
 * remove a plugin from PluginRegistry.
 *
 * @param name name the full class name of the plugin.
 */
- (void)unRegistryPlugin:(NSString *)name;

/**
 * remove plugins to PluginRegistry.
 *
 * @param pluginList A set of plugins that need to be removed.
 */
- (void)unRegistryPlugins:(NSArray *)pluginList;

/**
 * remove all plugins from PluginRegistry.
 */
- (void)unRegistryAllPlugins;

/**
 * Check whether a plugin has been added to PluginRegistry.
 *
 * @param name the full class name of the plugin.
 * @return return true if the plugin has been added to PluginRegistry.
 */
- (Boolean)hasPlugin:(NSString *)name;

/**
 * get a plugin instance that has been added to PluginRegistry.
 *
 * @param name the full class name of the plugin.
 * @return return pluing if the plugin has been added to PluginRegistry.
 */
- (id<IArkUIXPlugin>)getPlugin:(NSString *)name;

@end

#endif // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_PLUGINLIFECYCLE_IPLUGINREGISTRY_H