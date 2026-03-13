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

#import "ArkUIXPluginRegistry.h"
#import "PluginContext.h"
#include "base/log/log.h"

@interface ArkUIXPluginRegistry () {
    PluginContext *_pluginContext;
}

@property (nonatomic, strong) NSMutableDictionary<NSString*, id<IArkUIXPlugin>> *pluginDictionary;
@end

@implementation ArkUIXPluginRegistry

- (instancetype)initArkUIXPluginRegistry:(PluginContext *)pluginContext {
    self = [super init];
    if (self) {
        _pluginContext = pluginContext;
    }
    return self;
}

- (void)registryPlugin:(NSString *)name {
    LOGI("ArkUIXPluginRegistry registry plugin: %{public}s", [name UTF8String]);
    Class PluginClass = NSClassFromString(name);
    if (PluginClass == Nil) {
        LOGE("ArkUIXPluginRegistry pluginClass do not found");
        return;
    } 
    id<IArkUIXPlugin> plugin = (id<IArkUIXPlugin>)[[PluginClass alloc] init];
    if (plugin == nil) {
        LOGE("ArkUIXPluginRegistry plugin do not exist");
    } else if (![plugin conformsToProtocol:@protocol(IArkUIXPlugin)]) {
        LOGE("ArkUIXPluginRegistry plugin not follow IArkUIXPlugin Protocal");
    } else {
        if ([self hasPlugin:name]) {
            LOGI("ArkUIXPluginRegistry plugin: %{public}s already registered", [name UTF8String]);
        } else {
            LOGI("ArkUIXPluginRegistry plugin: %{public}s is successfully registered", [name UTF8String]);
            @synchronized (self) {
                [self.pluginDictionary setObject:plugin forKey:name];
            }
            [plugin onRegistry:_pluginContext];
        }
    }
}

- (void)registryPlugins:(NSArray *)pluginList {
    for (NSString *pluginName in pluginList) {
        [self registryPlugin:pluginName];
    }
}

- (void)unRegistryPlugin:(NSString *)name {
    id<IArkUIXPlugin> plugin = self.pluginDictionary[name];
    if (plugin != nil) {
        LOGI("ArkUIXPluginRegistry unRegistry Plugin %{public}s", [name UTF8String]);
        [plugin onUnRegistry:_pluginContext];
        @synchronized (self) {
            [self.pluginDictionary removeObjectForKey:name];
        }
    }
}

- (void)unRegistryPlugins:(NSArray *)pluginList {
    for (NSString *pluginName in pluginList) {
        [self unRegistryPlugin:pluginName];
    }
}

- (void)unRegistryAllPlugins {
    for (NSString *pluginName in self.pluginDictionary.allKeys) {
        [self unRegistryPlugin:pluginName];
    }
    @synchronized (self) {
        [self.pluginDictionary removeAllObjects];
    }
}

- (Boolean)hasPlugin:(NSString *)name {
    return [self.pluginDictionary.allKeys containsObject:name];
}

- (id<IArkUIXPlugin>)getPlugin:(NSString *)name {
    if ([self hasPlugin:name]) {
        return self.pluginDictionary[name];
    }
    LOGE("ArkUIXPluginRegistry get plugin: %{public}s failed!", [name UTF8String]);
    return nil;
}

#pragma mark --private

- (NSMutableDictionary *)pluginDictionary {
    if (!_pluginDictionary) {
        _pluginDictionary = [[NSMutableDictionary alloc] init];
    }
    return _pluginDictionary;
}

- (void)dealloc {
    LOGI("ArkUIXPluginRegistry dealloc");
}
@end