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

#import "BridgePlugin+jsMessage.h"
#import "ParameterHelper.h"
#import "BridgePluginManager.h"

@implementation BridgePlugin (jsMessage)

- (void)jsCallMethod:(MethodData *)callMethod {
    NSString *resultString = nil;
    ErrorCode errorCode = BRIDGE_ERROR_NO;
    NSString *errorMessage = nil;
    NSMutableDictionary *resultDic = [NSMutableDictionary dictionary];
    if (!callMethod.methodName.length) {
        errorCode = BRIDGE_METHOD_NAME_ERROR;
        errorMessage = BRIDGE_METHOD_NAME_ERROR_MESSAGE;
    } else {
        NSArray *parameterArray = (NSArray *)callMethod.parameter;
        SEL c_method = NSSelectorFromString(callMethod.methodName);
        id result = nil;
        NSLog(@"%s, parameterArray : %@", __func__, parameterArray);
        if ([self respondsToSelector:c_method]) {
            @try {
                result = [self performeNewSelector:c_method
                                        withParams:parameterArray
                                            target:self];
                if (result && [result isKindOfClass:NSDictionary.class]) {
                    NSDictionary * dic = (NSDictionary *)result;
                    errorCode = (ErrorCode)[dic[@"errorCode"] intValue];
                    errorMessage = dic[@"errorMessage"];
                }
                NSLog(@"try result : %@", result);
            } @catch (NSException *exception) {
                errorCode = BRIDGE_METHOD_UNIMPL;
                errorMessage = BRIDGE_METHOD_UNIMPL_MESSAGE;
                NSLog(@"catch exception name : %@, reason : %@", [exception name], [exception reason]);
            } @finally {
                if (result && [result isKindOfClass:NSString.class]) {
                    resultString = result;
                }
                NSLog(@"finally resultStirng : %@", resultString);
            }
        } else {
            errorCode = BRIDGE_METHOD_UNIMPL;
            errorMessage = BRIDGE_METHOD_UNIMPL_MESSAGE;
            NSLog(@"method error, message : %@", errorMessage);
        }
    }
    [resultDic setObject:callMethod.methodName forKey:@"methodName"];
    [resultDic setObject:@(errorCode) forKey:@"errorcode"];
    [resultDic setObject:errorMessage.length ? errorMessage : @"" forKey:@"errormessage"];
    if (resultString.length) {
        [resultDic setObject:resultString forKey:@"result"];
    }
    NSString *jsonString = [ParameterHelper jsonStringWithObject:resultDic];
    [[BridgePluginManager shareManager] platformSendMethodResult:self.bridgeName
                                                         methodName:callMethod.methodName
                                                             result:jsonString.length ? jsonString : @""
                                                         instanceId:self.instanceId];
    NSLog(@"%s, resultString : %@", __func__, jsonString);
}

- (void)jsSendMethodResult:(ResultValue *)object {
    NSLog(@"%s, object : %@", __func__, object);
    if (self.methodResult &&
        [self.methodResult respondsToSelector:@selector(onSuccess:resultValue:)]) {
        if (object.errorCode > 0) {
            [self.methodResult onError:object.methodName
                             errorCode:object.errorCode
                          errorMessage:object.errorMessage];
        } else {
            [self.methodResult onSuccess:object.methodName
                             resultValue:object.result];
        }
    }
}

- (void)jsSendMessage:(NSString *)data {
    id obj = [ParameterHelper objectWithJSONString:data];
    NSLog(@"%s, dataString : %@, obj : %@", __func__, data, obj);
    if (obj && self.messageListener && [self.messageListener respondsToSelector:@selector(onMessage:)]) {
        id object = [self.messageListener onMessage:obj[@"result"]];
        if (object) {
            NSDictionary *dic = @{@"result":object, @"errorcode":@(0)};
            NSString *string = [ParameterHelper jsonStringWithObject:dic];
            NSLog(@"data : %@, string : %@", object, string);
            [[BridgePluginManager shareManager] platformSendMessageResponse:self.bridgeName
                                                                          data:string
                                                                    instanceId:self.instanceId];
        }
    }
}

- (void)jsSendMessageResponse:(NSString *)data {
    id obj = [ParameterHelper objectWithJSONString:data];
    NSLog(@"%s, dataString : %@, obj : %@", __func__, data, obj);
    if (obj && self.messageListener && [self.messageListener respondsToSelector:@selector(onMessageResponse:)]) {
        [self.messageListener onMessageResponse:obj[@"result"]];
    }
}

