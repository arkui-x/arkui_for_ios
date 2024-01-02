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

#import "BridgePluginManager.h"

#import "BridgePluginManager+internal.h"

@implementation BridgePluginManager
+ (instancetype)bridgePluginManager:(int32_t)instanceId {
    return [self innerBridgePluginManager:instanceId];
}

+ (void)unbridgePluginManager:(int32_t)instanceId {
    return [self innerUnbridgePluginManager:instanceId];
}

- (BOOL)registerBridgePlugin:(NSString*)bridgeName
                    bridgePlugin:(id)bridgePlugin {
    return [self innerRegisterBridgePlugin:bridgeName bridgePlugin:bridgePlugin];
}

- (BOOL)unRegisterBridgePlugin:(NSString*)bridgeName {
    return [self innerUnRegisterBridgePlugin:bridgeName];
}

- (void)dealloc {
    NSLog(@"BridgePluginManager dealloc");
}

@end
