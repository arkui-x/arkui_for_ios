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

#import <libace_ios/iOSTxtInputManager.h>
#import <XCTest/XCTest.h>
#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>

@interface EditingTests : XCTestCase

@end

@implementation EditingTests

#define FAILED_MESSAGE @"Test failed!"
iOSTxtInputManager *inputManager;

- (void)setUp {
    inputManager = [iOSTxtInputManager shareintance];
}

- (void)tearDown {
    inputManager = nil;
}

- (void)testInit_0100 {
    XCTAssertNotNil(inputManager, FAILED_MESSAGE);
}

- (void)testTextInputView_0100 {
    UIView<UITextInput> *textInput = [inputManager textInputView];
    XCTAssertNotNil(textInput, FAILED_MESSAGE);
}

- (void)testShowTextInput_0100 {
    [inputManager showTextInput];
}

- (void)testHideTextInput_0100 {
    [inputManager hideTextInput];
}

- (void)testSetTextInputClient_0100 {
    NSDictionary *param = [NSDictionary new];
    [inputManager setTextInputClient:1 withConfiguration:param];
}

- (void)testClearTextInputClient_0100 {
    [inputManager clearTextInputClient];
}

- (void)testPerformanceExample_0100 {
    [self measureBlock:^{
    }];
}

@end
