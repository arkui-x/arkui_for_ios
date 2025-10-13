/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights reserved.
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

#import <WebKit/WebKit.h>
#import "AceWebInfoManager.h"

#define ARKUI_X_USER_AGENT @"ArkUIXDefaultUserAgent"
#define ARKUI_X_USER_AGENT_LAST_SYSTEM_VERSION @"ArkUIXUserAgentLastSystemVersion"

@interface AceWebInfoManager ()

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, copy) NSString *userAgent;
@property (nonatomic, copy) NSString *lastUpdateSystemVersion;

@end

@implementation AceWebInfoManager

+ (instancetype)sharedManager {
    static AceWebInfoManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AceWebInfoManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _userAgent = [[NSUserDefaults standardUserDefaults] stringForKey:ARKUI_X_USER_AGENT];
        _lastUpdateSystemVersion = [[NSUserDefaults standardUserDefaults] 
                                        stringForKey:ARKUI_X_USER_AGENT_LAST_SYSTEM_VERSION];
        [self.webView loadHTMLString:@"" baseURL:nil];
    }
    return self;
}

- (void)updateUserAgentIfNeeded {
    NSString *currentSystemVersion = [self systemVersion];
    if (!_lastUpdateSystemVersion || ![currentSystemVersion isEqualToString:_lastUpdateSystemVersion]) {
        [self getUserAgent];
    }
}

- (NSString *)systemVersion {
    return [[UIDevice currentDevice] systemVersion];
}

- (NSString *)getUserAgent {
    if (!_userAgent) {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [self refreshUserAgentWithCompletion:^{
            dispatch_semaphore_signal(semaphore);
        }];
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC));
    }
    return _userAgent ? _userAgent : [self fallbackUserAgent];
}

- (void)setUserAgent:(NSString *)userAgent {
    if (!userAgent || userAgent.length == 0) {
        return;
    }
    _userAgent = userAgent;
    _lastUpdateSystemVersion = [self systemVersion];
    [[NSUserDefaults standardUserDefaults] setObject:_userAgent forKey:ARKUI_X_USER_AGENT];
    [[NSUserDefaults standardUserDefaults] 
        setObject:_lastUpdateSystemVersion forKey:ARKUI_X_USER_AGENT_LAST_SYSTEM_VERSION];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)refreshUserAgentWithCompletion:(void (^)(void))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.webView evaluateJavaScript:@"window.location.href='about:blank';" completionHandler:nil];
        [self.webView evaluateJavaScript:@"navigator.userAgent" 
            completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error fetching UserAgent: %@", error.localizedDescription);
            } else {
                if ([result isKindOfClass:[NSString class]]) {
                    [self setUserAgent:[NSString stringWithFormat:@"%@", result]];
                }
            }
            if (completion) {
                completion();
            }
        }];
    });
}

- (WKWebView *)webView {
    if (!_webView) {
        _webView = [[WKWebView alloc] initWithFrame:CGRectZero];
    }
    return _webView;
}

- (NSString *)fallbackUserAgent {
    NSString *deviceModel = [[UIDevice currentDevice] model];
    NSString *osVersion = [self systemVersion];
    return [NSString stringWithFormat:
                @"Mozilla/5.0 (%@; CPU %@ OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
                deviceModel, deviceModel, [osVersion stringByReplacingOccurrencesOfString:@"." withString:@"_"]];
}

- (NSMutableSet<NSString *> *)authChallengeUseCredentials {
    if (!_authChallengeUseCredentials) {
        _authChallengeUseCredentials = [NSMutableSet set];
    }
    return _authChallengeUseCredentials;
}

@end
