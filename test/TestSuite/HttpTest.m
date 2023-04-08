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

#import "http_ios_request.h"

static NSUInteger const ERRORDATA = 3;
static NSUInteger const FAILED = 404;
static NSUInteger const HUNDRED = 100;
static NSUInteger const SUCCESS = 200;
static NSUInteger const TESTTIMEOUT = 10;
static NSUInteger const TWENTY = 20;
static NSUInteger const ZERO = 0;

@interface http_ios_request_test : XCTestCase
@property (nonatomic, strong) http_ios_request* request;
@property (nonatomic, copy) NSString* baseUrl;
@end

@implementation http_ios_request_test

- (void)setUp {
    self.request = [[http_ios_request alloc] init];
    self.baseUrl = @"https://httpbin.org";
}

- (void)tearDown {
    [super tearDown];
    self.request = nil;
}

- (void)testDeInitialize {
    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task, NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
    }];
    [self.request deInitialize];
    XCTAssertNil(self.request.responseBlock);
}

#pragma mark -  handler

- (void)testThatCompletionHandlerWithResponseObjectOnSuccess {
    __block id blockResponseObject = nil;
    __block id blockError = nil;
    XCTestExpectation* expectation = [self expectationWithDescription:@"Request should succeed"];
    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = self.baseUrl;
    requestParam.method = @"GET";

    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task,NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        blockResponseObject = response;
        [expectation fulfill];
    }];

    [self.request setFailBlock:^(NSInteger errorCode, NSString* _Nonnull errorMessage, void* _Nonnull userData) {
        blockError = errorMessage;
        [expectation fulfill];
    }];

    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:TESTTIMEOUT handler:nil];

    XCTAssertNil(blockError);
    XCTAssertNotNil(blockResponseObject);
}

- (void)testThatFailureCompletionBlockWithErrorOnFailure {
    __block id blockError = nil;
    __block NSInteger code = ZERO;
    XCTestExpectation* expectation = [self expectationWithDescription:@"Request should succeed"];

    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = @"bad.com";
    requestParam.method = @"GET";

    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task,NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        [expectation fulfill];
    }];

    [self.request setFailBlock:^(NSInteger errorCode, NSString* _Nonnull errorMessage, void* _Nonnull userData) {
        blockError = errorMessage;
        code = errorCode;
        [expectation fulfill];
    }];

    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:TESTTIMEOUT handler:nil];

    XCTAssertNotNil(blockError);
    XCTAssertEqual(code, ERRORDATA);
}

- (void)testThatCompletionWithRedirectionBlock {
    __block BOOL success;
    __block id blockError = nil;

    XCTestExpectation* expectation = [self expectationWithDescription:@"Request should succeed"];
    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = @"https://httpbingo.org/redirect/1";
    requestParam.method = @"POST";

    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task,NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        [expectation fulfill];
    }];

    [self.request setFailBlock:^(NSInteger errorCode, NSString* _Nonnull errorMessage, void* _Nonnull userData) {
        blockError = errorMessage;
        [expectation fulfill];
    }];

    [self.request setRedirectionBlock:^NSURLRequest* _Nullable(NSURLSession* _Nonnull session,
        NSURLSessionTask* _Nonnull task, NSURLResponse* _Nonnull response, NSURLRequest* _Nonnull request) {
        if (response) {
            success = YES;
        }
        return request;
    }];
    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:TESTTIMEOUT handler:nil];

    XCTAssertNil(blockError);
    XCTAssertTrue(success);
}

- (void)testThatCompletionWithHeadAndBodyBlock {
    __block BOOL headSuccess;
    __block BOOL bodySuccess;

    XCTestExpectation* expectation = [self expectationWithDescription:@"Request should succeed"];

    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = self.baseUrl;
    requestParam.method = @"GET";

    [self.request setMemoryHeaderBlock:^(NSDictionary* _Nonnull headers, void* _Nonnull userData) {
        if(headers) {
            headSuccess = true;
        }
    }];

    [self.request setMemoryBodyBlock:^(NSData* _Nonnull data, void* _Nonnull userData) {
        bodySuccess = true;
    }];

    [self.request setFailBlock:^(NSInteger errorCode, NSString* _Nonnull errorMessage, void* _Nonnull userData) {
        [expectation fulfill];
    }];
    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task, NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        [expectation fulfill];
    }];

    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:TESTTIMEOUT handler:nil];

    XCTAssertTrue(headSuccess);
    XCTAssertTrue(bodySuccess);
}

