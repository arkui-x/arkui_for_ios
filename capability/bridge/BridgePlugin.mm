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
#import "BridgePluginManager.h"
#import "ResultValue.h"
#import <objc/message.h>
#import <objc/runtime.h>

@interface BridgePlugin () {
    BOOL _isAvailable;
    BridgeType _bridgeType;
}
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
    self = [super init];
    if (self) {
        self.bridgeName = bridgeName;
        self.instanceId = instanceId;
        NSLog(@"init bridgeplugin bridgeName %@", bridgeName);
        BOOL isSuccess = [[BridgePluginManager shareManager] registerBridgePlugin:bridgeName
                                                                     bridgePlugin:self];
        _isAvailable = isSuccess;
        _bridgeType = type;
    }
    return self;
}

- (void)callMethod:(MethodData*)method {
    if (!_isAvailable) {
        NSLog(@"bridgePlugin is available!");
        return;
    }

    NSLog(@"%s, method : %@", __func__, method);
    ResultValue* result;
    if (self.type == JSON_TYPE) {
        result = [[BridgePluginManager shareManager] platformCallMethod:self.bridgeName
                                                             methodName:method.methodName
                                                                  param:method.parameter
                                                             instanceId:self.instanceId];
    } else {
        result = [[BridgePluginManager shareManager] platformCallMethodBinary:self.bridgeName
                                                                   methodName:method.methodName
                                                                        param:method.parameter
                                                                   instanceId:self.instanceId];
    }

    if (result) {
         if (self.methodResult &&
                [self.methodResult respondsToSelector:@selector(onError:errorCode:errorMessage:)])
            {
                [self.methodResult onError:method.methodName
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
        [[BridgePluginManager shareManager] platformSendMessage:self.bridgeName
                                                           data:data
                                                     instanceId:self.instanceId];
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

        [[BridgePluginManager shareManager] platformSendMessageBinary:self.bridgeName
                                                                 data:data
                                                           instanceId:self.instanceId];
    }
}

- (BridgeType)type {
    return _bridgeType;
}

@end