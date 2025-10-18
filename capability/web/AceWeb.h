/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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
#include "scheme_handler/scheme_handler.h"

@interface AceWeb : NSObject

@property (nonatomic, assign) BOOL webScrollEnabled;

-(instancetype)init:(int64_t)incId
             target:(UIViewController*)target
     onEvent:(IAceOnResourceEvent)callback
     abilityInstanceId:(int32_t)abilityInstanceId;
-(instancetype)init:(int64_t)incId
        incognitoMode:(BOOL)incognitoMode
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
- (void)evaluateJavaScript:(NSString*)script callback:(void (^)(id _Nullable obj, NSError* _Nullable error))callback;
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
- (void)postMessageEventExt:(id)message;
- (void)onMessageEvent:(void (^)(NSString* ocResult))callback;
- (void)onMessageEventExt:(void (^)(id _Nullable ocResult))callback;
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
- (void)zoomIn;
- (void)zoomOut;
- (NSString*)getOriginalUrl;
- (void)pageUp:(bool)value;
- (bool)isZoomAccess;
- (void)setCustomUserAgent:(NSString*)userAgent;
- (NSString*)getCustomUserAgent;
-(NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *)getSyncCallMethod;
-(void)releaseObject;
-(int64_t)getWebId;
-(WKWebView*)getWeb;
-(NSString*)updateWebLayout:(NSDictionary*) paramMap;
+ (void)setWebDebuggingAccess:(bool)webDebuggingAccess;
- (void)pageDown:(bool)value;
- (void)postUrl:(NSString*)url postData:(NSData *)postData;
+ (BOOL)getWebDebuggingAccess;
- (NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *)getSyncCallMethod;
- (void)releaseObject;
- (int64_t)getWebId;
- (WKWebView*)getWeb;
- (NSString*)updateWebLayout:(NSDictionary*) paramMap;
- (void)startDownload:(NSString*)url;
- (void)onDownloadBeforeStart:(void (^)(NSString* guid, NSString *method, NSString *mimeType, NSString *url))callback;
- (void)onDownloadUpdated:(void (^)(NSString* guid, NSString* state, int64_t totalBytes,
                                int64_t receivedBytes, NSString *suggestedFileName))callback;
- (void)onDownloadFailed:(void (^)(NSString* guid, NSString* state, int64_t code))callback;
- (void)onDownloadFinish:(void (^)(NSString* guid, NSString* path))callback;
- (bool)webDownloadItemStart:(NSString*)guid ocPath:(NSString*)ocPath;
- (bool)webDownloadItemCancel:(NSString*)guid;
- (bool)webDownloadItemPause:(NSString*)guid;
- (bool)webDownloadItemResume:(NSString*)guid;
- (void)registerJavaScriptProxy:(NSString*)objName
                 syncMethodList:(NSArray*)syncMethodList
                asyncMethodList:(NSArray*)asyncMethodList
                       callback:(id (^)(NSString* objName, NSString* methodName, NSArray* args))callback;
- (void)deleteJavaScriptRegister:(NSString*)objName;
- (void)setNestedScrollOptionsExt:(void *)options;
- (BOOL)setWebSchemeHandler:(NSString*)scheme handler:(const ArkWeb_SchemeHandler*)handler;
- (BOOL)clearWebSchemeHandler;
@end
