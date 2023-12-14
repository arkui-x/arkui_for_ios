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

#ifndef FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_BRIDGEPLUGIN_H
#define FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_BRIDGEPLUGIN_H

#import "MethodData.h"
#import "ResultValue.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol IMethodResult <NSObject>

/**
 * Method call succeeded callback.
 *
 * @param methodName  method name.
 * @param resultValue method resultValue.
 */
- (void)onSuccess:(NSString*)methodName
      resultValue:(id)resultValue;

/**
 * Method call failed callback.
 *
 * @param methodName  method name.
 * @param errorCode errorCode. success : 0
 * @param errorMessage errorMessage.
 */
- (void)onError:(NSString*)methodName
       errorCode:(ErrorCode)errorCode
    errorMessage:(NSString*)errorMessage;

/**
 * Method cancel callback.
 *
 * @param methodName  method name.
 */
- (void)onMethodCancel:(NSString*)methodName;

@end

@protocol IMessageListener <NSObject>

/**
 * Message callback.
 * @return object.
 * @param data data.
 */
- (id)onMessage:(id)data;

/**
 * Message response callback.
 *
 * @param data data.
 */
- (void)onMessageResponse:(id)data;

@end

typedef enum : int {
    JSON_TYPE,
    BINARY_TYPE,
} BridgeType;

@interface BridgePlugin : NSObject

@property (nonatomic, strong) NSString* bridgeName;

@property (nonatomic, assign) id<IMethodResult> methodResult;       // callmethod result delegate

@property (nonatomic, assign) id<IMessageListener> messageListener; // message listerner delegate

@property (nonatomic, assign) int32_t instanceId;

@property (nonatomic, assign, readonly) BridgeType type; // default JSON_TYPE

/**
 * Initializes this BridgePlugin.
 *
 * @param bridgeName  bridgeName.
 * @param instanceId instanceId.
 */
- (instancetype)initBridgePlugin:(NSString* _Nonnull)bridgeName
                      instanceId:(int32_t)instanceId;

/**
 * Initializes this BridgePlugin.
 *
 * @param bridgeName  bridgeName.
 * @param instanceId instanceId.
 * @param type type.
 */
- (instancetype)initBridgePlugin:(NSString* _Nonnull)bridgeName
                      instanceId:(int32_t)instanceId
                      bridgeType:(BridgeType)type;

/**
 * platform callMethod.
 *
 * @param method  methodData model.
 */
- (void)callMethod:(MethodData*)method;

/**
 * sendMessage to js.
 *
 * @param data  data.
 */
- (void)sendMessage:(id)data;

@end

NS_ASSUME_NONNULL_END

#endif // FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_BRIDGEPLUGIN_H