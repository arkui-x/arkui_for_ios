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

#import <libace_ios/AceResourceRegisterOC.h>
#import <libace_ios/AceVideoResourcePlugin.h>
#import <XCTest/XCTest.h>

@interface VideoTests : XCTestCase

@end

@implementation VideoTests

#define KEY_TEXTURE @"texture"
#define FAILED_MESSAGE @"Test failed!"
#define TAG @"5"

AceVideoResourcePlugin *aceVideoResourcePlugin;
NSString *incId = @"";

- (void)setUp {
}

- (void)tearDown {
}

- (void)testInitWithBundleDirectory_0100 {
    aceVideoResourcePlugin = [[AceVideoResourcePlugin alloc] init];
    aceVideoResourcePlugin = [aceVideoResourcePlugin initWithBundleDirectory:KEY_TEXTURE];
    XCTAssertNotNil(aceVideoResourcePlugin, FAILED_MESSAGE);
}

- (void)testCreate_0100 {
    aceVideoResourcePlugin.tag = TAG;
    [((AceResourceRegisterOC*)aceVideoResourcePlugin.resRegister) registerPlugin:aceVideoResourcePlugin];
    int64_t value = [
            ((AceResourceRegisterOC*)aceVideoResourcePlugin.resRegister) createResource:TAG param:@"AceVideo"];
    incId = [NSString stringWithFormat:@"%lld", value];
    [aceVideoResourcePlugin release:incId];
    XCTAssertNotEqual(value, -1, FAILED_MESSAGE);
}
@end
