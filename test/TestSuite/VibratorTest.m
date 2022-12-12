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
#import <libace_ios/ace_vibrator_test.h>

@interface VibratorTest : XCTestCase

@end

@implementation VibratorTest
#define FAILED_MESSAGE @"Test failed!"
- (void)setUp {
}

- (void)tearDown {
}

- (void)testInitVibratorTest_0100 {
    bool result = [AceVibratorTest testInitVibrator];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testVibrateInt_0100 {
    bool result = [AceVibratorTest testVibrateInt];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testVibrateString_0100 {
    bool result = [AceVibratorTest testVibrateString];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

@end
