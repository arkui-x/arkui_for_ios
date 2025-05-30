/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WebMessageChannel : NSObject

- (instancetype)init:(NSArray*)portsName webView:(WKWebView*)webView;
- (void)initJsPortInstance;
- (void)postMessage:(NSString*)name portName:(NSString*)portName uri:(NSString*)uri;
- (void)postMessageEvent:(NSString*)message;
- (void)postMessageEventExt:(id)message;
- (void)closePort;
@end

NS_ASSUME_NONNULL_END
