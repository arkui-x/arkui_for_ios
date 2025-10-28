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
#import "BridgeJsonCodec.h"
#import "BridgePlugin+jsMessage.h"
#import "BridgePluginManager+internal.h"
#import "ResultValue.h"

@implementation BridgePlugin (jsMessage)

- (void)jsCallMethod:(MethodData*)callMethod {
    NSString* resultString = nil;
    ErrorCode errorCode = BRIDGE_ERROR_NO;
    NSString* errorMessage = nil;
    id result = nil;
    if (!callMethod.methodName.length) {
        errorCode = BRIDGE_METHOD_NAME_ERROR;
        errorMessage = BRIDGE_METHOD_NAME_ERROR_MESSAGE;
    } else {
        NSArray* parameterArray = (NSArray*)callMethod.parameter;
        if (callMethod.methodName.length != 0) {
            @try {
                NSString* tmep = callMethod.methodName;
                if ([tmep containsString:@"$"]) {
                    NSArray* strinMethodNameArr = [tmep componentsSeparatedByString:@"$"];
                    tmep = strinMethodNameArr[0];
                }
                result = [self performeNewSelector:tmep
                                        withParams:parameterArray
                                            target:self];
                if (result && [result isKindOfClass:NSDictionary.class]) {
                    NSDictionary* dic = (NSDictionary*)result;
                    errorCode = (ErrorCode)[dic[@"errorCode"] intValue];
                    errorMessage = dic[@"errorMessage"];
                }
            } @catch (NSException* exception) {
                errorCode = BRIDGE_METHOD_UNIMPL;
                errorMessage = BRIDGE_METHOD_UNIMPL_MESSAGE;
                NSLog(@"catch exception name : %@, reason : %@", [exception name], [exception reason]);
            } @finally {
                if (result && [result isKindOfClass:NSString.class]) {
                    resultString = result;
                }
            }
        } else {
            errorCode = BRIDGE_METHOD_UNIMPL;
            errorMessage = BRIDGE_METHOD_UNIMPL_MESSAGE;
            NSLog(@"method error, message : %@", errorMessage);
        }
    }

    if (self.type == JSON_TYPE) {
        [self.bridgeManager platformSendMethodResult:self.bridgeName
                                                        methodName:callMethod.methodName
                                                        errorCode:errorCode
                                                        errorMessage:errorMessage.length ? errorMessage : @""
                                                        result:resultString];
    } else {
        // BINARY_TYPE
        if ([result isKindOfClass:[NSArray class]]) {
            ResultValue* resultValue = [[ResultValue alloc] init];
            resultValue.errorCode = BRIDGE_DATA_ERROR;
            resultValue.errorMessage = BRIDGE_DATA_ERROR_MESSAGE;
            resultValue.methodName = [NSString stringWithFormat:@"%@: please use BridgeArray", callMethod.methodName];
            [self callPlatformError:resultValue];
            return;
        }
        [self.bridgeManager platformSendMethodResultBinary:self.bridgeName
                                                            methodName:callMethod.methodName
                                                            errorCode:errorCode
                                                            errorMessage:errorMessage.length ? errorMessage : @""
                                                            result:result];
    }
}

