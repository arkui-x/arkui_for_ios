/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
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

#ifndef ACE_STORAGE_TEST_H
#define ACE_STORAGE_TEST_H

#import <Foundation/Foundation.h>

@interface AceStorageTest : NSObject

+ (bool)testInitStorage;
+ (bool)testString;
+ (bool)testIntString;
+ (bool)testDoubleString;
+ (bool)testSpecialCharactersString;
+ (bool)testEmptyString;
+ (bool)testDouble;
+ (bool)testZeroDouble;
+ (bool)testBoolean;
+ (bool)testClear;
+ (bool)testDelete;
@end

#endif // ACE_STORAGE_TEST_H