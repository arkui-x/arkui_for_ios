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
        NSString *escapedMessage = [[message stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]
                                                stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
        NSString* source = [NSString stringWithFormat:@"(function() {%@.%@.postMessage('%@');})();",
                                     WEBVIEW_MESSAGE_CHANNELS_VARIABLE_NAME, port, escapedMessage];
        [self evaluateJavaScript:source];
    }
}

- (void)postMessageEventExt:(id) message
{
    for (NSString* port in self.etsPorts) {
        NSString* source = @"";
        if ([message isKindOfClass:[NSData class]]) {
            NSString *base64String = [message base64EncodedStringWithOptions:0];
        source = [NSString stringWithFormat:@"(function() { \
            var binaryString = window.atob('%@'); \
            var len = binaryString.length; \
            var bytes = new Uint8Array(len); \
            for (var i = 0; i < len; i++) { \
                bytes[i] = binaryString.charCodeAt(i); \
            } \
            %@.%@.postMessage(bytes.buffer); \
        })();", base64String, WEBVIEW_MESSAGE_CHANNELS_VARIABLE_NAME, port];
        } else if ([message isKindOfClass:[NSArray class]]) {
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            source = [NSString stringWithFormat:@"(function() {%@.%@.postMessage(%@);})();",
                    WEBVIEW_MESSAGE_CHANNELS_VARIABLE_NAME, port, jsonString];
        } else if ([message isKindOfClass:[NSNumber class]]) {
            if(strcmp([message objCType], @encode(char)) == 0) {
                bool boolValue = [message boolValue];
                NSString *result = boolValue ? @"true" : @"false";
                source = [NSString stringWithFormat:@"(function() {%@.%@.postMessage(%@);})();",
                        WEBVIEW_MESSAGE_CHANNELS_VARIABLE_NAME, port, result];
            } else {
                source = [NSString stringWithFormat:@"(function() {%@.%@.postMessage(%@);})();",
                        WEBVIEW_MESSAGE_CHANNELS_VARIABLE_NAME, port, message];
            }
        } else if ([message isKindOfClass:[NSError class]]) {
            NSError *error = (NSError *)message;
            NSString *errorName = error.domain;
            NSString *errorMessage = error.localizedDescription;
            source = [NSString stringWithFormat:@"(function() {%@.%@.postMessage(new Error('%@'));})();",
                WEBVIEW_MESSAGE_CHANNELS_VARIABLE_NAME, port, errorMessage];
        } else {
            NSString *escapedMessage = [[message stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]
                        stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
            source = [NSString stringWithFormat:@"(function() {%@.%@.postMessage('%@');})();",
                        WEBVIEW_MESSAGE_CHANNELS_VARIABLE_NAME, port, escapedMessage];
        }
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
