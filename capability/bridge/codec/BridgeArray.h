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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Type of array data items encoded in a `BridgeArrayType`.
 *
 * - BridgeArrayTypeBooL: bool list  `NSNumber numberWithBool:`
 * - BridgeArrayTypeInt32: 32-bit signed list `NSNumber numberWithInt:`
 * - BridgeArrayTypeInt64: 64-bit signed list `NSNumber numberWithInt:
 * - BridgeArrayTypeDouble: double list  `NSNumber numberWithDouble:`
 * - BridgeArrayTypeString: NSString list `NSString`
 */
typedef enum {
    BridgeArrayTypeBooL = 1,
    BridgeArrayTypeInt32,
    BridgeArrayTypeInt64,
    BridgeArrayTypeDouble,
    BridgeArrayTypeString,
} BridgeArrayType;

@interface BridgeArray : NSObject

/**
 * Initializes this BridgeArray. 
 * Using BINARY_ TYPE encode, when sending an array of a specified type, 
 * the array needs to be converted to the BridgeArray class
 * BridgeArrayTypeBooL、BridgeArrayTypeInt32、BridgeArrayTypeInt64、BridgeArrayTypeDouble、
 * The above four types need to be converted to an NSNumber array
 * 
 * @param bridgeArray array
 * @param type BridgeArrayType.
 * @since 11
 */
+ (instancetype)bridgeArray:(NSArray*)array type:(BridgeArrayType)type;

/**
 * The type of the encoded array.
 * @since 11
 */
@property (readonly, nonatomic, assign) BridgeArrayType arrayType;

/**
 * Get array
 * @since 11
 */
@property (readonly, nonatomic) NSArray* array;

@end

NS_ASSUME_NONNULL_END