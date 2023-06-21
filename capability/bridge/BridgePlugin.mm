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
#import <objc/runtime.h>
#import <objc/message.h>
#import "ParameterHelper.h"
#import "BridgePluginManager.h"

@interface BridgePlugin () {
    BOOL _isAvailable;
}
@end

@implementation BridgePlugin

#pragma mark - public method
- (instancetype)initBridgePlugin:(NSString *_Nonnull)bridgeName
                      instanceId:(int32_t)instanceId {
    self = [super init];
    if (self) {
        self.bridgeName = bridgeName;
        self.instanceId = instanceId;
        NSLog(@"init bridgeplugin bridgeName %@", bridgeName);
        BOOL isSuccess = [[BridgePluginManager shareManager] registerBridgePlugin:bridgeName
                                                                     bridgePlugin:self];
        _isAvailable = isSuccess;
    }
    return self;
}

- (void)callMethod:(MethodData *)method {
    if (!_isAvailable) {
        NSLog(@"bridgePlugin is available!");
        return;
    }
    NSString *jsonString = nil;
    if (method.parameter.count > 0) {
        NSMutableDictionary *mDic = [NSMutableDictionary dictionary];
        for (int i = 0; i < method.parameter.count; i++) {
            [mDic setObject:method.parameter[i] forKey:[NSString stringWithFormat:@"%d",i]];
        }
        jsonString = [ParameterHelper jsonStringWithObject:mDic.copy];
    }
    NSLog(@"%s, method : %@, jsonString : %@", __func__, method, jsonString);
    ResultValue *result = [[BridgePluginManager shareManager] platformCallMethod:self.bridgeName
                                                                            methodName:method.methodName
                                                                                 param:jsonString
                                                                            instanceId:self.instanceId];
    if (result) {
        [self.methodResult onError:method.methodName
                         errorCode:result.errorCode
                      errorMessage:result.errorMessage];
    }
}

- (void)sendMessage:(id)data {
    if (!_isAvailable) {
        NSLog(@"bridgePlugin is available!");
        return;
    }
    if (!data) {
        return;
    }
    NSDictionary *dic = @{@"result":data, @"errorcode":@(0)};
    NSString *string = (NSString *)[ParameterHelper jsonStringWithObject:dic];
    NSLog(@"%s, string : %@", __func__, string);
    [[BridgePluginManager shareManager] platformSendMessage:self.bridgeName
                                                          data:string
                                                    instanceId:self.instanceId];
}

@end
