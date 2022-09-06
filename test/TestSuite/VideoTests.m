//
//  VideoTests.m
//  VideoTests
//
//  Created by ZhangChuan on 2022/8/13.
//

#import <XCTest/XCTest.h>
#import <libace_ios/AceVideoResourcePlugin.h>

@interface VideoTests : XCTestCase

@end

@implementation VideoTests

#define KEY_TEXTURE @"texture"
#define VALUE @"123"
#define FAILED_MESSAGE @"测试未通过"

AceVideoResourcePlugin *avrp;
id player;
NSString *playerID = @"";

- (void)setUp {
    avrp = [[AceVideoResourcePlugin alloc] init];
    
    NSDictionary *name = [NSDictionary dictionaryWithObjectsAndKeys:KEY_TEXTURE, VALUE, nil];
    int64_t incId = [avrp create: name];
    
    playerID = [NSString stringWithFormat:@"%lld", incId];
    player = [avrp getObject: playerID];
}

- (void)tearDown {
    playerID = @"";
    player = nil;
}

- (void)testInit_0100 {
    XCTAssertNotNil(avrp, FAILED_MESSAGE);
}

- (void)testCreate_0100 {
    NSDictionary *name = [NSDictionary dictionaryWithObjectsAndKeys:KEY_TEXTURE, VALUE, nil];
    int64_t incId = [avrp create: name];
    XCTAssertNotEqual(incId, -1, FAILED_MESSAGE);
}

- (void)testGetObject_0100 {
    player = [avrp getObject: playerID];
    XCTAssertNotNil(player, FAILED_MESSAGE);
}

- (void)testRelease_0100 {
    XCTAssertTrue([avrp release:playerID], FAILED_MESSAGE);
}

- (void)testPerformance_0100 {
    [self measureBlock:^{
    }];
}

- (void)testGetCallMethod_0100 {
    if (player != nil) {
        XCTAssertNotNil([player getCallMethod], FAILED_MESSAGE);
    } else {
        XCTFail(FAILED_MESSAGE);
    }
}

- (void)testGetPixelBuffer_0100 {
    if (player != nil) {
        XCTAssertNotNil([player getPixelBuffer], FAILED_MESSAGE);
    } else {
        XCTFail(FAILED_MESSAGE);
    }
}

@end