- (NSString*)jsCallMethodSync:(MethodData*)callMethod
{
    NSString* resultString = @"";
    ErrorCode errorCode = BRIDGE_ERROR_NO;
    NSString* errorMessage = BRIDGE_ERROR_NO_MESSAGE;
    id result = nil;
    if (!callMethod) {
        errorCode = BRIDGE_INVALID;
        errorMessage = BRIDGE_INVALID_MESSAGE;
        return [self createResultJson:errorCode errorMessage:errorMessage resultString:resultString];
    }
    NSArray* parameterArray = (NSArray*)callMethod.parameter;
    if (callMethod.methodName.length == 0) {
        errorCode = BRIDGE_METHOD_UNIMPL;
        errorMessage = BRIDGE_METHOD_UNIMPL_MESSAGE;
        NSLog(@"method error, message : %@", errorMessage);
        return [self createResultJson:errorCode errorMessage:errorMessage resultString:resultString];
    }
    @try {
        NSString* tmep = callMethod.methodName;
        if ([tmep containsString:@"$"]) {
            NSArray* strinMethodNameArr = [tmep componentsSeparatedByString:@"$"];
            tmep = strinMethodNameArr[0];
        }
        result = [self performeNewSelector:tmep withParams:parameterArray target:self];
        if (result && [result isKindOfClass:NSDictionary.class]) {
            NSDictionary* dic = (NSDictionary*)result;
            errorCode = (ErrorCode)[dic[@"errorCode"] intValue];
            errorMessage = dic[@"errorMessage"];
        }
    } @catch (NSException* exception) {
        errorCode = BRIDGE_METHOD_UNIMPL;
        errorMessage = BRIDGE_METHOD_UNIMPL_MESSAGE;
        NSLog(@"catch exception name : %@, reason : %@", [exception name], [exception reason]);
    } @finally {
        if (result && [result isKindOfClass:NSString.class]) {
            resultString = result;
        }
        NSLog(@"jsCallMethodBinarySync completed for method: %@ finally", callMethod.methodName);
    }
    return [self createResultJson:errorCode errorMessage:errorMessage resultString:resultString];
}

- (NSString*)createResultJson:(int)errorCode errorMessage:(NSString*)errorMessage resultString:(NSString*)resultString
{
    NSNumber* numberErrorCode = [NSNumber numberWithInt:errorCode];
    NSString* strErrorMessage = errorMessage ?: @"";
    NSString* strResult = resultString ?: @"";
    NSDictionary* dict = @{ @"errorCode" : numberErrorCode, @"errorMessage" : strErrorMessage, @"result" : strResult };
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
    NSString* resultJson = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return resultJson;
}

- (int)SafeParseErrorCode:(id)errorCodeObj
{
    int errorCode = BRIDGE_ERROR_NO;
    if ([errorCodeObj isKindOfClass:[NSNumber class]] || [errorCodeObj isKindOfClass:[NSString class]]) {
        errorCode = [errorCodeObj intValue];
    }
    if (errorCode < BRIDGE_ERROR_NO || errorCode > BRIDGE_END) {
        return BRIDGE_INVALID;
    }
    return errorCode;
}

- (ResultValue*)jsCallMethodBinarySync:(MethodData*)callMethod
{
    ResultValue* resultValue = [[ResultValue alloc] init];
    if (!callMethod) {
        resultValue.errorCode = BRIDGE_INVALID;
        resultValue.errorMessage = BRIDGE_INVALID_MESSAGE;
        return resultValue;
    }
    if (callMethod.methodName.length == 0) {
        resultValue.errorCode = BRIDGE_METHOD_NAME_ERROR;
        resultValue.errorMessage = BRIDGE_METHOD_NAME_ERROR_MESSAGE;
        return resultValue;
    }
    NSArray* parameterArray = (NSArray*)callMethod.parameter;
    NSString* tmep = callMethod.methodName;
    if ([tmep containsString:@"$"]) {
        NSArray* strinMethodNameArr = [tmep componentsSeparatedByString:@"$"];
        tmep = strinMethodNameArr[0];
    }
    id result = [self performeNewSelector:tmep withParams:parameterArray target:self];
    if (result == nil) {
        resultValue.errorCode = BRIDGE_DATA_ERROR;
        resultValue.errorMessage = BRIDGE_DATA_ERROR_MESSAGE;
        return resultValue;
    }
    if ([result isKindOfClass:[NSDictionary class]] && [((NSDictionary*)result) objectForKey:@"errorCode"]) {
        NSDictionary* dic = (NSDictionary*)result;
        resultValue.errorCode = (ErrorCode)[self SafeParseErrorCode:dic[@"errorCode"]];
        resultValue.errorMessage = dic[@"errorMessage"] ?: @"";
    } else {
        resultValue.errorCode = BRIDGE_ERROR_NO;
        resultValue.errorMessage = BRIDGE_ERROR_NO_MESSAGE;
        resultValue.result = [[BridgeBinaryCodec sharedInstance] encode:result];
    }
    return resultValue;
}

