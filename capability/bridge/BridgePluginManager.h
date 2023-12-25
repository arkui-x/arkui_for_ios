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

#ifndef FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_BridgePluginMANAGER_H
#define FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_BridgePluginMANAGER_H

#import <Foundation/Foundation.h>
#import "ResultValue.h"

NS_ASSUME_NONNULL_BEGIN

@interface BridgePluginManager : NSObject

/**
 * Bridge plugin manager.
 * @param instanceId the id of instance.
 *
 * @return Bridge plugin manager.
 */
+ (instancetype)bridgePluginManager:(int32_t)instanceId;

/**
 * Unregister the created bridge
 *
 * @param instanceId the id of instance.
 * @return Success or fail.
 */
+ (void)unbridgePluginManager:(int32_t)instanceId;

/**
 * Register Bridge plugin
 *
 * @param bridgeName Name of bridge.
 * @param bridgePlugin bridgePlugin object.
 * @return Success or fail.
 */
- (BOOL)registerBridgePlugin:(NSString*)bridgeName
                    bridgePlugin:(id)bridgePlugin;

/**
 * Unregister the created bridge
 *
 * @param bridgeName name of bridge.
 * @return Success or fail.
 */
- (BOOL)unRegisterBridgePlugin:(NSString*)bridgeName;
@end

NS_ASSUME_NONNULL_END

#endif // FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_BridgePluginMANAGER_H