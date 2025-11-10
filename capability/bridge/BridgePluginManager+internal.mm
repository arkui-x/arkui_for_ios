/*
 * Copyright (c) 2023-2025 Huawei Device Co., Ltd.
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

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "BridgeBinaryCodec.h"
#import "BridgeCodecUtil.h"
#import "BridgeGCDTaskQueue.h"
#import "BridgeJsonCodec.h"
#import "BridgeManagerHolder.h"
#import "BridgePlugin+internal.h"
#import "BridgePlugin+jsMessage.h"
#import "BridgePlugin.h"
#import "BridgePluginManager+internal.h"
#import "BridgeTaskQueueHandler.h"
#import "ResultValue.h"

#include "adapter/ios/capability/bridge/bridge_manager.h"
#include "adapter/ios/capability/bridge/buffer_mapping.h"
#include "base/log/log.h"
#include "core/common/ace_engine.h"
#include "core/common/container.h"

@interface BridgePluginManager () 
@property (nonatomic, assign) BOOL willTerminate;
@property (nonatomic, strong) NSMutableDictionary<NSString*, BridgePlugin*>* bridgeMap;
@property (nonatomic, strong) NSMutableDictionary<NSString*, BridgeTaskQueueHandler*>* bridgeQueueMap;
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

static NSData* ConvertBufferMappingToNSData(std::unique_ptr<OHOS::Ace::Platform::BufferMapping> result) {
    if (!result) {
        return nil;
    }
    const uint8_t* bytes = result->GetMapping();
    size_t length = result->GetSize();
    return [NSData dataWithBytes:bytes length:length];
}

+ (instancetype)sharedInstance {
    static BridgePluginManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BridgePluginManager alloc] initBridgePluginManager];
    });
    return instance;
}

- (instancetype)initBridgePluginManager {
    self = [super self];
    if (self) {
        self.bridgeMap = [[NSMutableDictionary alloc] init];
        self.bridgeQueueMap = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - public set get
static char kWillTerminateKey;
static char kPluginInstanceIdKey;
static char kBridgeMapKey;
static char kBridgeQueueMapKey;

- (void)setWillTerminate:(BOOL)willTerminate {
    objc_setAssociatedObject(self, &kWillTerminateKey, @(willTerminate), OBJC_ASSOCIATION_ASSIGN);
}

- (BOOL)willTerminate {
    NSNumber* value = objc_getAssociatedObject(self, &kWillTerminateKey);
    return [value boolValue];
}

- (void)setBridgeMap:(NSMutableDictionary<NSString*,BridgePlugin*>*)bridgeMap {
    objc_setAssociatedObject(self, &kBridgeMapKey, bridgeMap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary<NSString*,BridgePlugin*>*)bridgeMap {
    return objc_getAssociatedObject(self, &kBridgeMapKey);
}

- (void)setBridgeQueueMap:(NSMutableDictionary<NSString*,BridgePlugin*>*)bridgeQueueMap {
    objc_setAssociatedObject(self, &kBridgeQueueMapKey, bridgeQueueMap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary<NSString*, BridgeTaskQueueHandler*>*)bridgeQueueMap {
    return objc_getAssociatedObject(self, &kBridgeQueueMapKey);
}

#pragma mark - public method

- (BOOL)innerRegisterBridgePlugin:(NSString*)bridgeName
                bridgePlugin:(BridgePlugin*)bridgePlugin {
    if (!bridgeName.length || !bridgePlugin) {
        NSLog(@"register failed, bridgename : %@, plugin : %@", bridgeName, bridgePlugin);
        return NO;
    }
    if ([self.bridgeMap.allKeys containsObject:bridgeName]) {
        if ([self innerUnRegisterBridgePlugin:bridgeName]) {
             NSLog(@"%@ Duplicate registration, delete previously registered bridge", bridgeName);
        }
    }
    [self.bridgeMap setObject:bridgePlugin forKey:bridgeName];
    std::string c_bridgeName = [bridgeName UTF8String];
    int32_t bridgeType = OHOS::Ace::Platform::BridgeManager::GetBridgeType(c_bridgeName);
    if (OHOS::Ace::Platform::BridgeManager::JSBridgeExists(c_bridgeName) &&
        bridgeType == bridgePlugin.type) {
        [bridgePlugin onRegisterResult:true];
    }
    if (bridgePlugin.taskOption) {
        if (![self.bridgeQueueMap.allKeys containsObject:bridgeName]) {
            BridgeTaskQueueHandler * handler = [[BridgeTaskQueueHandler alloc] init];
            handler.isUseTaskQueue = true;
            handler.isSerial = bridgePlugin.taskOption.isSerial;
            [self.bridgeQueueMap setObject:handler forKey:bridgeName];
        }
    }
    return YES;
}

- (BOOL)innerUnRegisterBridgePlugin:(NSString*)bridgeName {
    if (!bridgeName.length) {
        return false;
    }
    @synchronized(self) {
        [self.bridgeMap removeObjectForKey:bridgeName];
        [self.bridgeQueueMap removeObjectForKey:bridgeName];
    }
    return true;
}

- (void)unRegisterBridgePlugin {
    @synchronized(self) {
        [self.bridgeMap removeAllObjects];
    }
}

- (void)jsCallMethod:(NSString*)bridgeName methodName:(NSString*)methodName param:(NSString*)param {
    __weak BridgePluginManager* weakSelf = self;
    BridgeTaskInfo* taskInfo = [BridgeTaskInfo bridgeTaskInfoFactory:bridgeName
                                        queueInOutType:INPUT handler:^{
        [weakSelf jsCallMethodInner:bridgeName methodName:methodName param:param];
    }];
    [self dispatchTaskInQueueHandlerWithTaskInfo:taskInfo];
}

- (NSString*)jsCallMethodSync:(NSString*)bridgeName methodName:(NSString*)methodName param:(NSString*)param {
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin || bridgePlugin.type != JSON_TYPE) {
        NSNumber* numberErrorCode = [NSNumber numberWithInt:BRIDGE_INVALID];
        NSString* strErrorMessage = BRIDGE_INVALID_MESSAGE;
        NSString* strResult = @"";
        NSDictionary* dict = @{ @"errorCode" : numberErrorCode, @"errorMessage" : strErrorMessage, @"result" : strResult };
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
        NSString* resultJson = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return resultJson;
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
    return [bridgePlugin jsCallMethodSync:methodData];
}

- (void)jsSendMethodResult:(NSString*)bridgeName methodName:(NSString*)methodName result:(id)result {
    __weak BridgePluginManager* weakSelf = self;
    BridgeTaskInfo* taskInfo = [BridgeTaskInfo bridgeTaskInfoFactory:bridgeName
                                        queueInOutType:INPUT handler:^{
        [weakSelf jsSendMethodResultInner:bridgeName methodName:methodName result:result];
    }];
    [self dispatchTaskInQueueHandlerWithTaskInfo:taskInfo];
}

- (void)jsSendMessage:(NSString*)bridgeName data:(id)data {
    __weak BridgePluginManager* weakSelf = self;
    BridgeTaskInfo* taskInfo = [BridgeTaskInfo bridgeTaskInfoFactory:bridgeName
                                        queueInOutType:INPUT handler:^{
        [weakSelf jsSendMessageInner:bridgeName data:data];
    }];
    [self dispatchTaskInQueueHandlerWithTaskInfo:taskInfo];
}

- (void)jsSendMessageResponse:(NSString*)bridgeName data:(NSString*)data {
    __weak BridgePluginManager* weakSelf = self;
    BridgeTaskInfo* taskInfo = [BridgeTaskInfo bridgeTaskInfoFactory:bridgeName
                                        queueInOutType:INPUT handler:^{
        [weakSelf jsSendMessageResponseInner:bridgeName data:data];
    }];
    [self dispatchTaskInQueueHandlerWithTaskInfo:taskInfo];
}

- (void)jsCancelMethod:(NSString*)bridgeName methodName:(NSString*)methodName {
    __weak BridgePluginManager* weakSelf = self;
    BridgeTaskInfo* taskInfo = [BridgeTaskInfo bridgeTaskInfoFactory:bridgeName
                                        queueInOutType:INPUT handler:^{
        [weakSelf jsCancelMethodInner:bridgeName methodName:methodName];
    }];
    [self dispatchTaskInQueueHandlerWithTaskInfo:taskInfo];
}

- (void)jsSendMessageBinary:(NSString*)bridgeName data:(id)data {
    __weak BridgePluginManager* weakSelf = self;
    BridgeTaskInfo* taskInfo = [BridgeTaskInfo bridgeTaskInfoFactory:bridgeName
                                        queueInOutType:INPUT handler:^{
        [weakSelf jsSendMessageBinaryInner:bridgeName data:data];
    }];
    [self dispatchTaskInQueueHandlerWithTaskInfo:taskInfo];
}

- (void)jsCallMethodBinary:(NSString*)bridgeName
                methodName:(NSString*)methodName
                    param:(NSData*)data {
    __weak BridgePluginManager* weakSelf = self;
    BridgeTaskInfo* taskInfo = [BridgeTaskInfo bridgeTaskInfoFactory:bridgeName
                                        queueInOutType:INPUT handler:^{
        [weakSelf jsCallMethodBinaryInner:bridgeName methodName:methodName param:data];
    }];
    [self dispatchTaskInQueueHandlerWithTaskInfo:taskInfo];
}

- (void)jsSendMethodResultBinary:(NSString*)bridgeName
                    methodName:(NSString*)methodName
                    errorCode:(int)errorCode
                    errorMessage:(NSString*)errorMessage
                    result:(id)result {
    __weak BridgePluginManager* weakSelf = self;
    BridgeTaskInfo* taskInfo = [BridgeTaskInfo bridgeTaskInfoFactory:bridgeName
                                        queueInOutType:INPUT handler:^{
        [weakSelf jsSendMethodResultBinaryInner:bridgeName methodName:methodName errorCode:errorCode
                errorMessage:errorMessage result:result];
    }];
    [self dispatchTaskInQueueHandlerWithTaskInfo:taskInfo];                  
}

- (void)platformCallMethod:(NSString*)bridgeName
                        methodName:(NSString*)methodName
                            param:(NSArray* _Nullable)params 
                        reultValueCallback:(void (^)(ResultValue* _Nullable reultValue))callback {
    __weak BridgePluginManager* weakSelf = self;
    [[BridgeGCDTaskQueue sharedInstance] gcdDispatchAsync:(^{
        [weakSelf platformCallMethodInner:bridgeName methodName:methodName param:params reultValueCallback:callback];
    })];
}

- (void)platformSendMessage:(NSString*)bridgeName data:(id)data {
    __weak BridgePluginManager* weakSelf = self;
    [[BridgeGCDTaskQueue sharedInstance] gcdDispatchAsync:(^{
        [weakSelf platformSendMessageInner:bridgeName data:data];
    })];
}

- (void)platformSendMessageResponse:(NSString*)bridgeName data:(id)data {
    __weak BridgePluginManager* weakSelf = self;
    [[BridgeGCDTaskQueue sharedInstance] gcdDispatchAsync:(^{
        [weakSelf platformSendMessageResponseInner:bridgeName data:data];
    })];
}

- (void)platformSendMethodResult:(NSString*)bridgeName methodName:(NSString*)methodName
                    errorCode:(int)errorCode
                    errorMessage:(NSString*)errorMessage
                    result:(id)result {
    __weak BridgePluginManager* weakSelf = self;
    [[BridgeGCDTaskQueue sharedInstance] gcdDispatchAsync:(^{
      RawValue* resultValue = [RawValue rawValueRresult:result
                                           errorCode:errorCode
                                           errorMessage:errorMessage.length ? errorMessage : @""];
      NSString* jsonString = [[BridgeJsonCodec sharedInstance] encode:resultValue];
      [weakSelf platformSendMethodResultInner:bridgeName methodName:methodName result:jsonString];
    })];
}

- (void)platformSendMessageResponseErrorInfo:(NSString*)bridgeName errorCode:(ErrorCode)errorCode {
    RawValue* resultValue = [RawValue rawValueRresult:@"errorCode" errorCode:errorCode errorMessage:@""];
    NSString* jsonString = [[BridgeJsonCodec sharedInstance] encode:resultValue];

    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_data;
    if (jsonString) {
        c_data = [jsonString UTF8String];
    }
    OHOS::Ace::Platform::BridgeManager::PlatformSendMessageResponse(c_bridgeName, c_data);
}

- (void)platformSendMethodResultErrorInfo:(NSString*)bridgeName
                methodName:(NSString*)methodName errorCode:(ErrorCode)errorCode {
    RawValue* resultValue = [RawValue resultErrorCode:errorCode errorMessage:ResultValueError(errorCode)];
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    NSString* jsonString = [[BridgeJsonCodec sharedInstance] encode:resultValue];
    [self platformSendMethodResultInner:bridgeName methodName:methodName result:jsonString];
}

- (void)platformWillTerminate {
    if (self.willTerminate) {
        return;
    }
    self.willTerminate = true;
    OHOS::Ace::Platform::BridgeManager::PlatformSendWillTerminate();
}

- (void)platformSendMethodResultBinary:(NSString*)bridgeName
                            methodName:(NSString*)methodName
                            errorCode:(int)errorCode
                            errorMessage:(NSString*)errorMessage
                                result:(id)result {
    __weak BridgePluginManager* weakSelf = self;
    [[BridgeGCDTaskQueue sharedInstance] gcdDispatchAsync:(^{
        [weakSelf platformSendMethodResultBinaryInner:bridgeName methodName:methodName
                                errorCode:errorCode
                                errorMessage:errorMessage
                                result:result];
    })];
}

- (void)platformSendMessageBinary:(NSString*)bridgeName
                            data:(id)data {
    __weak BridgePluginManager* weakSelf = self;
    [[BridgeGCDTaskQueue sharedInstance] gcdDispatchAsync:(^{
        [weakSelf platformSendMessageBinaryInner:bridgeName data:data];
    })];
}

- (void)platformCallMethodBinary:(NSString*)bridgeName
                                methodName:(NSString*)methodName
                                param:(NSArray* _Nullable)params
                            reultValueCallback:(void (^)(ResultValue* _Nullable reultValue))callback {
    __weak BridgePluginManager* weakSelf = self;
    [[BridgeGCDTaskQueue sharedInstance] gcdDispatchAsync:(^{
        [weakSelf platformCallMethodBinaryInner:bridgeName methodName:methodName param:params reultValueCallback:callback];
    })];
}

#pragma mark - private method
- (void)jsCallMethodInner:(NSString*)bridgeName methodName:(NSString*)methodName param:(NSString*)param {
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        [self platformSendMethodResultErrorInfo:bridgeName methodName:methodName errorCode:BRIDGE_INVALID];
        return;
    }
    if (bridgePlugin.type != JSON_TYPE) {
        [self platformSendMethodResultErrorInfo:bridgeName methodName:methodName
                                                    errorCode:BRIDGE_CODEC_TYPE_MISMATCH];
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
    MethodData* methodData = [[MethodData alloc] initMethodWithName:methodName
                                                    parameter:mArray.copy];
    [bridgePlugin jsCallMethod:methodData];
}

- (void)jsSendMethodResultInner:(NSString*)bridgeName methodName:(NSString*)methodName result:(id)result {
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        [self platformSendMethodResultErrorInfo:bridgeName methodName:methodName errorCode:BRIDGE_INVALID];
        return;
    }
    if (bridgePlugin.type != JSON_TYPE) {
        [self platformSendMethodResultErrorInfo:bridgeName methodName:methodName 
                                                        errorCode:BRIDGE_CODEC_TYPE_MISMATCH];
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

- (void)jsSendMessageInner:(NSString*)bridgeName data:(id)data {
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        [self platformSendMessageResponseErrorInfo:bridgeName errorCode:BRIDGE_NAME_ERROR];
        return;
    }
    if (bridgePlugin.type != JSON_TYPE) {
        [self platformSendMessageResponseErrorInfo:bridgeName errorCode:BRIDGE_CODEC_TYPE_MISMATCH];
        return;
    }

    RawValue* rawValue = [[BridgeJsonCodec sharedInstance] decode:data];
    [bridgePlugin jsSendMessage:rawValue.result];
}

- (void)jsSendMessageResponseInner:(NSString*)bridgeName data:(NSString*)data {
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        return;
    }
    RawValue* rawValue = [[BridgeJsonCodec sharedInstance] decode:data];
    [bridgePlugin jsSendMessageResponse:rawValue.result];
}

- (void)jsCancelMethodInner:(NSString*)bridgeName methodName:(NSString*)methodName {
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        return;
    }
    [bridgePlugin jsCancelMethod:bridgeName methodName:methodName];
}

- (void)platformCallMethodInner:(NSString*)bridgeName
                        methodName:(NSString*)methodName
                            param:(NSArray* _Nullable)params 
                        reultValueCallback:(void (^)(ResultValue* _Nullable reultValue))callback {
    ResultValue* resultValue = [[ResultValue alloc] init];
    if (!bridgeName.length) {
        resultValue.errorCode = BRIDGE_NAME_ERROR;
        resultValue.errorMessage = BRIDGE_NAME_ERROR_MESSAGE;
        if (callback) {
            callback(resultValue);
        }
        return;
    }

    if (!methodName.length) {
        resultValue.errorCode = BRIDGE_METHOD_NAME_ERROR;
        resultValue.errorMessage = BRIDGE_METHOD_NAME_ERROR_MESSAGE;
        if (callback) {
            callback(resultValue);
        }
        return;
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
    OHOS::Ace::Platform::BridgeManager::PlatformCallMethod(c_bridgeName, c_methodName, c_param);
}

- (ResultValue*)platformCallMethodInnerReult:(NSString*)bridgeName
                                  methodName:(NSString*)methodName
                                       param:(NSArray* _Nullable)params {
    ResultValue* resultValue = [[ResultValue alloc] init];
    if (!bridgeName.length) {
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
    std::string result =
        OHOS::Ace::Platform::BridgeManager::PlatformCallMethodResult(c_bridgeName, c_methodName, c_param);
    NSString* strResult = [NSString stringWithCString:result.c_str() encoding:NSUTF8StringEncoding];
    RawValue* rawValue = [[BridgeJsonCodec sharedInstance] decode:strResult];
    resultValue.result = rawValue.result ?: @"";
    resultValue.errorCode = (ErrorCode)rawValue.errorCode;
    resultValue.errorMessage = rawValue.errorMessage ?: @"";
    resultValue.methodName = methodName;
    return resultValue;
}

- (void)platformSendMessageInner:(NSString*)bridgeName data:(id)data {
    if (!bridgeName.length) {
        NSLog(@"bridgeName is null");
        return;
    }
    RawValue* rawValue = [RawValue rawValueResult:data errorCode:0];
    NSString* string = [[BridgeJsonCodec sharedInstance] encode:rawValue];

    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_data;
    if (string) {
        c_data = [string UTF8String];
    }
    OHOS::Ace::Platform::BridgeManager::PlatformSendMessage(c_bridgeName, c_data);
}

- (void)platformSendMessageResponseInner:(NSString*)bridgeName data:(id)data {
    if (!bridgeName.length) {
        NSLog(@"bridgeName is null");
        return;
    }
    RawValue* rawValue = [RawValue rawValueResult:data errorCode:0];
    NSString* jsonString = [[BridgeJsonCodec sharedInstance] encode:rawValue];

    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_data;
    if (jsonString) {
        c_data = [jsonString UTF8String];
    }
    OHOS::Ace::Platform::BridgeManager::PlatformSendMessageResponse(c_bridgeName, c_data);
}

- (void)platformSendMethodResultInner:(NSString*)bridgeName methodName:(NSString*)methodName result:(NSString*)result {
    if (!bridgeName.length) {
        NSLog(@"bridgeName is null");
        return;
    }
    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_methodName = [methodName UTF8String];
    std::string c_result;
    if (result) {
        c_result = [result UTF8String];
    }
    OHOS::Ace::Platform::BridgeManager::PlatformSendMethodResult(c_bridgeName, c_methodName, c_result);
}

- (void)jsSendMessageBinaryInner:(NSString*)bridgeName data:(id)data {
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

- (void)jsCallMethodBinaryInner:(NSString*)bridgeName methodName:(NSString*)methodName param:(NSData*)data {
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        [self platformSendMethodResultErrorInfo:bridgeName methodName:methodName errorCode:BRIDGE_INVALID];
        return;
    }
    if (bridgePlugin.type != BINARY_TYPE) {
        [self platformSendMethodResultErrorInfo:bridgeName
                methodName:methodName errorCode:BRIDGE_CODEC_TYPE_MISMATCH];
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

    MethodData* methodData = [[MethodData alloc] initMethodWithName:methodName
                                                    parameter:oc_parameter.copy];
    [bridgePlugin jsCallMethod:methodData];
}

- (ResultValue*)jsCallMethodBinarySync:(NSString*)bridgeName methodName:(NSString*)methodName param:(NSData*)data
{
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin || bridgePlugin.type != BINARY_TYPE) {
        ResultValue* resultValue = [[ResultValue alloc] init];
        resultValue.errorCode = BRIDGE_INVALID;
        resultValue.errorMessage = BRIDGE_INVALID_MESSAGE;
        return resultValue;
    }
    NSArray* oc_parameter = @[];
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
    return [bridgePlugin jsCallMethodBinarySync:methodData];
}

- (void)platformSendMethodResultBinaryInner:(NSString*)bridgeName
                            methodName:(NSString*)methodName
                            errorCode:(int)errorCode
                            errorMessage:(NSString*)errorMessage
                            result:(id)result {
    if (!bridgeName.length) {
        NSLog(@"bridgeName is null");
        return;
    }

    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_methodName = [methodName UTF8String];
    NSData* dataResult = [[BridgeBinaryCodec sharedInstance] encode:result];

    std::string c_errorMessage;
    if (errorMessage) {
        c_errorMessage = [errorMessage UTF8String];
    }
    auto c_result = NSDataToBufferMapping(dataResult);
    OHOS::Ace::Platform::BridgeManager::PlatformSendMethodResultBinary(
        c_bridgeName, c_methodName, errorCode, c_errorMessage, std::move(c_result));
}

- (void)platformSendMessageBinaryInner:(NSString*)bridgeName data:(id)data {
    if (!bridgeName.length) {
        NSLog(@"bridgeName is null");
        return;
    }

    std::string c_bridgeName = [bridgeName UTF8String];
    NSData* dataResult = [[BridgeBinaryCodec sharedInstance] encode:data];
        auto c_data = NSDataToBufferMapping(dataResult);
        OHOS::Ace::Platform::BridgeManager::PlatformSendMessageBinary(c_bridgeName, std::move(c_data));
}

- (void)platformCallMethodBinaryInner:(NSString*)bridgeName
                                methodName:(NSString*)methodName
                                    param:(NSArray* _Nullable)params
                                reultValueCallback:(void (^)(ResultValue* _Nullable reultValue))callback {
    ResultValue* resultValue = [[ResultValue alloc] init];
    if (!bridgeName.length) {
        resultValue.errorCode = BRIDGE_NAME_ERROR;
        resultValue.errorMessage = BRIDGE_NAME_ERROR_MESSAGE;
        if (callback) {
            callback(resultValue);
        }
        return;
    }

    if (!methodName.length) {
        resultValue.errorCode = BRIDGE_METHOD_NAME_ERROR;
        resultValue.errorMessage = BRIDGE_METHOD_NAME_ERROR_MESSAGE;
        if (callback) {
            callback(resultValue);
        }
        return;
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
    auto c_result = NSDataToBufferMapping(dataResult);
    OHOS::Ace::Platform::BridgeManager::PlatformCallMethodBinary(
                c_bridgeName, c_methodName, std::move(c_result));
}

- (ResultValue*)platformCallMethodBinaryInnerResult:(NSString*)bridgeName
                                         methodName:(NSString*)methodName
                                              param:(NSArray* _Nullable)params {
    ResultValue* resultValue = [[ResultValue alloc] init];
    if (!bridgeName.length) {
        resultValue.errorCode = BRIDGE_NAME_ERROR;
        resultValue.errorMessage = BRIDGE_NAME_ERROR_MESSAGE;
        return resultValue;
    }
    if (!methodName.length) {
        resultValue.errorCode = BRIDGE_METHOD_NAME_ERROR;
        resultValue.errorMessage = BRIDGE_METHOD_NAME_ERROR_MESSAGE;
        return resultValue;
    }
    NSData* dataResult = nil;
    if (params.count == 0) {
        dataResult = nil;
    } else {
        dataResult = [[BridgeBinaryCodec sharedInstance] encode:params];
    }
    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_methodName = [methodName UTF8String];
    auto c_result = NSDataToBufferMapping(dataResult);
    int32_t errorCode = BRIDGE_ERROR_NO;
    std::unique_ptr<OHOS::Ace::Platform::BufferMapping> data_bufferMapping =
        OHOS::Ace::Platform::BridgeManager::PlatformCallMethodBinarySync(
            c_bridgeName, c_methodName, std::move(c_result), errorCode);
    if (errorCode != BRIDGE_ERROR_NO) {
        resultValue.errorCode = SafeIntToErrorCode(static_cast<int>(errorCode));
        resultValue.errorMessage = [self getErrorMessage:errorCode];
        return resultValue;
    }
    NSData* nsData = ConvertBufferMappingToNSData(std::move(data_bufferMapping));
    if (nsData == nil && params.count != 0) {
        resultValue.errorCode = BRIDGE_DATA_ERROR;
        resultValue.errorMessage = BRIDGE_DATA_ERROR_MESSAGE;
        return resultValue;
    }
    id oc_resultValue = [[BridgeBinaryCodec sharedInstance] decode:nsData];
    resultValue.result = oc_resultValue ?: @"";
    resultValue.errorCode = BRIDGE_ERROR_NO;
    resultValue.errorMessage = BRIDGE_ERROR_NO_MESSAGE;
    resultValue.methodName = methodName;
    return resultValue;
}

ErrorCode SafeIntToErrorCode(int value) {
    if (value < BRIDGE_ERROR_NO || value > BRIDGE_END) {
        return BRIDGE_END;
    }
    return static_cast<ErrorCode>(value);
}

- (NSString*)getErrorMessage:(int32_t)index
{
    NSArray* arr = @[
        BRIDGE_ERROR_NO_MESSAGE, BRIDGE_NAME_ERROR_MESSAGE, BRIDGE_CREATE_ERROR_MESSAGE, BRIDGE_INVALID_MESSAGE,
        BRIDGE_METHOD_NAME_ERROR_MESSAGE, BRIDGE_METHOD_RUNNING_MESSAGE, BRIDGE_METHOD_UNIMPL_MESSAGE,
        BRIDGE_METHOD_PARAM_ERROR_MESSAGE, BRIDGE_METHOD_EXISTS_MESSAGE, BRIDGE_DATA_ERROR_MESSAGE,
        BRIDGE_BOTTOM_COMMUNICATION_ERROR_MESSAGE, BRIDGE_CODEC_TYPE_MISMATCH_MESSAGE,
        BRIDGE_CODEC_INVALID_MESSAGE, BRIDGE_END_MESSAGE
    ];
    if (index < 0 || index >= arr.count) {
        return @"";
    }
    return arr[index];
}

- (void)jsSendMethodResultBinaryInner:(NSString*)bridgeName
                    methodName:(NSString*)methodName
                    errorCode:(int)errorCode
                    errorMessage:(NSString*)errorMessage
                    result:(id)result {
    BridgePlugin* bridgePlugin = (BridgePlugin*)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        NSLog(@"bridgePlugin is null");
        return;
    }
    if (bridgePlugin.type != BINARY_TYPE) {
        NSLog(@"bridgePlugin type not BINARY_TYPE");
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

- (BridgePlugin* _Nullable)getPluginWithBridgeName:(NSString*)bridgeName {
    if (!bridgeName.length) {
        NSLog(@"bridgeName is null");
        return nil;
    }
    @synchronized(self) {
        BridgePlugin* bridgePlugin = (BridgePlugin*)[self.bridgeMap objectForKey:bridgeName];
        return bridgePlugin;
    }
}

- (void)dispatchTaskInQueueHandlerWithTaskInfo:(BridgeTaskInfo*)taskInfo {
    if (!taskInfo) {
        return;
    }
    NSString* bridgeName = taskInfo.bridgeName;
    if (!bridgeName || bridgeName.length == 0) {
        NSLog(@"no register bridge handler, %@", bridgeName);
        return;
    }
    BridgeTaskQueueHandler* handler = (BridgeTaskQueueHandler*)[self.bridgeQueueMap objectForKey: bridgeName];
    if (!handler || !handler.isUseTaskQueue) {
        taskInfo.handler();
        return;
    }
    [handler dispatchTaskInfo:taskInfo];
}


@end
