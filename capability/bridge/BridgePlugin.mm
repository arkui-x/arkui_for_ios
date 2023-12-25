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

#import "BridgePlugin.h"

#import <objc/message.h>
#import <objc/runtime.h>

#import "BridgePluginManager+internal.h"
#import "BridgeManagerHolder.h"
#import "ResultValue.h"

@interface BridgePlugin () {
    BridgeType _bridgeType;
    BOOL _isAvailable;
}
@property(nonatomic, strong) TaskOption* taskOptionInner;
@end

@implementation BridgePlugin

#pragma mark - public method
 
- (instancetype)initBridgePlugin:(NSString* _Nonnull)bridgeName
                    instanceId:(int32_t)instanceId {
    return [self initBridgePlugin:bridgeName instanceId:instanceId bridgeType:JSON_TYPE];
}

- (instancetype)initBridgePlugin:(NSString* _Nonnull)bridgeName
                    instanceId:(int32_t)instanceId
                    bridgeType:(BridgeType)type {
    self.instanceId = instanceId;
    BridgePluginManager* bridgeManager = [BridgeManagerHolder getBridgeManagerWithInceId:instanceId];
    return [self initBridgePlugin:bridgeName bridgeType:type bridgeManager:bridgeManager];
}

- (instancetype)initBridgePlugin:(NSString* _Nonnull)bridgeName
                    bridgeManager:(BridgePluginManager*)bridgeManager {
    return [self initBridgePlugin:bridgeName bridgeType:JSON_TYPE bridgeManager:bridgeManager taskOption:nil];
}

- (instancetype)initBridgePlugin:(NSString* _Nonnull)bridgeName
                    bridgeType:(BridgeType)type
                    bridgeManager:(BridgePluginManager *)bridgeManager {
    return [self initBridgePlugin:bridgeName bridgeType:type bridgeManager:bridgeManager taskOption:nil];
}

- (instancetype)initBridgePlugin:(NSString* _Nonnull)bridgeName
                        bridgeType:(BridgeType)type
                        bridgeManager:(BridgePluginManager*)bridgeManager
                        taskOption:(TaskOption*)taskOption {
    self = [super init];
    if (self) {
        if (taskOption) {
            self.taskOptionInner = taskOption;
        }
        self.bridgeName = bridgeName;
        self.bridgeManager = bridgeManager;
        if ([self checkBridgeInner]) {
            _isAvailable = [self.bridgeManager registerBridgePlugin:bridgeName bridgePlugin:self];
        }
        _bridgeType = type;
    }
    return self;
}

- (void)callMethod:(MethodData*)method {
    if (!_isAvailable) {
        NSLog(@"bridgePlugin is available!");
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
                                                reultValueCallback:nil];
    }
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
        NSLog(@"bridgePlugin is available!");
        return;
    }
    if (self.type == JSON_TYPE) {
        [self.bridgeManager platformSendMessage:self.bridgeName data:data];
    } else {
        // BINARY_TYPE
        if ([data isKindOfClass:[NSArray class]]) {
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
    return [self.bridgeManager unRegisterBridgePlugin:bridgeName];
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
    return false;
}

@end