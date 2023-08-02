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
#import "BridgePlugin+jsMessage.h"
#import <Foundation/Foundation.h>
#import "ParameterHelper.h"

#include "adapter/ios/capability/bridge/bridge_manager.h"
#include "adapter/ios/entrance/ace_container.h"
#include "core/common/ace_engine.h"
#include "core/common/container.h"
#include "base/log/log.h"
#include "core/common/flutter/flutter_task_executor.h"

@interface BridgePluginManager ()
{
    BOOL _willTerminate;
}
@property (nonatomic, strong) NSMutableDictionary<NSString *, BridgePlugin *> *bridgeMap;
@end

@implementation BridgePluginManager

+ (instancetype)shareManager {
    static BridgePluginManager *_manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manager = [[BridgePluginManager alloc] init];
    });
    return _manager;
}

#pragma mark - public method
- (BOOL)registerBridgePlugin:(NSString *)bridgeName
                bridgePlugin:(BridgePlugin *)bridgePlugin {
    if (!bridgeName.length || !bridgePlugin) {
        NSLog(@"register failed, bridgename : %@, plugin : %@", bridgeName, bridgePlugin);
        return NO;
    }
    @synchronized (self) {
        if ([self.bridgeMap.allKeys containsObject:bridgeName]) {
            NSLog(@"register failed, bridgePlugin exist");
            return NO;
        }
        NSLog(@"register success, bridgeName : %@, plugin : %@", bridgeName, bridgePlugin);
        [self.bridgeMap setObject:bridgePlugin
                           forKey:bridgeName];
    }
    return YES;
}

- (void)UnRegisterBridgePluginWithInstanceId:(int32_t)instanceId {
    @synchronized (self) {
        NSArray *allValues = self.bridgeMap.allValues;
        if (!allValues.count) {
            return;
        }
        for (BridgePlugin *plugin in allValues) {
            if (instanceId == plugin.instanceId) {
                NSUInteger index = [self.bridgeMap.allValues indexOfObject:plugin];
                NSString *key = [self.bridgeMap.allKeys objectAtIndex:index];
                [self.bridgeMap removeObjectForKey:key];
            }
        }
    }
}

- (void)UnRegisterBridgePlugin:(NSString *)bridgeName {
    if (!bridgeName.length) {
        return;
    }
    @synchronized (self) {
        NSLog(@"bridge unregister, name : %@", bridgeName);
        [self.bridgeMap removeObjectForKey:bridgeName];
    }
}

- (void)jsCallMethod:(NSString *)bridgeName
          methodName:(NSString *)methodName
               param:(NSString * _Nullable)param {
    NSLog(@"%s, bridgeName : %@, methodName : %@, param : %@", __func__, bridgeName, methodName, param);
    BridgePlugin *bridgePlugin = (BridgePlugin *)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        NSDictionary *errorResult = @{@"errorcode":@(BRIDGE_INVALID)};
        NSString *jsonString = [ParameterHelper jsonStringWithObject:errorResult];
        [self platformSendMethodResult:bridgeName
                            methodName:methodName
                                result:jsonString
                            instanceId:1];
        return;
    }
    NSMutableArray *mArray = [NSMutableArray array];
    if (param) {
        id methodParam = [ParameterHelper objectWithJSONString:param];
        if (methodParam && [methodParam isKindOfClass:NSDictionary.class]) {
            NSDictionary * methodDic = (NSDictionary *)methodParam;
            for (int i = 0; i < methodDic.allKeys.count; i++) {
                id argument = [methodDic objectForKey:[NSString stringWithFormat:@"%d",i]];
                [mArray addObject:argument];
            }
        }
    }
    MethodData *methodData = [[MethodData alloc] initMethodWithName:methodName
                                                                parameter:mArray.copy];
    NSLog(@"bridgeName : %@, methodParamArray : %@, bridgePlugin : %@", bridgeName, mArray, bridgePlugin);
    [bridgePlugin jsCallMethod:methodData];
}

