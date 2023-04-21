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

#import <XCTest/XCTest.h>
#import <libarkui_ios/AcePlatformPlugin.h>
#import <libarkui_ios/StageAssetManager.h>

@interface PlatformPluginTest : XCTestCase

@end

@implementation PlatformPluginTest

#define INSTANCEID 1
#define FAILED_MESSAGE @"Test failed!"

- (void)setUp {}

- (void)tearDown {}

/**
 * initPlatformPlugin
 */
- (void)testInitPlatformPlugin {
    NSString *bundleDirectory = [[StageAssetManager assetManager] getBundlePath];
    AcePlatformPlugin * plugin = [[AcePlatformPlugin alloc]
          initPlatformPlugin:self instanceId:INSTANCEID bundleDirectory:bundleDirectory];
    XCTAssertNotNil(plugin, FAILED_MESSAGE);

}

@end
