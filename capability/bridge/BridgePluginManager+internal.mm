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

#import "BridgePluginManager+internal.h"
#import "BridgeBinaryCodec.h"
#import "BridgeCodecUtil.h"
#import "BridgeJsonCodec.h"
#import "BridgePlugin.h"
#import "BridgePlugin+jsMessage.h"
#import "BridgeManagerHolder.h"
#import <Foundation/Foundation.h>

#include "adapter/ios/capability/bridge/bridge_manager.h"
#include "adapter/ios/capability/bridge/buffer_mapping.h"
#include "base/log/log.h"
#include "core/common/ace_engine.h"
#include "core/common/container.h"
#include "core/common/flutter/flutter_task_executor.h"

#import <objc/runtime.h>

@interface BridgePluginManager () 
@property (nonatomic, assign) BOOL willTerminate;
@property (nonatomic, assign) int32_t pluginInstanceId;
@property (nonatomic, strong) NSMutableDictionary<NSString*, BridgePlugin*>* bridgeMap;
@end

@implementation BridgePluginManager (internal)

const std::vector<uint8_t> ConvertToVector(NSData* data) {
    const uint8_t* bytes = (const uint8_t*)data.bytes;
    return std::vector<uint8_t>(bytes, bytes + data.length);
}

static std::unique_ptr<OHOS::Ace::Platform::BufferMapping> NSDataToBufferMapping(NSData* nsData) {
    if (nsData == nil) {
        return std::make_unique<OHOS::Ace::Platform::BufferMapping>
                (OHOS::Ace::Platform::BufferMapping::Copy(nullptr, 0));
    }
    uint8_t* dataBytes = (uint8_t*)[nsData bytes];
    size_t dataSize = [nsData length];
    return std::make_unique<OHOS::Ace::Platform::BufferMapping>
                (OHOS::Ace::Platform::BufferMapping::Copy(dataBytes, dataSize));
}

+ (instancetype)bridgePluginManager:(int32_t)instanceId {
    return [[BridgePluginManager alloc] initBridgePluginManager:instanceId];
}

+ (void)unbridgePluginManager:(int32_t)instanceId {
    [BridgeManagerHolder removeBridgeManagerWithId:instanceId];
}


