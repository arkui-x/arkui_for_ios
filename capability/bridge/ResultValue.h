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

#ifndef FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_ResultValue_H
#define FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_ResultValue_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : int {
    BRIDGE_ERROR_NO = 0,
    BRIDGE_NAME_ERROR,
    BRIDGE_CREATE_ERROR,
    BRIDGE_INVALID,
    BRIDGE_METHOD_NAME_ERROR,
    BRIDGE_METHOD_RUNNING,
    BRIDGE_METHOD_UNIMPL,
    BRIDGE_METHOD_PARAM_ERROR,
    BRIDGE_METHOD_EXISTS,
    BRIDGE_DATA_ERROR,
    BRIDGE_BOTTOM_COMMUNICATION_ERROR,
    BRIDGE_CODEC_TYPE_MISMATCH,
    BRIDGE_CODEC_INVALID,
    BRIDGE_END,
} ErrorCode;

extern NSString *const BRIDGE_ERROR_NO_MESSAGE;
extern NSString *const BRIDGE_NAME_ERROR_MESSAGE;
extern NSString *const BRIDGE_CREATE_ERROR_MESSAGE;
extern NSString *const BRIDGE_INVALID_MESSAGE;
extern NSString *const BRIDGE_METHOD_NAME_ERROR_MESSAGE;
extern NSString *const BRIDGE_METHOD_RUNNING_MESSAGE;
extern NSString *const BRIDGE_METHOD_UNIMPL_MESSAGE;
extern NSString *const BRIDGE_METHOD_PARAM_ERROR_MESSAGE;
extern NSString *const BRIDGE_METHOD_EXISTS_MESSAGE;
extern NSString *const BRIDGE_DATA_ERROR_MESSAGE;
extern NSString *const BRIDGE_BOTTOM_COMMUNICATION_ERROR_MESSAGE;
extern NSString *const BRIDGE_CODEC_TYPE_MISMATCH_MESSAGE;
extern NSString *const BRIDGE_CODEC_INVALID_MESSAGE;
extern NSString *const BRIDGE_END_MESSAGE;

extern NSString *const ResultValueError(ErrorCode type);

@interface ResultValue : NSObject

@property (nonatomic, strong) NSString *methodName;

@property (nonatomic, strong) NSString *result;

@property (nonatomic, assign) ErrorCode errorCode;

@property (nonatomic, strong) NSString *errorMessage;

- (instancetype)initWithMethodName:(NSString *)methodName
                            result:(NSString *)result
                         errorCode:(ErrorCode)errorCode
                      errorMessage:(NSString *)errorMessage;
@end

NS_ASSUME_NONNULL_END

#endif // FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_ResultValue_H