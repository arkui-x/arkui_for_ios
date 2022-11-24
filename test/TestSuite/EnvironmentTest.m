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
#import <libace_ios/ace_environment_test.h>

@interface EnvironmentTest : XCTestCase

@end

@implementation EnvironmentTest
#define FAILED_MESSAGE @"Test failed!"
- (void)setUp {
}

- (void)tearDown {
}

- (void)testInitEnvironment_0100 {
    bool result = [AceEnvironmentTest testInitEnvironment];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

- (void)testGetAccessibilityEnabled_0100 {
    bool result = [AceEnvironmentTest testGetAccessibilityEnabled];
    XCTAssertTrue(result, FAILED_MESSAGE);
}

@end