- (instancetype)initBridgePluginManager:(int32_t)instanceId {
    self = [super self];
    if (self) {
        [BridgeManagerHolder addBridgeManager:self inceId:instanceId];
        self.pluginInstanceId = instanceId;
        self.bridgeMap = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - public set get
static char kWillTerminateKey;
static char kPluginInstanceIdKey;
static char kBridgeMapKey;

- (void)setWillTerminate:(BOOL)willTerminate {
    objc_setAssociatedObject(self, &kWillTerminateKey, @(willTerminate), OBJC_ASSOCIATION_ASSIGN);
}

- (BOOL)willTerminate {
    NSNumber *value = objc_getAssociatedObject(self, &kWillTerminateKey);
    return [value boolValue];
}

- (void)setPluginInstanceId:(int32_t)pluginInstanceId {
    objc_setAssociatedObject(self, &kPluginInstanceIdKey, @(pluginInstanceId), OBJC_ASSOCIATION_ASSIGN);
}

- (int32_t)pluginInstanceId {
    NSNumber *value = objc_getAssociatedObject(self, &kPluginInstanceIdKey);
    return [value intValue];
}

- (void)setBridgeMap:(NSMutableDictionary<NSString *,BridgePlugin *> *)bridgeMap {
    objc_setAssociatedObject(self, &kBridgeMapKey, bridgeMap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary<NSString *,BridgePlugin *> *)bridgeMap {
    return objc_getAssociatedObject(self, &kBridgeMapKey);
}

#pragma mark - public method

- (BOOL)registerBridgePlugin:(NSString*)bridgeName
                bridgePlugin:(BridgePlugin*)bridgePlugin {
    if (!bridgeName.length || !bridgePlugin) {
        NSLog(@"register failed, bridgename : %@, plugin : %@", bridgeName, bridgePlugin);
        return NO;
    }
    @synchronized(self) {
        if ([self.bridgeMap.allKeys containsObject:bridgeName]) {
            NSLog(@"register failed, bridgePlugin exist");
            return NO;
        }
        [self.bridgeMap setObject:bridgePlugin
                            forKey:bridgeName];
    }
    return YES;
}

- (BOOL)unRegisterBridgePlugin:(NSString*)bridgeName {
    if (!bridgeName.length) {
        return false;
    }
    @synchronized(self) {
        [self.bridgeMap removeObjectForKey:bridgeName];
    }
    return true;
}

- (void)jsCallMethod:(NSString*)bridgeName
        methodName:(NSString*)methodName
            param:(NSString*)param {
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        [self platformSendMethodResultErrorInfo:bridgeName methodName:methodName errorCode:BRIDGE_INVALID];
        return;
    }
    if (bridgePlugin.type != JSON_TYPE) {
        [self platformSendMethodResultErrorInfo:bridgeName methodName:methodName errorCode:BRIDGE_CODEC_TYPE_MISMATCH];
        return;
    }

    NSMutableArray* mArray = [NSMutableArray array];
    if (param) {
        id methodParam = [JsonHelper objectWithJSONString:param];
        if (methodParam && [methodParam isKindOfClass:NSDictionary.class]) {
            NSDictionary* methodDic = (NSDictionary*)methodParam;
            for (int i = 0; i < methodDic.allKeys.count; i++) {
                id argument = [methodDic objectForKey:[NSString stringWithFormat:@"%d", i]];
                [mArray addObject:argument];
            }
        }
    }
    MethodData* methodData = [[MethodData alloc] initMethodWithName:methodName parameter:mArray.copy];
    [bridgePlugin jsCallMethod:methodData];
}

- (void)jsSendMethodResult:(NSString*)bridgeName
                methodName:(NSString*)methodName
                    result:(id)result {
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        [self platformSendMethodResultErrorInfo:bridgeName methodName:methodName errorCode:BRIDGE_INVALID];
        return;
    }
    if (bridgePlugin.type != JSON_TYPE) {
        [self platformSendMethodResultErrorInfo:bridgeName methodName:methodName errorCode:BRIDGE_CODEC_TYPE_MISMATCH];
        return;
    }

    RawValue* rawValue = [[BridgeJsonCodec sharedInstance] decode:result];
    ResultValue* resultValue = [[ResultValue alloc] init];
    resultValue.result = rawValue.result ?: @"";
    resultValue.errorCode = (ErrorCode)rawValue.errorCode;
    resultValue.errorMessage = rawValue.errorMessage ?: @"";
    resultValue.methodName = methodName;
    [bridgePlugin jsSendMethodResult:resultValue];
}

- (void)jsSendMessage:(NSString*)bridgeName
                 data:(id)data {
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        [self platformSendMessageResponseErrorInfo:bridgeName errorCode:BRIDGE_NAME_ERROR];
        return;
    }
    if (bridgePlugin.type != JSON_TYPE) {
        [self platformSendMessageResponseErrorInfo:bridgeName errorCode:BRIDGE_CODEC_TYPE_MISMATCH];
        return;
    }

    [bridgePlugin jsSendMessage:data];
}

- (void)jsSendMessageResponse:(NSString*)bridgeName
                        data:(NSString*)data {
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        return;
    }
    RawValue* rawValue = [[BridgeJsonCodec sharedInstance] decode:data];
    [bridgePlugin jsSendMessageResponse:rawValue.result];
}

- (void)jsCancelMethod:(NSString*)bridgeName
            methodName:(NSString*)methodName {
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        return;
    }
    [bridgePlugin jsCancelMethod:bridgeName methodName:methodName];
}

