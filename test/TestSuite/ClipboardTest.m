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
#import <libace_ios/ace_clipboard_test.h>

@interface ClipboardTests : XCTestCase

@end

@implementation ClipboardTests
#define FAILED_MESSAGE @"Test failed!"
- (void)setUp {
}

- (void)tearDown{
}

- (void)testInitClipboard_0100 {
    bool result = [AceClipboardTest testInitClipboard];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testSetAndGet_0100 {
    bool result = [AceClipboardTest testStringSetAndGet];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testSetAndGet_0200 {
    bool result = [AceClipboardTest testIntSetAndGet];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testSetAndGet_0300 {
    bool result = [AceClipboardTest testDoubleSetAndGet];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testSetAndGet_0400 {
    bool result = [AceClipboardTest testSpecialCharactersSetAndGet];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testSetAndGet_0500 {
    bool result = [AceClipboardTest testCopyOptionsLocal];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testSetAndGet_0600 {
    bool result = [AceClipboardTest testCopyOptionsDistributed];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testSetAndGet_0700 {
    bool result = [AceClipboardTest testIsDragData];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testClear_0100 {
    bool result = [AceClipboardTest testClear];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

@end
