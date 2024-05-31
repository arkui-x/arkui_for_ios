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

#import <Foundation/Foundation.h>

#import "BridgePluginManager.h"
#import "MethodData.h"
#import "ResultValue.h"
#import "TaskOption.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * When using the 'callMethod:' method of BrigdePlugin, 
 * implement the 'IMethodResult' delegate to listen for returned results and error messages
 * 
 * @since 10
 */
@protocol IMethodResult <NSObject>

/*
 * The iOS platform calls the method registered by Arkui, and after a successful call,
 * this method will be called, returning the name and value of the calling method
 * 
 * @param methodName  method name.
 * @param resultValue method resultValue.
 * @since 10
 */
- (void)onSuccess:(NSString*)methodName
        resultValue:(id)resultValue;

/**
 * The iOS platform calls a method registered with Arkui, but if the call fails,
 * it will call and return the method name, error code, and error log.
 * The error code is checked in the 'ResultValue' class
 * 
 * @param methodName  method name.
 * @param errorCode errorCode. success : 0
 * @param errorMessage errorMessage.
 * @since 10
 */
- (void)onError:(NSString*)methodName
        errorCode:(ErrorCode)errorCode
        errorMessage:(NSString*)errorMessage;

/**
 * Call other platform method successfully and return trigger.
 *
 * @param methodName  method name.
 * @since 10
 */
- (void)onMethodCancel:(NSString*)methodName;

@end

/**
 * Using the sendMessage method of BrigdePlugin,
 * implement this delegate to listen to the information sent by Arkui calling the sendmessage method and
 * obtain the data returned by Arkui
 * 
 * @since 10
 */
@protocol IMessageListener <NSObject>

/**
 * This method can listen to the data passed by Arkui calling the 'sendMessage' method
 * 
 * @return object.
 * @param data data.
 * @since 10
 */
- (id)onMessage:(id)data;

/**
 * The iOS platform calls sendmessage to pass information to Arkui,
 * and through this method, the return value of Arkui can be returned
 *
 * @param data data.
 * @since 10
 */
- (void)onMessageResponse:(id)data;

@end

/**
 * Encoding type of Bridge.
 * JSON_ TYPE is JSON string format, JSON_ TYPE is Default type
 * BINARY_TYPE is Unit_8 format
 * 
 * @since 11
 */
typedef enum : int {
    JSON_TYPE,
    BINARY_TYPE,
} BridgeType;

@interface BridgePlugin : NSObject

/**
 * The bridge name.
 * 
 * @since 10
 */
@property(nonatomic, strong, readonly) NSString* bridgeName;

/**
 * The bridgeManager.
 * 
 * @since 10
 */
@property(nonatomic, strong, readonly) BridgePluginManager* bridgeManager;

/**
 * Callmethod result delegate
 * 
 * @since 10
 */
@property(nonatomic, assign) id<IMethodResult> methodResult;

/**
 * SendMessage listerner delegate
 * 
 * @since 10
 */
@property(nonatomic, assign) id<IMessageListener> messageListener;

/**
 * @since 10
 * @deprecated since 11
 */
@property(nonatomic, assign, readonly) int32_t instanceId;

/**
 * The current encoding format data format, default is JSON_TYPE
 * 
 * @since 10
 */
@property(nonatomic, assign, readonly) BridgeType type;

/**
 * The type of current queue task
 * 
 * @since 11
 */
@property(nonatomic, strong, readonly) TaskOption* taskOption;

/**
 * Initializes this BridgePlugin. 
 * This API is supported since API version 10 and deprecated since API version 11.
 * You are advised to use BridgePluginManager related construction methods
 * 
 * @param bridgeName  bridgeName.
 * @param instanceId instanceId.
 * @since 10
 * @deprecated since 11
 */
- (instancetype)initBridgePlugin:(NSString* _Nonnull)bridgeName
                    instanceId:(int32_t)instanceId DEPRECATED_MSG_ATTRIBUTE("This API deprecated since API version 11."
                    "Use initBridgePlugin: bridgeManager: instead.");

/**
 * Initializes this BridgePlugin.
 * Obtain the BridgePluginManager object through the 'getBridgeManager' of StageViewController
 * 
 * @param bridgeName  bridgeName.
 * @param bridgeManager bridgeManager.
 * @since 11
 */
- (instancetype)initBridgePlugin:(NSString* _Nonnull)bridgeName
                    bridgeManager:(BridgePluginManager*)bridgeManager;

/**
 * Initializes this BridgePlugin.
 * Obtain the BridgePluginManager object through the 'getBridgeManager' of StageViewController
 *
 * @param bridgeName  bridgeName.
 * @param bridgeManager bridgeManager.
 * @param type type.
 * @since 11
 */
- (instancetype)initBridgePlugin:(NSString* _Nonnull)bridgeName
                    bridgeManager:(BridgePluginManager*)bridgeManager
                    bridgeType:(BridgeType)type;

/**
 * Initializes this BridgePlugin.
 * Obtain the BridgePluginManager object through the 'getBridgeManager' of StageViewController
 * 
 * @param bridgeName  bridgeName.
 * @param bridgeManager bridgeManager.
 * @param type type.
 * @param taskOption taskOption.
 * @since 11
 */
- (instancetype)initBridgePlugin:(NSString* _Nonnull)bridgeName
                    bridgeManager:(BridgePluginManager*)bridgeManager
                    bridgeType:(BridgeType)type
                    taskOption:(TaskOption*)taskOption;
/**
 * The iOS platform calls the method registered by Arkui,
 * use 'methodResult' deleate, Listening to call results.
 *
 * @param method  methodData model.
 * @since 10
 */
- (void)callMethod:(MethodData*)method;

/**
 * sendMessage to arkui.
 * use 'messageListener' deleate, Listening to call results.
 * 
 * @param data  data.
 * @since 10
 */
- (void)sendMessage:(id)data;

/**
 * Check if BridgePlugin is available.
 *
 * @return The isAvailable of BridgePlugin.
 * @since 11
 */
- (BOOL)isBridgeAvailable;

/**
 * Unregister the created bridge
 *
 * @param bridgeName Name of bridge.
 * @return Success or not.
 * @since 10
 */
- (BOOL)unRegister:(NSString*)bridgeName;

@end

NS_ASSUME_NONNULL_END

#endif // FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_BRIDGEPLUGIN_H