- (ResultValue*)platformCallMethod:(NSString*)bridgeName
                        methodName:(NSString*)methodName
                            param:(NSArray* _Nullable)params {
    ResultValue* resultValue = [[ResultValue alloc] init];
    if (!bridgeName.length || !methodName.length) {
        resultValue.errorCode = BRIDGE_NAME_ERROR;
        resultValue.errorMessage = BRIDGE_NAME_ERROR_MESSAGE;
        return resultValue;
    }

    if (!methodName.length) {
        resultValue.errorCode = BRIDGE_METHOD_NAME_ERROR;
        resultValue.errorMessage = BRIDGE_METHOD_NAME_ERROR_MESSAGE;
        return resultValue;
    }

    NSString* jsonString = nil;
    if (params.count > 0) {
        NSMutableDictionary* mDic = [NSMutableDictionary dictionary];
        for (int i = 0; i < params.count; i++) {
            [mDic setObject:params[i] forKey:[NSString stringWithFormat:@"%d", i]];
        }
        jsonString = [JsonHelper jsonStringWithObject:mDic.copy];
    }

    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_methodName = [methodName UTF8String];
    std::string c_param = [jsonString.length ? jsonString : @"" UTF8String];
    int32_t instanceId = self.pluginInstanceId;

    OHOS::Ace::ContainerScope scope(instanceId);
    auto taskExecutor = OHOS::Ace::Container::CurrentTaskExecutor();
    if (!taskExecutor) {
        NSLog(@"null taskExecutor");
        resultValue.errorCode = BRIDGE_BOTTOM_COMMUNICATION_ERROR;
        resultValue.errorMessage = BRIDGE_BOTTOM_COMMUNICATION_ERROR_MESSAGE;
        return resultValue;
    }
    auto task = [c_bridgeName, c_methodName, c_param, instanceId] {
        OHOS::Ace::Platform::BridgeManager::PlatformCallMethod(instanceId, c_bridgeName, c_methodName, c_param);
    };

    taskExecutor->PostTask(task, OHOS::Ace::TaskExecutor::TaskType::JS);
    return nil;
}

- (void)platformSendMessage:(NSString*)bridgeName
                        data:(id)data {
    if (!bridgeName.length) {
        return;
    }
    RawValue* rawValue = [RawValue rawValueResult:data errorCode:0];
    NSString* string = [[BridgeJsonCodec sharedInstance] encode:rawValue];

    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_data = [string UTF8String];
    int32_t instanceId = self.pluginInstanceId;

    OHOS::Ace::ContainerScope scope(instanceId);
    auto taskExecutor = OHOS::Ace::Container::CurrentTaskExecutor();
    if (!taskExecutor) {
        NSLog(@"null taskExecutor");
        return;
    }
    auto task = [c_bridgeName, c_data, instanceId] {
        OHOS::Ace::Platform::BridgeManager::PlatformSendMessage(instanceId, c_bridgeName, c_data);
    };

    taskExecutor->PostTask(task, OHOS::Ace::TaskExecutor::TaskType::JS);
}

- (void)platformSendMessageResponse:(NSString*)bridgeName data:(NSString*)data {
    if (!bridgeName.length) {
        return;
    }
    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_data = [data UTF8String];
    int32_t instanceId = self.pluginInstanceId;

    OHOS::Ace::ContainerScope scope(instanceId);
    auto taskExecutor = OHOS::Ace::Container::CurrentTaskExecutor();
    if (!taskExecutor) {
        NSLog(@"null taskExecutor");
        return;
    }
    auto task = [c_bridgeName, c_data, instanceId] {
        OHOS::Ace::Platform::BridgeManager::PlatformSendMessageResponse(instanceId, c_bridgeName, c_data);
    };

    taskExecutor->PostTask(task, OHOS::Ace::TaskExecutor::TaskType::JS);
}

- (void)platformSendMethodResult:(NSString*)bridgeName
                    methodName:(NSString*)methodName
                        result:(NSString*)result {
    if (!bridgeName.length) {
        return;
    }
    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_methodName = [methodName UTF8String];
    std::string c_result = [result UTF8String];
    int32_t instanceId = self.pluginInstanceId;

    OHOS::Ace::ContainerScope scope(instanceId);
    auto taskExecutor = OHOS::Ace::Container::CurrentTaskExecutor();
    if (!taskExecutor) {
        NSLog(@"null taskExecutor");
        return;
    }

    auto task = [c_bridgeName, c_methodName, c_result, instanceId] {
        OHOS::Ace::Platform::BridgeManager::PlatformSendMethodResult(instanceId, c_bridgeName, c_methodName, c_result);
    };

    taskExecutor->PostTask(task, OHOS::Ace::TaskExecutor::TaskType::JS);
}

