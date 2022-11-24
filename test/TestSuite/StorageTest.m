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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <libace_ios/ace_storage_test.h>

@interface StorageTest : XCTestCase

@end

@implementation StorageTest
#define FAILED_MESSAGE @"Test failed!"
- (void)setUp {
}

- (void)tearDown {
}

- (void)testInitStorageTest_0100 {
    bool result = [AceStorageTest testInitStorage];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testString_0100 {
    bool result = [AceStorageTest testString];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testString_0200 {
    bool result = [AceStorageTest testIntString];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testString_0300 {
    bool result = [AceStorageTest testDoubleString];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testString_0400 {
    bool result = [AceStorageTest testSpecialCharactersString];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testString_0500 {
    bool result = [AceStorageTest testEmptyString];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testDouble_0100 {
    bool result = [AceStorageTest testDouble];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testDouble_0200 {
    bool result = [AceStorageTest testZeroDouble];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testBoolean_0100 {
    bool result = [AceStorageTest testBoolean];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testClear_0100 {
    bool result = [AceStorageTest testClear];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testDelete_0100 {
    bool result = [AceStorageTest testDelete];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

@end
