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

#import "BridgeJsonCodec.h"

NSString* const ResponseErrorCode = @"errorCode";
NSString* const ResponseErrorMessage = @"errormessage";
NSString* const ResponseResult = @"result";

@implementation JsonHelper
+ (id)objectWithJSONString:(NSString*)jsonString {
    if (!jsonString.length) {
        NSLog(@"no jsonString");
        return nil;
    }
    NSData* jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError* error;
    id jsonObj = [NSJSONSerialization JSONObjectWithData:jsonData
                                                 options:NSJSONReadingMutableContainers
                                                   error:&error];
    if (error) {
        NSLog(@"json -> objct faild, error : %@", error);
        return nil;
    }

    return jsonObj;
}

+ (NSString*)jsonStringWithObject:(id)object {
    if (![NSJSONSerialization isValidJSONObject:object]) {
        NSLog(@"objct -> json faild, object is not valid");
        return nil;
    }

    NSError* error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:object
                                                       options:kNilOptions
                                                         error:&error];

    NSString* json = [[NSString alloc] initWithData:jsonData
                                           encoding:NSUTF8StringEncoding];
    if (error) {
        NSLog(@"objc -> json faild, error: %@", error);
        return nil;
    }
    return json;
}
@end

@implementation RawValue

- (instancetype)init {
    self = [super init];
    if (self) {
        self.errorCode = -1;
    }
    return self;
}

- (instancetype)initWithResult:(NSString*)result
                     errorCode:(int)errorCode
                  errorMessage:(NSString*)errorMessage {
    self = [super init];
    if (self) {
        self.result = result;
        self.errorCode = errorCode;
        self.errorMessage = errorMessage;
    }
    return self;
}

+ (RawValue*)rawValueRresult:(id)result
                   errorCode:(int)errorCode
                errorMessage:(NSString*)errorMessage {
    return [[RawValue alloc] initWithResult:result errorCode:errorCode errorMessage:errorMessage];
}

+ (RawValue*)resultErrorCode:(int)errorCode
                errorMessage:(NSString* _Nullable)errorMessage {
    return [[RawValue alloc] initWithResult:nil errorCode:errorCode errorMessage:errorMessage];
}

+ (RawValue*)rawValueResult:(id)result
                  errorCode:(int)errorCode {
    return [[RawValue alloc] initWithResult:result errorCode:errorCode errorMessage:nil];
}

@end

@implementation BridgeJsonCodec

+ (instancetype)sharedInstance {
    static BridgeJsonCodec* _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[BridgeJsonCodec alloc] init];
    });
    return _sharedInstance;
}

- (NSString*)encode:(RawValue*)message {
    NSMutableDictionary* jsonDict = [NSMutableDictionary dictionary];

    if (message.result) {
        jsonDict[ResponseResult] = message.result;
    }

    if (message.errorCode != -1) {
        jsonDict[ResponseErrorCode] = @(message.errorCode);
    }

    if (message.errorMessage.length > 0) {
        jsonDict[ResponseErrorMessage] = message.errorMessage;
    }

    NSString* jsonString = [JsonHelper jsonStringWithObject:jsonDict];
    return jsonString;
}

- (RawValue*)decode:(NSString*)message {
    NSDictionary* jsonDict = [JsonHelper objectWithJSONString:message];

    NSString* result = jsonDict[ResponseResult];
    int errorCode = [jsonDict[ResponseErrorCode] intValue];
    NSString* errorMessage = jsonDict[ResponseErrorMessage];

    RawValue* resultValue = [RawValue rawValueRresult:result
                                            errorCode:errorCode
                                         errorMessage:errorMessage];

    return resultValue;
}

@end