- (void)platformSendMessageResponseErrorInfo:(NSString*)bridgeName errorCode:(ErrorCode)errorCode {
    RawValue* resultValue = [RawValue rawValueRresult:@"errorCode" errorCode:errorCode errorMessage:@""];
    NSString* jsonString = [[BridgeJsonCodec sharedInstance] encode:resultValue];

    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_data = [jsonString UTF8String];
    int32_t instanceId = self.pluginInstanceId;
    OHOS::Ace::Platform::BridgeManager::PlatformSendMessageResponse(instanceId, c_bridgeName, c_data);
}

- (void)platformSendMethodResultErrorInfo:(NSString*)bridgeName
                methodName:(NSString*)methodName errorCode:(ErrorCode)errorCode {
    RawValue* resultValue = [RawValue resultErrorCode:errorCode errorMessage:ResultValueError(errorCode)];
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    NSString* jsonString = [[BridgeJsonCodec sharedInstance] encode:resultValue];
    [self platformSendMethodResult:bridgeName
                        methodName:methodName
                            result:jsonString];
}

- (void)platformWillTerminate {
    if (self.willTerminate) {
        return;
    }
    self.willTerminate = true;
    OHOS::Ace::Platform::BridgeManager::PlatformSendWillTerminate();
}

- (void)jsSendMessageBinary:(NSString*)bridgeName data:(id)data {
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        [self platformSendMessageResponseErrorInfo:bridgeName errorCode:BRIDGE_NAME_ERROR];
        return;
    }
    if (bridgePlugin.type != BINARY_TYPE) {
        [self platformSendMessageResponseErrorInfo:bridgeName errorCode:BRIDGE_CODEC_TYPE_MISMATCH];
        return;
    }
    id oc_data = [[BridgeBinaryCodec sharedInstance] decode:data];
    [bridgePlugin jsSendMessage:oc_data];
}

- (void)jsCallMethodBinary:(NSString*)bridgeName
                methodName:(NSString*)methodName
                    param:(NSData*)data {
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        [self platformSendMethodResultErrorInfo:bridgeName methodName:methodName errorCode:BRIDGE_INVALID];
        return;
    }
    if (bridgePlugin.type != BINARY_TYPE) {
        NSLog(@"######1231313");
        [self platformSendMethodResultErrorInfo:bridgeName methodName:methodName errorCode:BRIDGE_CODEC_TYPE_MISMATCH];
        return;
    }

    NSArray* oc_parameter;
    if (data && data.length != 0) {
        BridgeCodecType binaryType = (BridgeCodecType)[[BridgeBinaryCodec sharedInstance] getBinaryType:data];
        id decode_data = [[BridgeBinaryCodec sharedInstance] decode:data];
        if (binaryType == T_COMPOSITE_LIST) {
            oc_parameter = decode_data;
        } else if (decode_data) {
            oc_parameter = @[decode_data];
        }
    }

    MethodData* methodData = [[MethodData alloc] initMethodWithName:methodName parameter:oc_parameter.copy];
    [bridgePlugin jsCallMethod:methodData];
}

- (void)platformSendMethodResultBinary:(NSString*)bridgeName
                            methodName:(NSString*)methodName
                            errorCode:(int)errorCode
                            errorMessage:(NSString*)errorMessage
                            result:(id)result {
    if (!bridgeName.length) {
        return;
    }

    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_methodName = [methodName UTF8String];
    NSData* dataResult = [[BridgeBinaryCodec sharedInstance] encode:result];

    std::string c_errorMessage = [errorMessage UTF8String];
    int32_t instanceId = self.pluginInstanceId;

    OHOS::Ace::ContainerScope scope(instanceId);
    auto taskExecutor = OHOS::Ace::Container::CurrentTaskExecutor();
    if (!taskExecutor) {
        NSLog(@"null taskExecutor");
        return;
    }
    auto task = [c_bridgeName, c_methodName, 
        dataResult = std::move(dataResult), errorCode, c_errorMessage, instanceId] {
        auto c_result = NSDataToBufferMapping(dataResult);
        OHOS::Ace::Platform::BridgeManager::PlatformSendMethodResultBinary(instanceId, c_bridgeName,
                c_methodName, errorCode, c_errorMessage, std::move(c_result));
    };

    taskExecutor->PostTask(task, OHOS::Ace::TaskExecutor::TaskType::JS);
}

