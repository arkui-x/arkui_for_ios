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
 
#import "ResultValue.h"

NSString *const BRIDGE_ERROR_NO_MESSAGE = @"Correct!";
NSString *const BRIDGE_NAME_ERROR_MESSAGE = @"Bridge name error!";
NSString *const BRIDGE_CREATE_ERROR_MESSAGE = @"Bridge creation failure!";
NSString *const BRIDGE_INVALID_MESSAGE = @"Bridge unavailable!";
NSString *const BRIDGE_METHOD_NAME_ERROR_MESSAGE = @"Method name error!";
NSString *const BRIDGE_METHOD_RUNNING_MESSAGE = @"Method is running...";
NSString *const BRIDGE_METHOD_UNIMPL_MESSAGE = @"Method not implemented!";
NSString *const BRIDGE_METHOD_PARAM_ERROR_MESSAGE = @"Method parameter error!";
NSString *const BRIDGE_METHOD_EXISTS_MESSAGE = @"Method already exists!";
NSString *const BRIDGE_DATA_ERROR_MESSAGE= @"Data error!";
NSString *const BRIDGE_BOTTOM_COMMUNICATION_ERROR_MESSAGE = @"Bottom Communication error!";
NSString *const BRIDGE_END_MESSAGE = @"Bridge end!";

@implementation ResultValue

- (instancetype)initWithMethodName:(NSString *)methodName
                            result:(NSString *)result
                         errorCode:(ErrorCode)errorCode
                      errorMessage:(NSString *)errorMessage {
    self = [super init];
    if (self) {
        self.methodName = methodName;
        self.result = result;
        self.errorCode = errorCode;
        self.errorMessage = errorMessage;
    }
    return self;
}

@end