- (void)testThatCompletionWithProgressBlock {
    __block BOOL upProgress;
    __block BOOL dnProgress;

    __weak XCTestExpectation* expectation = [self expectationWithDescription:@"Progress Should equal 1.0"];

    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = self.baseUrl;
    requestParam.method = @"POST";
    requestParam.bodyParam = @{@"key":@"value"};

    [self.request setUploadProgress:^(void* _Nonnull userData, long total, long now) {
        if(total == now) {
            upProgress = true;
        }
    }];
    [self.request setDownloadProgress:^(void* _Nonnull userData, long total, long now) {
        if(total == now) {
            dnProgress = true;
        }
    }];

    [self.request setFailBlock:^(NSInteger errorCode, NSString* _Nonnull errorMessage, void* _Nonnull userData) {
        [expectation fulfill];
    }];
    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task, NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        [expectation fulfill];
    }];

    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:TESTTIMEOUT handler:nil];
    
    XCTAssertTrue(upProgress);
    XCTAssertTrue(dnProgress);
}

#pragma mark -  test param

- (void)testSettingHTTPHeadersRequest {
    XCTestExpectation* expectation = [self expectationWithDescription:@"Request should succeed"];

    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = @"https://www.baidu.com";
    requestParam.method = @"GET";
    requestParam.headerJson = @{@"TestHttp":@"T"};

    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task,NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        XCTAssertTrue([task.originalRequest.allHTTPHeaderFields[@"TestHttp"] isEqualToString:@"T"]);
        NSLog(@"%@",task.originalRequest.allHTTPHeaderFields);
        [expectation fulfill];
    }];

    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:TESTTIMEOUT handler:nil];
}

- (void)testSettingHTTPBodyParamRequest {
    XCTestExpectation* expectation = [self expectationWithDescription:@"Request should succeed"];

    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = [NSString stringWithFormat:@"%@/post", self.baseUrl];
    requestParam.method = @"POST";
    requestParam.bodyParam = @{@"key":@"value"};

    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task,NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        NSDictionary* dict1= [NSJSONSerialization JSONObjectWithData:data options:ZERO error:nil];
        XCTAssertTrue([dict1[@"form"][@"key"] isEqualToString:@"value"]);
        [expectation fulfill];
    }];

    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:TESTTIMEOUT handler:nil];
}

- (void)testSettingHTTPJsonStringBodyParamRequest {
    XCTestExpectation* expectation = [self expectationWithDescription:@"Request should succeed"];

    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = [NSString stringWithFormat:@"%@/post", self.baseUrl];
    requestParam.method = @"POST";
    requestParam.bodyParam = @"{\"name\" : \"test\"}";

    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task,NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        NSDictionary* dict1= [NSJSONSerialization JSONObjectWithData:data options:ZERO error:nil];
        XCTAssertTrue([dict1[@"form"][@"name"] isEqualToString:@"test"]);
        [expectation fulfill];
    }];

    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:TESTTIMEOUT handler:nil];
}
#pragma mark -  http https

# pragma mark - HTTP Status Codes
- (void)testThatStatue200 {
    XCTestExpectation* expectation = [self expectationWithDescription:@"Request should succeed"];
    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = [NSString stringWithFormat:@"%@/status/200", self.baseUrl];
    requestParam.method = @"GET";

    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task,NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        XCTAssertEqual(response.statusCode, SUCCESS);
        [expectation fulfill];
    }];

    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:HUNDRED handler:nil];
}

- (void)testThatStatue404 {
    XCTestExpectation* expectation = [self expectationWithDescription:@"Request should succeed"];
    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = [NSString stringWithFormat:@"%@/status/404", self.baseUrl];
    requestParam.method = @"GET";

    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task,NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        XCTAssertEqual(response.statusCode, FAILED);
        [expectation fulfill];
    }];

    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:TWENTY handler:nil];
}

#pragma mark - Method

- (void)testGET {
    XCTestExpectation* expectation = [self expectationWithDescription:@"Request should succeed"];

    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = self.baseUrl;
    requestParam.method = @"GET";

    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task,NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        [expectation fulfill];
    }];

    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:TESTTIMEOUT handler:nil];
}

