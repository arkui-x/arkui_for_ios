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

#include <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <libace_ios/AceResourceRegisterOC.h>
#import <libace_ios/AceTextureResourcePlugin.h>

@interface TextureTest : XCTestCase

@end

@implementation TextureTest

#define KEY_TEXTURE @"texture"
#define FAILED_MESSAGE @"FAILED!"
#define TAG @"5"

AceTextureResourcePlugin* aceTextureResourcePlugin;
NSObject<FlutterTexture>* flutterTextureRegistry;

NSString* incTextureId = @"";

- (void)setUp {
}

- (void)tearDown {
}

- (void)testInitWithTextures_0100 {
    aceTextureResourcePlugin = [[AceTextureResourcePlugin alloc] init];
    aceTextureResourcePlugin = [aceTextureResourcePlugin initWithTextures:flutterTextureRegistry];
    XCTAssertNotNil(aceTextureResourcePlugin, FAILED_MESSAGE);
}

- (void)testCreate_0100 {
    aceTextureResourcePlugin.tag = TAG;
    [((AceResourceRegisterOC*)aceTextureResourcePlugin.resRegister) registerPlugin:aceTextureResourcePlugin];
    int64_t value =
        [((AceResourceRegisterOC*)aceTextureResourcePlugin.resRegister) createResource:TAG param:@"AceTexture"];
    incTextureId = [NSString stringWithFormat:@"%lld", value];
    [aceTextureResourcePlugin release:incTextureId];
    XCTAssertNotEqual(value, -1, FAILED_MESSAGE);
}

- (void)testCreate_0200 {
    aceTextureResourcePlugin = [[AceTextureResourcePlugin alloc] init];
    aceTextureResourcePlugin = [aceTextureResourcePlugin initWithTextures:flutterTextureRegistry];
    int64_t value = [aceTextureResourcePlugin create:nil];
    XCTAssertEqual(value, -1, FAILED_MESSAGE);
}

@end