- (void)jsSendMethodResult:(ResultValue*)object {
    if (self.methodResult) {
        if (object.errorCode > 0) {
            if ([self.methodResult respondsToSelector:@selector(onError:errorCode:errorMessage:)]) {
                [self.methodResult onError:object.methodName
                            errorCode:object.errorCode
                            errorMessage:object.errorMessage];
            }
            
        } else {
            if ([self.methodResult respondsToSelector:@selector(onSuccess:resultValue:)]) {
                 [self.methodResult onSuccess:object.methodName
                            resultValue:object.result];
            }
        }
    }
}

- (void)jsSendMessage:(id)data {
    if (self.messageListener && [self.messageListener respondsToSelector:@selector(onMessage:)]) {
        id object = [self.messageListener onMessage:data];
        [self.bridgeManager platformSendMessageResponse:self.bridgeName
                                                            data:object];
    }
}

- (void)jsSendMessageResponse:(id)data {
    if (data && self.messageListener && [self.messageListener respondsToSelector:@selector(onMessageResponse:)]) {
        [self.messageListener onMessageResponse:data];
    }
}

- (void)jsCancelMethod:(NSString*)bridgeName methodName:(NSString*)methodName {
    if (self.methodResult && [self.methodResult respondsToSelector:@selector(onMethodCancel:)]) {
        [self.methodResult onMethodCancel:methodName];
    }
}

- (id)performeNewSelector:(NSString*)methodName withParams:(NSArray*)params target:(id)target {
    NSUInteger paramCount = params.count;
    int signatureDefaultArgsNum = 2;
    NSMethodSignature* signature;
    SEL selector = nullptr;

    if (params.count == 0) {
        selector = NSSelectorFromString(methodName);
        signature = [target methodSignatureForSelector:selector];
    } else {
        Class currentClass = [target class];
        while (currentClass && currentClass != [BridgePlugin class] && currentClass != [NSObject class]) {
            unsigned int methodCount;
            Method* methodList = class_copyMethodList(currentClass, &methodCount);
            for (int i = 0; i < methodCount; i++) {
                Method method = methodList[i];
                SEL c_sel = method_getName(method);
                const char* name = sel_getName(c_sel);
                if (![methodName hasSuffix:@":"]) {
                    methodName = [methodName stringByAppendingString:@":"];
                }
                const char* c_methodname = [methodName UTF8String];
                signature = [target methodSignatureForSelector:c_sel];
                if (signature && !strncmp(name, c_methodname, strlen(c_methodname))) {
                    selector = c_sel;
                    break;
                }
            }
            free(methodList);
            currentClass = selector ? [NSObject class] : class_getSuperclass(currentClass);
        }
    }

    return [self handleMethodParam:signature target:target selector:selector params:params];
}

BOOL isNumberTypeMatch(id argument, const char *argumentType) {
    if (![argument isKindOfClass:[NSNumber class]]) {
        return NO;
    }
    const char* numberType = [argument objCType];
    if (strcmp(numberType, "c") == 0 && strcmp(argumentType, "B") == 0) {
        return YES;
    }
    return strcmp(argumentType, numberType) == 0;
}