- (void)testHEAD {
    XCTestExpectation* expectation = [self expectationWithDescription:@"Request should succeed"];

    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = self.baseUrl;
    requestParam.method = @"HEAD";

    [self.request setMemoryHeaderBlock:^(NSDictionary* _Nonnull headers, void* _Nonnull userData) {
        XCTAssertNotNil(headers);
    }];

    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task,NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        XCTAssertTrue(data.length == ZERO);
        [expectation fulfill];
    }];

    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:TESTTIMEOUT handler:nil];
}

- (void)testPOST {
    XCTestExpectation* expectation = [self expectationWithDescription:@"Request should succeed"];

    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = [NSString stringWithFormat:@"%@/post", self.baseUrl];
    requestParam.method = @"POST";
    requestParam.bodyParam = @{@"test":@"post"};

    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task,NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        NSDictionary* dict1= [NSJSONSerialization JSONObjectWithData:data options:ZERO error:nil];
        XCTAssertTrue([dict1[@"form"][@"test"] isEqualToString:@"post"]);
        [expectation fulfill];
    }];

    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:TESTTIMEOUT handler:nil];
}

- (void)testPUT {
    XCTestExpectation* expectation = [self expectationWithDescription:@"Request should succeed"];

    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = [NSString stringWithFormat:@"%@/put", self.baseUrl];
    requestParam.method = @"PUT";
    requestParam.bodyParam = @{@"key":@"value"};
    requestParam.headerJson = @{@"field":@"value"};

    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task,NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:data options:ZERO error:nil];
        XCTAssertTrue([task.originalRequest.allHTTPHeaderFields[@"field"] isEqualToString:@"value"]);
        XCTAssertTrue([dict[@"form"][@"key"] isEqualToString:@"value"]);
        [expectation fulfill];
    }];

    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:TESTTIMEOUT handler:nil];
}

- (void)testDELETE {
    XCTestExpectation* expectation = [self expectationWithDescription:@"Request should succeed"];

    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = [NSString stringWithFormat:@"%@/delete", self.baseUrl];
    requestParam.method = @"DELETE";
    requestParam.bodyParam = @{@"key":@"value"};
    requestParam.headerJson = @{@"field":@"value"};

    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task,NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:data options:ZERO error:nil];
        XCTAssertTrue([task.originalRequest.allHTTPHeaderFields[@"field"] isEqualToString:@"value"]);
        XCTAssertTrue([dict[@"args"][@"key"] isEqualToString:@"value"]);
        [expectation fulfill];
    }];

    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:TESTTIMEOUT handler:nil];
}

- (void)testPATCH {
    XCTestExpectation* expectation = [self expectationWithDescription:@"Request should succeed"];

    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = [NSString stringWithFormat:@"%@/patch", self.baseUrl];
    requestParam.method = @"PATCH";
    requestParam.bodyParam = @{@"key":@"value"};
    requestParam.headerJson = @{@"field":@"value"};

    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task,NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:data options:ZERO error:nil];
        XCTAssertTrue([task.originalRequest.allHTTPHeaderFields[@"field"] isEqualToString:@"value"]);
        XCTAssertTrue([dict[@"form"][@"key"] isEqualToString:@"value"]);
        [expectation fulfill];
    }];

    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:TESTTIMEOUT handler:nil];
}

- (void)testRootCredential {
    __block BOOL success;
    XCTestExpectation* expectation = [self expectationWithDescription:@"Request should succeed"];

    http_ios_param* requestParam = [[http_ios_param alloc] init];
    requestParam.urlPath = @"https://apple.com/";
    requestParam.method = @"POST";

    [self.request setResponseBlock:^(NSURLSessionTask* _Nonnull task, NSHTTPURLResponse* _Nullable response,
        NSData* _Nullable data, void* _Nonnull userData) {
        success = true;
        [expectation fulfill];
    }];

    [self.request sendRequestWith:requestParam];
    [self waitForExpectationsWithTimeout:TESTTIMEOUT handler:nil];

    XCTAssertTrue(success);
}

- (void)testRootCachePath {
    NSString* cachePath = [http_ios_request getBaseCachePath];
    bool success = [cachePath containsString:@"/cache.json"];
    XCTAssertTrue(success);
}
@end