- (void)jsSendMethodResult:(NSString *)bridgeName
                methodName:(NSString *)methodName
                    result:(NSString *)result {
    NSLog(@"%s, bridgeName : %@, methodName : %@, result : %@", __func__, bridgeName, methodName, result);
    BridgePlugin *bridgePlugin = (BridgePlugin *)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        return;
    }
    id resultObj = [ParameterHelper objectWithJSONString:result];
    ResultValue *resultValue = [[ResultValue alloc] init];
    NSDictionary *dic = (NSDictionary *)resultObj;
    resultValue.result = dic[@"result"] ? dic[@"result"] : @"";
    resultValue.errorCode = (ErrorCode)[dic[@"errorcode"] intValue];
    resultValue.errorMessage = dic[@"errormessage"] ? dic[@"errormessage"] : @"";
    resultValue.methodName = methodName;
    [bridgePlugin jsSendMethodResult:resultValue];
}

- (void)jsSendMessage:(NSString *)bridgeName
                 data:(NSString *)data {
    NSLog(@"%s, bridgeName : %@, data : %@", __func__, bridgeName, data);
    BridgePlugin *bridgePlugin = (BridgePlugin *)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        [self platformSendMessageResponseErrorInfo:bridgeName errorCode:BRIDGE_NAME_ERROR];
        return;
    }
    [bridgePlugin jsSendMessage:data];
}

- (void)jsSendMessageResponse:(NSString *)bridgeName
                         data:(NSString *)data {
    NSLog(@"%s, bridgeName : %@, data : %@", __func__, bridgeName, data);
    BridgePlugin *bridgePlugin = (BridgePlugin *)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        return;
    }
    [bridgePlugin jsSendMessageResponse:data];
}

- (void)jsCancelMethod:(NSString *)bridgeName
            methodName:(NSString *)methodName {
    NSLog(@"%s, bridgeName : %@, methodName : %@", __func__, bridgeName, methodName);
    BridgePlugin *bridgePlugin = (BridgePlugin *)[self getPluginWithBridgeName:bridgeName];
    if (!bridgePlugin) {
        return;
    }
    [bridgePlugin jsCancelMethod:bridgeName methodName:methodName];
}

- (ResultValue *)platformCallMethod:(NSString *)bridgeName
                            methodName:(NSString  *)methodName
                                 param:(NSString * _Nullable)param
                            instanceId:(int32_t)instanceId {
    NSLog(@"%s, bridgeName : %@, methodName : %@, param : %@", __func__, bridgeName, methodName, param);
    ResultValue *resultValue = [[ResultValue alloc] init];
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
    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_methodName = [methodName UTF8String];
    std::string c_param = [param.length ? param : @"" UTF8String];

    OHOS::Ace::ContainerScope scope(instanceId);
    auto taskExecutor = OHOS::Ace::Container::CurrentTaskExecutor();
    if (!taskExecutor) {
        NSLog(@"null taskExecutor");
        resultValue.errorCode = BRIDGE_BOTTOM_COMMUNICATION_ERROR;
        resultValue.errorMessage = BRIDGE_BOTTOM_COMMUNICATION_ERROR_MESSAGE;
        return resultValue;
    }
    auto task = [c_bridgeName, c_methodName, c_param, instanceId] {
        OHOS::Ace::Platform::BridgeManager::PlatformCallMethod(c_bridgeName, c_methodName, c_param);
    };
    
    taskExecutor->PostTask(task, OHOS::Ace::TaskExecutor::TaskType::JS);
    return nil;
}