- (id)handleMethodParam:(NSMethodSignature*)signature
                target:(id)target
                selector:(SEL)selector
                params:(NSArray*)params {
    int signatureDefaultArgsNum = 2;
    if (!signature || selector == nullptr) {
        NSLog(@"signature nil");
        return @{@"errorCode": @(BRIDGE_METHOD_UNIMPL), @"errorMessage": BRIDGE_METHOD_UNIMPL_MESSAGE};
    }
    NSInteger paramsCount = signature.numberOfArguments - signatureDefaultArgsNum;
    if (paramsCount != params.count) {
        NSLog(@"params count error");
        return @{@"errorCode": @(BRIDGE_METHOD_PARAM_ERROR), @"errorMessage": BRIDGE_METHOD_PARAM_ERROR_MESSAGE};
    }

    NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = target;
    invocation.selector = selector;
    if (params.count > 0) {
        if ([params containsObject:[NSNull null]]) {
            return @{@"errorCode": @(BRIDGE_METHOD_PARAM_ERROR),
                     @"errorMessage": BRIDGE_METHOD_PARAM_ERROR_MESSAGE};
        }
        id err = [self bridgeFillInvocationParams:params
                                        signature:signature
                                       invocation:invocation
                                       startIndex:signatureDefaultArgsNum];
        if (err) {
            return err;
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

- (id)bridgeFillInvocationParams:(NSArray*)params
                       signature:(NSMethodSignature*)signature
                      invocation:(NSInvocation*)invocation
                      startIndex:(int)signatureDefaultArgsNum {
    NSInteger paramsCount = signature.numberOfArguments - signatureDefaultArgsNum;
    for (int i = 0; i < paramsCount; i++) {
        id argument = params[i];
        if (argument == [NSNull null]) {
            return
                @{ @"errorCode" : @(BRIDGE_METHOD_PARAM_ERROR), @"errorMessage" : BRIDGE_METHOD_PARAM_ERROR_MESSAGE };
        }
        const char* argumentType = [signature getArgumentTypeAtIndex:i + signatureDefaultArgsNum];
        if (!strcmp(argumentType, @encode(id))) {
            [invocation setArgument:&argument atIndex:i + signatureDefaultArgsNum];
        } else if ([argument isKindOfClass:[NSNumber class]]) {
            if (!isNumberTypeMatch(argument, argumentType)) {
                return @{
                    @"errorCode" : @(BRIDGE_METHOD_PARAM_ERROR),
                    @"errorMessage" : BRIDGE_METHOD_PARAM_ERROR_MESSAGE
                };
            }
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
            } else if (!strcmp(argumentType, @encode(double))) {
                double arg = [argument doubleValue];
                [invocation setArgument:&arg atIndex:i + signatureDefaultArgsNum];
            } else {
                return @{
                    @"errorCode" : @(BRIDGE_METHOD_PARAM_ERROR),
                    @"errorMessage" : BRIDGE_METHOD_PARAM_ERROR_MESSAGE
                };
            }
        } else {
            return
                @{ @"errorCode" : @(BRIDGE_METHOD_PARAM_ERROR), @"errorMessage" : BRIDGE_METHOD_PARAM_ERROR_MESSAGE };
        }
    }
    return nil;
}

- (id)handleReturnValue:(NSMethodSignature*)signature
            invocation:(NSInvocation*)invocation {
    const char* returnType = signature.methodReturnType;
    if (!strcmp(returnType, @encode(void))) {
        NSLog(@"no returnValue");
        return nil;
    } else if (!strcmp(returnType, @encode(id))) {
        void* returnValue;
        [invocation getReturnValue:&returnValue];
        id obj = (__bridge id)returnValue;
        if ([obj isKindOfClass:NSString.class]) {
            return (NSString*)obj;
        } else {
            if (self.type == JSON_TYPE) {
                NSString* objString = [JsonHelper jsonStringWithObject:obj];
                return objString;
            } else {
                return obj;
            }
        }
    } else {
        void* returnValue = (void*)malloc(signature.methodReturnLength);
        [invocation getReturnValue:returnValue];
        id result = nil;
        if (!strcmp(returnType, @encode(BOOL))) {
            result = [NSNumber numberWithBool:*((BOOL*)returnValue)];
        } else if (!strcmp(returnType, @encode(int))) {
            result = [NSNumber numberWithInt:*((int*)returnValue)];
        } else if (!strcmp(returnType, @encode(float))) {
            result = [NSNumber numberWithFloat:*((float*)returnValue)];
        } else if (!strcmp(returnType, @encode(long))) {
            result = [NSNumber numberWithLong:*((long*)returnValue)];
        } else if (!strcmp(returnType, @encode(double))) {
            result = [NSNumber numberWithDouble:*((double*)returnValue)];
        }
        free(returnValue);

        if (self.type == JSON_TYPE) {
            NSString* valueString = [NSString stringWithFormat:@"%@", result];
            return (NSString*)valueString;
        } else {
            return result;
        }
    }
}

- (void)callPlatformError:(ResultValue*)object {
    if (self.methodResult &&
        [self.methodResult respondsToSelector:@selector(onError:errorCode:errorMessage:)]) {
        if (object.errorCode > 0) {
            [self.methodResult onError:object.methodName
                            errorCode:object.errorCode
                            errorMessage:object.errorMessage];
        }
    }
}

@end