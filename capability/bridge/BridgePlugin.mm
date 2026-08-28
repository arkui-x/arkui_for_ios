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

#import "BridgePlugin.h"
#include <Foundation/Foundation.h>

#import <objc/message.h>
#import <objc/runtime.h>

#import "BridgeGCDTaskQueue.h"
#import "BridgePluginManager+internal.h"
#import "BridgeManagerHolder.h"
#import "ResultValue.h"
#include "base/log/log.h"

@interface BridgePlugin () {
    BridgeType _bridgeType;
}
@property(nonatomic, strong) TaskOption* taskOptionInner;
@property(nonatomic, strong) NSString* bridgeNameInner;
@property(nonatomic, strong) BridgePluginManager* bridgeManagerInner;
@property(nonatomic, assign) BOOL isAvailable;
@end

@implementation BridgePlugin

#pragma mark - public method
 
- (instancetype)initBridgePlugin:(NSString* _Nonnull)bridgeName
                    instanceId:(int32_t)instanceId {
    return [self initBridgePlugin:bridgeName bridgeManager:nil];
}

- (instancetype)initBridgePlugin:(NSString* _Nonnull)bridgeName
                    bridgeType:(BridgeType)type {
    return [self initBridgePlugin:bridgeName bridgeManager:nil bridgeType:type taskOption:nil];
}

- (instancetype)initBridgePlugin:(NSString* _Nonnull)bridgeName
                    bridgeManager:(BridgePluginManager*)bridgeManager {
    return [self initBridgePlugin:bridgeName bridgeManager:nil bridgeType:JSON_TYPE taskOption:nil];
}

- (instancetype)initBridgePlugin:(NSString* _Nonnull)bridgeName
                    bridgeManager:(BridgePluginManager*)bridgeManager
                    bridgeType:(BridgeType)type {
    return [self initBridgePlugin:bridgeName bridgeManager:nil bridgeType:type taskOption:nil];
}

- (instancetype)initBridgePlugin:(NSString* _Nonnull)bridgeName
                    bridgeManager:(BridgePluginManager*)bridgeManager
                    bridgeType:(BridgeType)type
                    taskOption:(TaskOption*)taskOption {
    self = [super init];
    if (self) {
        if (taskOption) {
            self.taskOptionInner = taskOption;
        }
        self.bridgeNameInner = bridgeName;
        _bridgeType = type;
        self.bridgeManagerInner = [BridgeManagerHolder getBridgePluginManager];
        if ([self checkBridgeInner]) {
            [self.bridgeManager innerRegisterBridgePlugin:bridgeName bridgePlugin:self];
        }
    }
    return self;
}

- (void)callMethod:(MethodData*)method {
    if (!_isAvailable) {
        LOGE("bridgePlugin callMethod, The bridge is not available, bridgeName: %{public}s", [self.bridgeName UTF8String]);
        return;
    }

    __weak BridgePlugin* weakSelf = self;
    if (self.type == JSON_TYPE) {
        [self.bridgeManager platformCallMethod:self.bridgeName
                                                methodName:method.methodName
                                                param:method.parameter 
                                                reultValueCallback:(^(ResultValue* result) {
            [weakSelf sendErrorCodeWithResult:result withMethodName:method.methodName];
        })];
    } else {
        [self.bridgeManager platformCallMethodBinary:self.bridgeName
                                                    methodName:method.methodName
                                                    param:method.parameter
                                                    reultValueCallback:(^(ResultValue* result) {
            [weakSelf sendErrorCodeWithResult:result withMethodName:method.methodName];
        })];
    }
}

