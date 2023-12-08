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

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "AceResourcePlugin.h"

@interface AceWeb : NSObject

-(instancetype)init:(int64_t)incId
             target:(UIViewController*)target
     onEvent:(IAceOnResourceEvent)callback
     abilityInstanceId:(int32_t)abilityInstanceId;
-(void)loadUrl:(NSString*)url header:(NSDictionary*)httpHeaders;
- (void)loadData:(NSString*)data
        mimeType:(NSString*)mimeType
        encoding:(NSString*)encoding
         baseUrl:(NSString*)baseUrl
      historyUrl:(NSString*)historyUrl;
- (NSString*)getUrl;
- (void)EvaluateJavaScript:(NSString*)script callback:(void (^)(NSString* ocResult))callback;
- (bool)accessBackward;
- (bool)accessForward;
- (void)backward;
- (void)forward;
- (void)refresh;
- (void)removeCache:(bool)value;
- (void)backOrForward:(NSInteger)step;
- (NSString*)getTitle;
- (CGFloat)getPageHeight;
- (void)createWebMessagePorts:(NSArray*)portsName;
- (void)postWebMessage:(NSString*)message port:(NSString*)port targetUrl:(NSString*)targetUrl;
- (void)postMessageEvent:(NSString*)message;
- (void)onMessageEvent:(void (^)(NSString* ocResult))callback;
- (void)closePort;
+ (bool)saveHttpAuthCredentials:(NSString*)host
                          realm:(NSString*)realm
                       username:(NSString*)username
                       password:(NSString*)password;
+ (NSURLCredential*)getHttpAuthCredentials:(NSString*)host realm:(NSString*)realm;
+ (bool)existHttpAuthCredentials;
+ (bool)deleteHttpAuthCredentials;
- (bool)accessStep:(NSInteger)step;
- (void)scrollTo:(CGFloat)x y:(CGFloat)y;
- (void)scrollBy:(CGFloat)deltaX deltaY:(CGFloat)deltaY;
- (void)zoom:(CGFloat)factor;
- (void)stop;
- (void)setCustomUserAgent:(NSString*)userAgent;
- (NSString*)getCustomUserAgent;
-(NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *)getSyncCallMethod;
-(void)releaseObject;
-(int64_t)getWebId;
-(WKWebView*)getWeb;
-(NSString*)updateWebLayout:(NSDictionary*) paramMap;
@end
