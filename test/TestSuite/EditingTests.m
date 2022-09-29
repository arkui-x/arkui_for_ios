//
//  EditingTests.m
//  iOS_TestHostTests
//
//  Created by ZhangChuan on 2022/8/15.
//

#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <libace_ios/iOSTextInputDelegate.h>
#import <libace_ios/iOSTxtInputManager.h>

@interface EditingTests : XCTestCase

@end

@implementation EditingTests

#define FAILED_MESSAGE @"测试未通过"
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