- (void)platformSendMessageBinary:(NSString*)bridgeName data:(id)data {
    if (!bridgeName.length) {
        return;
    }

    std::string c_bridgeName = [bridgeName UTF8String];
    int32_t instanceId = self.pluginInstanceId;
    NSData* dataResult = [[BridgeBinaryCodec sharedInstance] encode:data];

    OHOS::Ace::ContainerScope scope(instanceId);
    auto taskExecutor = OHOS::Ace::Container::CurrentTaskExecutor();
    if (!taskExecutor) {
        NSLog(@"null taskExecutor");
        return;
    }
    auto task = [c_bridgeName, dataResult = std::move(dataResult), instanceId] {
        auto c_data = NSDataToBufferMapping(dataResult);
        OHOS::Ace::Platform::BridgeManager::PlatformSendMessageBinary(instanceId, c_bridgeName, std::move(c_data));
    };

    taskExecutor->PostTask(task, OHOS::Ace::TaskExecutor::TaskType::JS);
}

- (ResultValue*)platformCallMethodBinary:(NSString*)bridgeName
                            methodName:(NSString*)methodName
                            param:(NSArray* _Nullable)params {
    ResultValue* resultValue = [[ResultValue alloc] init];
    if (!bridgeName.length || !methodName.length) {
        resultValue.errorCode = BRIDGE_NAME_ERROR;
        resultValue.errorMessage = BRIDGE_NAME_ERROR_MESSAGE;
        return resultValue;
    }

    if (!methodName.length) {
        resultValue.errorCode = BRIDGE_METHOD_NAME_ERROR;
        resultValue.errorMessage = BRIDGE_METHOD_NAME_ERROR_MESSAGE;
        return resultValue;
    }

    NSData* dataResult;
    if (params.count == 0) {
        dataResult = nil;
    } else {
        // T_COMPOSITE_LIST
        dataResult = [[BridgeBinaryCodec sharedInstance] encode:params];
    }

    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_methodName = [methodName UTF8String];
    int32_t instanceId = self.pluginInstanceId;

    OHOS::Ace::ContainerScope scope(instanceId);
    auto taskExecutor = OHOS::Ace::Container::CurrentTaskExecutor();
    if (!taskExecutor) {
        NSLog(@"null taskExecutor");
        resultValue.errorCode = BRIDGE_BOTTOM_COMMUNICATION_ERROR;
        resultValue.errorMessage = BRIDGE_BOTTOM_COMMUNICATION_ERROR_MESSAGE;
        return resultValue;
    }

    auto task = [c_bridgeName, c_methodName, dataResult = std::move(dataResult), instanceId] {
        auto c_result = NSDataToBufferMapping(dataResult);
        OHOS::Ace::Platform::BridgeManager::PlatformCallMethodBinary(instanceId, c_bridgeName, c_methodName, std::move(c_result));
    };

    taskExecutor->PostTask(task, OHOS::Ace::TaskExecutor::TaskType::JS);
    return nil;
}

- (void)jsSendMethodResultBinary:(NSString*)bridgeName
                    methodName:(NSString*)methodName
                    errorCode:(int)errorCode
                    errorMessage:(NSString*)errorMessage
                    result:(id)result {
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        return;
    }
    if (bridgePlugin.type != BINARY_TYPE) {
        return;
    }
    id oc_resultValue = [[BridgeBinaryCodec sharedInstance] decode:(NSData*)result];

    ResultValue* resultValue = [[ResultValue alloc] init];
    resultValue.result = oc_resultValue ?: @"";
    resultValue.errorCode = (ErrorCode)errorCode;
    resultValue.errorMessage = errorMessage ?: @"";
    resultValue.methodName = methodName;
    [bridgePlugin jsSendMethodResult:resultValue];
}

#pragma mark - private method
- (BridgePlugin* _Nullable)getPluginWithBridgeName:(NSString*)bridgeName {
    if (!bridgeName.length) {
        NSLog(@"no register bridge, %@", bridgeName);
        return nil;
    }
    @synchronized(self) {
        BridgePlugin* bridgePlugin = (BridgePlugin*)[self.bridgeMap objectForKey:bridgeName];
        return bridgePlugin;
    }
}

@end
