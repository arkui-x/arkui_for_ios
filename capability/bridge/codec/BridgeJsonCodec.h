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

#ifndef FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_BridgeJsonCodec_H
#define FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_BridgeJsonCodec_H

#import "BridgeCodesDelegate.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString* const ResponseErrorCode;
FOUNDATION_EXPORT NSString* const ResponseErrorMessage;
FOUNDATION_EXPORT NSString* const ResponseResult;

@interface JsonHelper : NSObject
+ (id)objectWithJSONString:(NSString*)jsonString;
+ (NSString*)jsonStringWithObject:(id)object;
@end

@interface RawValue : NSObject
@property (nonatomic, strong) id result;
@property (nonatomic, assign) int errorCode;
@property (nonatomic, strong) NSString* errorMessage;

+ (RawValue*)rawValueRresult:(NSString*)result
            errorCode:(int)errorCode
            errorMessage:(NSString*)errorMessage;

+ (RawValue*)resultErrorCode:(int)errorCode
            errorMessage:(NSString* _Nullable)errorMessage;

+ (RawValue*)rawValueResult:(NSString*)result
            errorCode:(int)errorCode;
@end

@interface BridgeJsonCodec : NSObject <BridgeCodesDelegate>

@end

NS_ASSUME_NONNULL_END
#endif // FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_BridgeJsonCodec_H