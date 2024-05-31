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

#import "DownloadManager.h"
#include <vector>
#include <utility>

@interface DownloadManager()<NSURLSessionTaskDelegate>

@end

@implementation DownloadManager

+ (DownloadManager *)sharedManager
{
    static DownloadManager *managerInstance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        managerInstance = [[self alloc] init];
    });
    return managerInstance;
}

- (NSData *)download:(NSString*)urlStr
{
    NSLog(@"DownloadStart:%@",urlStr);
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setValue:@"plain/text;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"Ace" forHTTPHeaderField:@"User-Agent"];
    request.HTTPMethod = @"GET";
    request.timeoutInterval = 5000.0;

    NSURLSessionConfiguration* sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfig.HTTPShouldUsePipelining = true;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:nil];
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSData *newData = nil;
    NSURLSessionTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data,
        NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *newResponse  = (NSHTTPURLResponse*)response;
        int code = (int)[newResponse statusCode];
        if (!error && code == 200) {
            newData = [[NSData alloc] initWithBytes:data.bytes length:data.length];
        } else {
            NSLog(@"DownloadError:%@",error);
        }
        dispatch_semaphore_signal(semaphore);
    }];
    [task resume];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return newData;
}

#pragma mark --NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession*)session didReceiveChallenge:(NSURLAuthenticationChallenge*)challenge
    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential* _Nullable))completionHandler
{
    if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust) {
        NSURLCredential *credntial = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential,credntial);
    }
}

@end