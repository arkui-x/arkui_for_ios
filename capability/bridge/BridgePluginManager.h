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

#import "BridgePlugin.h"
#import "ResultValue.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BridgePluginManager : NSObject

+ (instancetype)shareManager;

- (BOOL)registerBridgePlugin:(NSString*)bridgeName
                bridgePlugin:(BridgePlugin*)bridgePlugin;

- (void)UnRegisterBridgePluginWithInstanceId:(int32_t)instanceId;

- (void)UnRegisterBridgePlugin:(NSString*)name;

- (void)jsCallMethod:(NSString*)bridgeName
          methodName:(NSString*)methodName
               param:(NSString*)param;

- (void)jsSendMethodResult:(NSString*)bridgeName
                methodName:(NSString*)methodName
                    result:(id)result;

- (void)jsSendMessage:(NSString*)bridgeName
                 data:(id)data;

- (void)jsSendMessageResponse:(NSString*)bridgeName
                         data:(NSString*)data;

- (void)jsCancelMethod:(NSString*)bridgeName
            methodName:(NSString*)methodName;

- (ResultValue*)platformCallMethod:(NSString*)bridgeName
                        methodName:(NSString*)methodName
                             param:(NSArray* _Nullable)params
                        instanceId:(int32_t)instanceId;

- (void)platformSendMessage:(NSString*)bridgeName
                       data:(id)data
                 instanceId:(int32_t)instanceId;

- (void)platformSendMessageResponse:(NSString*)bridgeName
                               data:(NSString*)data
                         instanceId:(int32_t)instanceId;

- (void)platformSendMethodResult:(NSString*)bridgeName
                      methodName:(NSString*)methodName
                          result:(NSString*)result
                      instanceId:(int32_t)instanceId;

- (void)platformSendMessageResponseErrorInfo:(NSString*)bridgeName errorCode:(ErrorCode)errorCode;

- (void)platformWillTerminate;

- (void)jsSendMessageBinary:(NSString*)bridgeName
                       data:(id)data;

- (void)jsCallMethodBinary:(NSString*)bridgeName
                methodName:(NSString*)methodName
                     param:(NSData*)data;

- (void)platformSendMethodResultBinary:(NSString*)bridgeName
                            methodName:(NSString*)methodName
                             errorCode:(int)errorCode
                          errorMessage:(NSString*)errorMessage
                                result:(id)result
                            instanceId:(int32_t)instanceId;

- (void)platformSendMessageBinary:(NSString*)bridgeName
                             data:(id)data
                       instanceId:(int32_t)instanceId;

- (ResultValue*)platformCallMethodBinary:(NSString*)bridgeName
                              methodName:(NSString*)methodName
                                   param:(NSArray* _Nullable)params
                              instanceId:(int32_t)instanceId;

- (void)jsSendMethodResultBinary:(NSString*)bridgeName
                      methodName:(NSString*)methodName
                       errorCode:(int)errorCode
                    errorMessage:(NSString*)errorMessage
                          result:(id)result;
@end

NS_ASSUME_NONNULL_END

#endif // FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_BridgePluginMANAGER_H