- (void)platformSendMessage:(NSString *)bridgeName
                       data:(NSString *)data
                 instanceId:(int32_t)instanceId {
    NSLog(@"%s, bridgeName : %@, data : %@", __func__, bridgeName, data);
    if (!bridgeName.length) {
        return;
    }
    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_data = [data UTF8String];
    
    OHOS::Ace::ContainerScope scope(instanceId);
    auto taskExecutor = OHOS::Ace::Container::CurrentTaskExecutor();
    if (!taskExecutor) {
        NSLog(@"null taskExecutor");
        return;
    }
    auto task = [c_bridgeName, c_data] {
        OHOS::Ace::Platform::BridgeManager::PlatformSendMessage(c_bridgeName, c_data);
    };
    
    taskExecutor->PostTask(task, OHOS::Ace::TaskExecutor::TaskType::JS);
}

- (void)platformSendMessageResponse:(NSString *)bridgeName
                               data:(NSString *)data
                         instanceId:(int32_t)instanceId {
    NSLog(@"%s, bridgeName : %@, data : %@", __func__, bridgeName, data);
    if (!bridgeName.length) {
        return;
    }
    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_data = [data UTF8String];
    
    OHOS::Ace::ContainerScope scope(instanceId);
    auto taskExecutor = OHOS::Ace::Container::CurrentTaskExecutor();
    if (!taskExecutor) {
        NSLog(@"null taskExecutor");
        return;
    }
    auto task = [c_bridgeName, c_data] {
        OHOS::Ace::Platform::BridgeManager::PlatformSendMessageResponse(c_bridgeName, c_data);
    };
    
    taskExecutor->PostTask(task, OHOS::Ace::TaskExecutor::TaskType::JS);
}

- (void)platformSendMethodResult:(NSString *)bridgeName
                      methodName:(NSString *)methodName
                          result:(NSString *)result
                      instanceId:(int32_t)instanceId {
    NSLog(@"%s, bridgeName : %@, result : %@", __func__, bridgeName, result);
    if (!bridgeName.length) {
        return;
    }
    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_methodName = [methodName UTF8String];
    std::string c_result = [result UTF8String];
    
    OHOS::Ace::ContainerScope scope(instanceId);
    auto taskExecutor = OHOS::Ace::Container::CurrentTaskExecutor();
    if (!taskExecutor) {
        NSLog(@"null taskExecutor");
        return;
    }
    
    auto task = [c_bridgeName, c_methodName,c_result] {
        OHOS::Ace::Platform::BridgeManager::PlatformSendMethodResult(c_bridgeName, c_methodName, c_result);
    };
    
    taskExecutor->PostTask(task, OHOS::Ace::TaskExecutor::TaskType::JS);
}

- (void)platformSendMessageResponseErrorInfo:(NSString *)bridgeName errorCode:(ErrorCode)errorCode {
    NSDictionary *dic = @{@"result":@"errorcode", @"errorcode":@(errorCode)};
    NSString *string = (NSString *)[ParameterHelper jsonStringWithObject:dic];
    std::string c_bridgeName = [bridgeName UTF8String];
    std::string c_data = [string UTF8String];
    OHOS::Ace::Platform::BridgeManager::PlatformSendMessageResponse(c_bridgeName, c_data);
}

- (void)platformWillTerminate {
    if (_willTerminate){
        return;
    }
    _willTerminate = true;
    OHOS::Ace::Platform::BridgeManager::PlatformSendWillTerminate();
}

#pragma mark - private method
- (BridgePlugin * _Nullable)getPluginWithBridgeName:(NSString *)bridgeName {
    if (!bridgeName.length) {
        NSLog(@"no register bridge, %@", bridgeName);
        return nil;
    }
    BridgePlugin * bridgePlugin = (BridgePlugin *)[self.bridgeMap objectForKey:bridgeName];
    NSLog(@"bridgePlugin : %@, bridgeMap : %@", bridgePlugin, self.bridgeMap);
    return bridgePlugin;
}

- (NSMutableDictionary *)bridgeMap {
    if (!_bridgeMap) {
        _bridgeMap = [[NSMutableDictionary alloc] init];
    }
    return _bridgeMap;
}

@end