- (void)jsCancelMethod:(NSString *)bridgeName
            methodName:(NSString *)methodName {
    NSLog(@"%s, bridgeName : %@, methodName : %@", __func__, bridgeName, methodName);
    if (self.methodResult && [self.methodResult respondsToSelector:@selector(onMethodCancel:)]) {
        [self.methodResult onMethodCancel:methodName];
    }
}

- (id)performeNewSelector:(SEL)selector
               withParams:(NSArray *)params
                   target:(id)target {
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    if (!signature) {
        NSLog(@"signature nil");
        return @{@"errorCode":@(BRIDGE_METHOD_UNIMPL), @"errorMessage":BRIDGE_METHOD_UNIMPL_MESSAGE};
    }
    int signatureDefaultArgsNum = 2;
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = target;
    invocation.selector = selector;
    NSInteger paramsCount = signature.numberOfArguments - signatureDefaultArgsNum;
    if (paramsCount != params.count) {
        NSLog(@"params count error");
        return @{@"errorCode":@(BRIDGE_METHOD_PARAM_ERROR), @"errorMessage":BRIDGE_METHOD_PARAM_ERROR_MESSAGE};
    }
    if (params.count > 0) {
        for (int i = 0; i < paramsCount; i++) {
            id argument = params[i];
            const char *argumentType = [signature getArgumentTypeAtIndex:i + signatureDefaultArgsNum];
            NSLog(@"argument : %@", argument);
            if ([argument isKindOfClass:[NSNumber class]]) {
                if (!strcmp(argumentType, @encode(BOOL))) {
                    BOOL arg = [argument boolValue];
                    [invocation setArgument:&arg atIndex:i + signatureDefaultArgsNum];
                } else if (!strcmp(argumentType, @encode(int))) {
                    int arg = [argument intValue];
                    [invocation setArgument:&arg atIndex:i + signatureDefaultArgsNum];
                } else if (!strcmp(argumentType, @encode(float))) {
                    float arg = [argument floatValue];
                    [invocation setArgument:&arg atIndex:i + signatureDefaultArgsNum];
                } else if (!strcmp(argumentType, @encode(long))) {
                    long arg = [argument longValue];
                    [invocation setArgument:&arg atIndex:i + signatureDefaultArgsNum];
                } else {
                    return @{@"errorCode":@(BRIDGE_METHOD_PARAM_ERROR),
                             @"errorMessage":BRIDGE_METHOD_PARAM_ERROR_MESSAGE}; // illegal parameterType
                }
            } else {
                NSLog(@"paramsIndex : %d, id : %@", i, argument);
                [invocation setArgument:&argument atIndex:i + signatureDefaultArgsNum];
            }
        }
    }
    [invocation retainArguments];
    [invocation invoke];
    if (signature.methodReturnLength) {
        return [self handleReturnValue:signature invocation:invocation];
    }
    NSLog(@"no returnValue");
    return nil;
}

- (id)handleReturnValue:(NSMethodSignature *)signature
             invocation:(NSInvocation *)invocation {
    const char *returnType = signature.methodReturnType;
    if (!strcmp(returnType, @encode(void))) {
        NSLog(@"no returnValue");
        return nil;
    } else if (!strcmp(returnType, @encode(id))) {
        void *returnValue;
        [invocation getReturnValue:&returnValue];
        NSLog(@"id returnValue : %@", (__bridge id)returnValue);
        id obj = (__bridge id)returnValue;
        if ([obj isKindOfClass:NSString.class]) {
            return (NSString *)obj;
        } else {
            NSString *objString = [ParameterHelper jsonStringWithObject:obj];
            return objString;
        }
    } else {
        void *returnValue = (void *)malloc(signature.methodReturnLength);
        [invocation getReturnValue:returnValue];
        id result = nil;
        if (!strcmp(returnType, @encode(BOOL))) {
            result = [NSNumber numberWithBool:*((BOOL *)returnValue)];
        } else if (!strcmp(returnType, @encode(int))) {
            result = [NSNumber numberWithInt:*((int *)returnValue)];
        } else if (!strcmp(returnType, @encode(float))) {
            result = [NSNumber numberWithFloat:*((float *)returnValue)];
        } else if (!strcmp(returnType, @encode(long))) {
            result = [NSNumber numberWithLong:*((long *)returnValue)];
        }
        free(returnValue);
        NSLog(@"assign returnValue : %@", result);
        NSString *valueString = [NSString stringWithFormat:@"%@",result];
        return (NSString *)valueString;
    }
}

@end
