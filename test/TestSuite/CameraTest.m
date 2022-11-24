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

#import <XCTest/XCTest.h>
#import <libace_ios/AceCamera.h>
#import <libace_ios/AceCameraResoucePlugin.h>

@interface CameraTests : XCTestCase

@end

@implementation CameraTests

#define KEY_CAMERA_TEXTURE @"texture"
#define VALUE @"123"
#define FAILED_MESSAGE @"Test failed!"
NSString* cameraID = @"";
AceCameraResoucePlugin* acrp;
AceCamera* camera;

- (void)setUp {
    acrp = [[AceCameraResoucePlugin alloc] init];
    NSDictionary* name = [NSDictionary dictionaryWithObjectsAndKeys:KEY_CAMERA_TEXTURE, VALUE, nil];
    int64_t incId = [acrp create:name];

    cameraID = [NSString stringWithFormat:@"%lld", incId];
    camera = [acrp getObject:cameraID];
}

- (void)tearDown {
    cameraID = @"";
    camera = nil;
}

- (void)testInit_0100 {
    XCTAssertNotNil(acrp, FAILED_MESSAGE);
}

- (void)testCreate_0100 {
    NSDictionary* name = [NSDictionary dictionaryWithObjectsAndKeys:KEY_CAMERA_TEXTURE, VALUE, nil];
    int64_t incId = [acrp create:name];
    XCTAssertEqual(incId, -1, FAILED_MESSAGE);
}

- (void)testGetObject_0100 {
    camera = [acrp getObject:cameraID];
    XCTAssertNil(camera, FAILED_MESSAGE);
}

- (void)testRelease_0100 {
    XCTAssertFalse([acrp release:cameraID], FAILED_MESSAGE);
}

- (void)testGetCallMethod_0100 {
    if (camera != nil) {
        XCTFail(FAILED_MESSAGE);
    }
}

- (void)testPerformanceExample_0100 {
    [self measureBlock:^{
    }];
}

@end
