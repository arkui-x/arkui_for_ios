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
#import <libace_ios/BridgePlugin.h>
#import <libace_ios/Ace.h>
#import <libace_ios/BridgePluginManager.h>
#import <libace_ios/BridgePlugin+jsMessage.h>
#import <libace_ios/MethodData.h>
#import <libace_ios/ParameterHelper.h>
#import <libace_ios/ResultValue.h>

#import "ace_bridge_test.h"

@interface BridgePluginTest : XCTestCase<IAceMessageListener, IAceMethodResult> {
    BridgePlugin *_plugin;
    BridgePluginManager *_manager;
    MethodData *_methodData;
    ResultValue *_resultValue;
    id _mock;
}

@end

@implementation BridgePluginTest
#define BRIDGENAME @"testchannel"
#define INSTANCEID 1
#define FAILED_MESSAGE @"FAILED!"
#define METHODNAME @"func"
#define ERRORCODE 1
#define ERRORMESSAGE @"error message"

- (BOOL)func {
    return YES;
}

#pragma mark - IAceMessageListener
- (id)onMessage:(id)data {
    return nil;
}

- (void)onMessageResponse:(id)data {
}

#pragma mark - IAceMethodResult
- (void)onSuccess:(NSString *)methodName
    resultValue:(id)resultValue {
}

- (void)onError:(NSString *)methodName
      errorCode:(ErrorCode)errorCode
   errorMessage:(NSString *)errorMessage {
}

#pragma mark - test case

- (void)setUp {
    _mock = [[NSObject alloc] init];
    _plugin = [[BridgePlugin alloc] initBridgePlugin:BRIDGENAME instanceId:INSTANCEID];
    _plugin.methodResult = self;
    _plugin.messageListener = self;
    _manager = [BridgePluginManager shareManager];
    _methodData = [[MethodData alloc] initMethodWithName:METHODNAME parameter:nil];
    _resultValue = [[ResultValue alloc] initWithMethodName:METHODNAME
        result:@"" errorCode:ERRORCODE errorMessage:ERRORMESSAGE];
}

- (void)tearDown {
}

- (void)testInitBridgePlugin_0100 {
    XCTAssertNotNil(_plugin, FAILED_MESSAGE);
}

- (void)testGetBridgeName_0200 {
    XCTAssertNotNil(_plugin.bridgeName, FAILED_MESSAGE);
}

- (void)testGetInstanceId_0300 {
    XCTAssertGreaterThan(_plugin.instanceId, 0, FAILED_MESSAGE);
}

- (void)testGetMethodResult_0400 {
    XCTAssertNotNil(_plugin.methodResult, FAILED_MESSAGE);
}

- (void)testGetMessageListener_0500 {
    XCTAssertNotNil(_plugin.messageListener, FAILED_MESSAGE);
}

- (void)testCallMethodError_0600 {
    XCTAssertTrue([_plugin.methodResult respondsToSelector:@selector(onError:errorCode:errorMessage:)],
        FAILED_MESSAGE);
}

- (void)testCallMethodSuccess_0700  {
    XCTAssertTrue([_plugin.methodResult respondsToSelector:@selector(onSuccess:resultValue:)], FAILED_MESSAGE);
}

- (void)testSendMessage_0800 {
    XCTAssertTrue([_plugin.messageListener respondsToSelector:@selector(onMessage:)], FAILED_MESSAGE);
}

- (void)testOnMessageResponse_0900 {
    XCTAssertTrue([_plugin.methodResult respondsToSelector:@selector(onMessageResponse:)], FAILED_MESSAGE);
}

- (void)testPluginCallMethod_1000 {
    XCTAssertNoThrow([_plugin callMethod:_methodData], FAILED_MESSAGE);
}

- (void)testPluginSendMessage_1100 {
    NSNull * _null = [NSNull null];
    XCTAssertNoThrow([_plugin sendMessage:_null], FAILED_MESSAGE);
}

- (void)testPluginJsCallMethod_1200 {
    XCTAssertNoThrow([_plugin jsCallMethod:_methodData], FAILED_MESSAGE);
}

- (void)testPluginJsSendMessage_1300 {
    XCTAssertNoThrow([_plugin jsSendMessage:@""], FAILED_MESSAGE);
}

