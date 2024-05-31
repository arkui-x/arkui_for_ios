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

#import "WebMessageChannel.h"

#define WEBVIEW_MESSAGE_CHANNELS_VARIABLE_NAME @"arkuix_webView_MessageChannel"
@interface WebMessageChannel()
@property (nonatomic, weak) WKWebView *webView;
@property (nonatomic, strong) NSArray* allPorts;
@property (nonatomic, strong) NSMutableArray* etsPorts;
@end

@implementation WebMessageChannel

- (instancetype)init:(NSArray*)portsName webView:(WKWebView*)webView
{
    self.allPorts = [NSArray arrayWithArray:portsName];
    self.etsPorts = [[NSMutableArray alloc] init];
    self.webView = webView;
    return self;
}

- (void)initJsPortInstance
{
    NSString* source =
        [NSString stringWithFormat:@"var %@ = new MessageChannel();", WEBVIEW_MESSAGE_CHANNELS_VARIABLE_NAME];
    [self evaluateJavaScript:source];
}

- (void)postMessage:(NSString*)name portName:(NSString*)portName uri:(NSString*)uri
{
    NSMutableArray* portNames = [[NSMutableArray alloc] init];
    for (NSString* port in self.allPorts) {
        if ([port isEqualToString:portName]) {
            [portNames addObject:[NSString stringWithFormat:@"%@.%@", WEBVIEW_MESSAGE_CHANNELS_VARIABLE_NAME, port]];
        } else {
            [self.etsPorts addObject:port];
            [self setWebMessageCallBack:port];
        }
    }
    NSString* source = [NSString stringWithFormat:@"(function() {window.postMessage(\"%@\",\"%@\",[%@]);})();", name,
                                 uri, [portNames componentsJoinedByString:@", "]];
    [self evaluateJavaScript:source];
}

- (void)setWebMessageCallBack:(NSString*)port
{
    NSString* source = [NSString
        stringWithFormat:
            @"(function() {%@.%@.onmessage = "
            @"(event)=>{window.webkit.messageHandlers.onWebMessagePortMessage.postMessage(event.data);};})();",
        WEBVIEW_MESSAGE_CHANNELS_VARIABLE_NAME, port];
    [self evaluateJavaScript:source];
}

- (void)postMessageEvent:(NSString*)message
{
    for (NSString* port in self.etsPorts) {
        NSString* source = [NSString stringWithFormat:@"(function() {%@.%@.postMessage(\"%@\");})();",
                                     WEBVIEW_MESSAGE_CHANNELS_VARIABLE_NAME, port, message];
        [self evaluateJavaScript:source];
    }
}

- (void)closePort
{
    for (NSString* port in self.allPorts) {
        NSString* source = [NSString
            stringWithFormat:@"(function() {%@.%@.close();})();", WEBVIEW_MESSAGE_CHANNELS_VARIABLE_NAME, port];
        [self evaluateJavaScript:source];
    }
}

- (void)evaluateJavaScript:(NSString*)source
{
    if (self.webView == nil) {
        return;
    }

    [self.webView evaluateJavaScript:source
                   completionHandler:^(id result, NSError* error) {}];
}

@end