- (id)callMethodSyncInner:(MethodData*)method {
    ResultValue* resultValue = [[ResultValue alloc] init];
    @try {
        if (!_isAvailable) {
            LOGE("bridgePlugin callMethodSyncInner failed, the bridge is not available, bridgeName: %{public}s",
                [self.bridgeName UTF8String]);
            NSString* strCode = [NSString stringWithFormat:@"%d", BRIDGE_INVALID];
            NSException* exception = [NSException exceptionWithName:strCode reason:BRIDGE_INVALID_MESSAGE userInfo:nil];
            @throw exception;
        }
        if (self.type == JSON_TYPE) {
            resultValue = [self.bridgeManager platformCallMethodInnerReult:self.bridgeName
                                                                methodName:method.methodName
                                                                     param:method.parameter];
        } else {
            resultValue = [self.bridgeManager platformCallMethodBinaryInnerResult:self.bridgeName
                                                                       methodName:method.methodName
                                                                            param:method.parameter];
        }
        if (resultValue.errorCode != BRIDGE_ERROR_NO) {
            LOGE("bridgePlugin callMethodSyncInner failed, code: %{public}d, bridgeName: %{public}s, method=%{public}s",
                resultValue.errorCode, [self.bridgeName UTF8String], [method.methodName UTF8String]);
            NSString* strCode = [NSString stringWithFormat:@"%d", resultValue.errorCode];
            NSException* exception = [NSException exceptionWithName:strCode
                                                             reason:resultValue.errorMessage
                                                           userInfo:nil];
            @throw exception;
        }
    } @catch (NSException* exception) {
        LOGE("bridge callMethodSyncInner catch, name: %{public}s, reason: %{public}s",
            [exception.name ?: @"" UTF8String], [exception.reason ?: @"" UTF8String]);
        [exception raise];
    }
    return resultValue.result;
}

- (id)callMethodSync:(NSString*)methodName parameters:(id)firstObj, ... NS_REQUIRES_NIL_TERMINATION {
    NSMutableArray* objects = [NSMutableArray array];
    va_list arguments;
    if (firstObj) {
        id eachObject = nil;
        [objects addObject:firstObj];
        va_start(arguments, firstObj);
        while ((eachObject = va_arg(arguments, id))) {
            [objects addObject:eachObject];
        }
        va_end(arguments);
    }
    MethodData* methodData = [[MethodData alloc] initMethodWithName:methodName
                                                          parameter:objects.copy];
    return [self callMethodSyncInner:methodData];
}

- (void)sendErrorCodeWithResult:(ResultValue*)result withMethodName:(NSString*)methodName {
    if (result) {
         if (self.methodResult &&
                [self.methodResult respondsToSelector:@selector(onError:errorCode:errorMessage:)])
            {
                [self.methodResult onError:methodName
                        errorCode:result.errorCode
                    errorMessage:result.errorMessage];
            }
    }
}

- (void)sendMessage:(id)data {
    if (!_isAvailable) {
        LOGE("bridgePlugin sendMessage the bridge is not available, bridgeName: %{public}s", [self.bridgeName UTF8String]);
        return;
    }
    if (self.type == JSON_TYPE) {
        [self.bridgeManager platformSendMessage:self.bridgeName data:data];
    } else {
        // BINARY_TYPE
        if ([data isKindOfClass:[NSArray class]]) {
            LOGE("bridgePlugin sendMessage bridgeName: %{public}s data is array", [self.bridgeName UTF8String]);
            if (self.methodResult &&
                [self.methodResult respondsToSelector:@selector(onError:errorCode:errorMessage:)]) {
                [self.methodResult onError:@"please use BridgeArray"
                                errorCode:BRIDGE_DATA_ERROR
                            errorMessage:BRIDGE_DATA_ERROR_MESSAGE];
            }
            return;
        }

        [self.bridgeManager platformSendMessageBinary:self.bridgeName
                                                                data:data];
    }
}

- (BOOL)isBridgeAvailable {
    return _isAvailable;
}

- (BOOL)unRegister:(NSString*)bridgeName {
    return [self.bridgeManager innerUnRegisterBridgePlugin:bridgeName];
}

- (BridgeType)type {
    return _bridgeType;
}

- (TaskOption*)taskOption {
    return _taskOptionInner;
}

- (BOOL)checkBridgeInner {
    if (self.bridgeName && self.bridgeName.length != 0 && self.bridgeManager) {
        return true;
    }
    LOGE("bridgePlugin checkBridgeInner failed: bridgeName: %{public}s", [self.bridgeName UTF8String]);
    return false;
}

- (NSString*)bridgeName {
    return self.bridgeNameInner;
}

- (BridgePluginManager*)bridgeManager {
    return self.bridgeManagerInner;
}

- (void)onPeerReady {}
@end