- (void)testPluginJsSendMethodResult_1400 {
    XCTAssertNoThrow([_plugin jsSendMethodResult:_resultValue], FAILED_MESSAGE);
}

- (void)testPluginJsSendMessageResponse_1500 {
    XCTAssertNoThrow([_plugin jsSendMessageResponse:@""], FAILED_MESSAGE);
}

- (void)testShareManagerIsSingle_1600 {
    NSMutableArray *managers = [NSMutableArray array];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BridgePluginManager *tempManager = [[BridgePluginManager alloc] init];
        [managers addObject:tempManager];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BridgePluginManager *tempManager = [[BridgePluginManager alloc] init];
        [managers addObject:tempManager];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BridgePluginManager *tempManager = [BridgePluginManager shareManager];
        [managers addObject:tempManager];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BridgePluginManager *tempManager = [BridgePluginManager shareManager];
        [managers addObject:tempManager];
    });
    
    BridgePluginManager *managerOne = [BridgePluginManager shareManager];
    [managers enumerateObjectsUsingBlock:^(BridgePluginManager *obj, NSUInteger idx, BOOL *_Nonnull stop) {
        XCTAssertEqual(managerOne, obj, FAILED_MESSAGE);
    }];
}

- (void)testShareManager_1700 {
    XCTAssertNotNil(_manager, FAILED_MESSAGE);
}

- (void)testManagerRegistPlugin_1800 {
    BOOL flag = [_manager registerBridgePlugin:BRIDGENAME bridgePlugin:_plugin];
    XCTAssertTrue(flag, FAILED_MESSAGE);
}

- (void)testManagerUnRegistPlugin_1900 {
    [_manager UnRegisterBridgePlugin:BRIDGENAME];
}

- (void)testManagerJsCallMethod_2000 {
    XCTAssertNoThrow([_manager jsCallMethod:BRIDGENAME methodName:METHODNAME param:nil], FAILED_MESSAGE);
}

- (void)testManagerJsSendMethodResult_2100 {
    XCTAssertNoThrow([_manager jsSendMethodResult:BRIDGENAME methodName:METHODNAME result:@""], FAILED_MESSAGE);
}

- (void)testManagerJsSendMessage_2200 {
    XCTAssertNoThrow([_manager jsSendMessage:BRIDGENAME data:@""], FAILED_MESSAGE);
}

- (void)testManagerJsSendMessageResponse_2300 {
    XCTAssertNoThrow([_manager jsSendMessageResponse:BRIDGENAME data:@""], FAILED_MESSAGE);
}

- (void)testInitMethodData_2400 {
    XCTAssertNotNil(_methodData, FAILED_MESSAGE);
}

- (void)testGetMethodName_2500 {
    XCTAssertNotNil(_methodData.methodName, FAILED_MESSAGE);
}

- (void)testGetParameter_2600 {
    XCTAssertEqualObjects(_methodData.parameter, nil, FAILED_MESSAGE);
}

- (void)testObjectWithJSONString_2700 {
    id obj = [AceParameterHelper objectWithJSONString:@"{\"qqq\":\"www\"}"];
    XCTAssertTrue([obj isEqualToDictionary:@{@"qqq":@"www"}], FAILED_MESSAGE);
}

- (void)testJSONStringWithObjct_2800 {
    NSString *string = [AceParameterHelper jsonStringWithObject:@{@"qqq":@"www"}];
    XCTAssertTrue([string isEqualToString:@"{\"qqq\":\"www\"}"],FAILED_MESSAGE);
}

- (void)testResultValueInit_2900 {
    XCTAssertNotNil(_resultValue, FAILED_MESSAGE);
}

- (void)testGetResultValueMethodName_3000 {
    XCTAssertEqualObjects(_resultValue.methodName, METHODNAME, FAILED_MESSAGE);
}

- (void)testGetResultValueResult_3100 {
    XCTAssertEqualObjects(_resultValue.result, @"", FAILED_MESSAGE);
}

- (void)testGetResultValueErrorCode_3200 {
    XCTAssertTrue(_resultValue.errorCode == 1, FAILED_MESSAGE);
}

- (void)testGetResultValueErrorMessage_3300 {
    XCTAssertEqualObjects(_resultValue.errorMessage, @"error message", FAILED_MESSAGE);
}

- (void)testExample {
}

- (void)testPerformanceExample {
    [self measureBlock:^{

    }];
}
@end
