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

#import "AceWeb.h"
#import "AceWebBridgeCpp.h"
#import "AceWebErrorReceiveInfoObject.h"
#include "AceWebCallbackObjectWrapper.h"

#define WEBVIEW_WIDTH  @"width"
#define WEBVIEW_HEIGHT  @"height"
#define WEBVIEW_POSITION_LEFT  @"left"
#define WEBVIEW_POSITION_TOP  @"top"
#define SUCCESS         @"success"
#define FAIL            @"fail"
#define KEY_SOURCE      @"src"
#define KEY_VALUE       @"value"

#define WEB_FLAG        @"web@"
#define PARAM_AND       @"#HWJS-&-#"
#define PARAM_EQUALS    @"#HWJS-=-#"
#define PARAM_BEGIN     @"#HWJS-?-#"
#define METHOD          @"method"
#define EVENT           @"event"
#define WEBVIEW_SRC      @"event"
#define S_Scale      @"event"

#define NTC_ZOOM_ACCESS            @"zoomAccess"
#define NTC_JAVASCRIPT_ACCESS      @"javascriptAccess"

@interface AceWeb()<WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate>
/**webView*/
@property (nonatomic, assign) WKWebView *webView;
@property (nonatomic, assign) int64_t incId;
@property (nonatomic, strong) WKPreferences *preferences;
@property (nonatomic, strong) WKWebpagePreferences *webpagePreferences;
@property (nonatomic, strong) UIViewController *target;
@property (nonatomic, strong) NSSet<UITouch *> *currentUiTouchs;
@property (nonatomic, strong) UIEvent  *currentEvent;
@property (nonatomic, assign) int8_t  currentType;
@property (nonatomic, assign) CGFloat screenScale;
@property (nonatomic, assign) bool allowZoom;
@property (nonatomic, assign) BOOL javascriptAccessSwitch;
@property (nonatomic, copy) IAceOnResourceEvent onEvent;

@property (nonatomic, strong) NSMutableDictionary<NSString *, IAceOnCallSyncResourceMethod> *callSyncMethodMap;
@end

@implementation AceWeb
- (instancetype)init:(int64_t)incId
              target:(UIViewController*)target
             onEvent:(IAceOnResourceEvent)callback
   abilityInstanceId:(int32_t)abilityInstanceId;
{
    self.onEvent = callback;
    self.incId = incId;
    self.target = target;
    self.javascriptAccessSwitch = YES;
    self.allowZoom = true;
    [self initConfigure];
    [self initEventCallback];
    [self initWeb];
    return self;
}

-(void)initWeb{
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    WKPreferences *preference = [[WKPreferences alloc]init];
    preference.javaScriptEnabled = self.javascriptAccessSwitch;
    
    config.preferences = preference;
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.UIDelegate = self;
    self.webView.navigationDelegate = self;
}
-(WKWebView*)getWeb {
    return self.webView;
}

-(void)loadUrl:(NSString*)url{
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
}

-(void)loadUrl:(NSString*)url header:(NSDictionary*) httpHeaders{
    
    if(url == nil){
        NSLog(@"Error:AceWeb: url is nill");
        return;
    }
    
    if ([url hasSuffix:@".html"] && ![url hasPrefix:@"file://"]) {
        url = [NSString stringWithFormat:@"file://%@", url];
    }
    
    if (httpHeaders == nil || httpHeaders.count == 0) {
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
        return;
    }
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[[NSURL alloc] initWithString:url]];
    NSDictionary *headerFields = httpHeaders;
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    [mutableRequest setAllHTTPHeaderFields:headerFields];
    [self.webView loadRequest:mutableRequest];
}

-(void)initConfigure {
    self.callSyncMethodMap = [[NSMutableDictionary alloc] init];
    self.screenScale = [UIScreen mainScreen].scale;
    InjectAceWebResourceObject();
}

- (void)fireCallback:(NSString *)method params:(NSString *)params
{
    NSString *method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", WEB_FLAG,
                             self.incId, EVENT, PARAM_EQUALS, method, PARAM_BEGIN];
    if (self.onEvent) {
        self.onEvent(method_hash, params);
    }
}

-(int64_t)getWebId {
    return self.incId;
}

- (void)initEventCallback
{
    __weak __typeof(self)weakSelf = self;
    
    NSString *javascriptAccess_method_hash = [self method_hashFormat:NTC_JAVASCRIPT_ACCESS];
    IAceOnCallSyncResourceMethod javascriptAccess_callback =
    ^NSString *(NSDictionary * param){
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf) {
            bool isJavaScriptEnable = [[param objectForKey:NTC_JAVASCRIPT_ACCESS] boolValue];

            if(!isJavaScriptEnable) {
                self.javascriptAccessSwitch = NO;
                if (@available(iOS 14.0, *)) {
                    self.webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = NO;
                    self.webView.configuration.preferences.javaScriptEnabled = NO;
                } else {
                    self.webView.configuration.preferences.javaScriptEnabled = NO;
                }
                [self.webView reload];
            }
            return SUCCESS;
        } else {
            NSLog(@"AceWeb: javaScriptAccess fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[javascriptAccess_callback copy] forKey:javascriptAccess_method_hash];
    
    // zoom callback
    NSString *zoom_method_hash = [self method_hashFormat:NTC_ZOOM_ACCESS];
    IAceOnCallSyncResourceMethod zoom_callback =
    ^NSString *(NSDictionary * param){
        bool isZoomEnable = [[param objectForKey:NTC_ZOOM_ACCESS] boolValue];
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf) {
            if(!isZoomEnable) {
                self.allowZoom = isZoomEnable;
            }
            return SUCCESS;
        } else {
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[zoom_callback copy] forKey:zoom_method_hash];
    
    // updateLayout callback
    NSString *layout_method_hash = [self method_hashFormat:@"updateLayout"];
    IAceOnCallSyncResourceMethod layout_callback = ^NSString *(NSDictionary * param){
        NSLog(@"AceWeb: updateLayout called");
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf updateWebLayout:param];
            return SUCCESS;
        } else {
            NSLog(@"AceWeb: updateLayout fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[layout_callback copy] forKey:layout_method_hash];
    
    IAceOnCallSyncResourceMethod touchDown_callback = ^NSString *(NSDictionary * param){
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf) {
            // [strongSelf processCurrentTouchEvent];
            return SUCCESS;
        } else {
            NSLog(@"AceWeb: updateLayout fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[touchDown_callback copy] forKey:[self method_hashFormat:@"touchDown"]];
    
    IAceOnCallSyncResourceMethod touchMove_callback = ^NSString *(NSDictionary * param){
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf) {
            // [strongSelf processCurrentTouchEvent];
            return SUCCESS;
        } else {
            NSLog(@"AceWeb: touchMove fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[touchMove_callback copy] forKey:[self method_hashFormat:@"touchMove"]];
    
    IAceOnCallSyncResourceMethod touchUp_callback = ^NSString *(NSDictionary * param){
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf) {
            // [strongSelf processCurrentTouchEvent];
            return SUCCESS;
        } else {
            NSLog(@"AceWeb: touchUp fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[touchUp_callback copy] forKey:[self method_hashFormat:@"touchUp"]];
    
}

- (NSString *)method_hashFormat:(NSString *)method
{
    return [NSString stringWithFormat:@"%@%lld%@%@%@%@", WEB_FLAG, self.incId, METHOD, PARAM_EQUALS, method, PARAM_BEGIN];
}

- (NSString *)event_hashFormat:(NSString *)method
{
    return [NSString stringWithFormat:@"%@%lld%@%@%@%@", WEB_FLAG, self.incId, EVENT, PARAM_EQUALS, method, PARAM_BEGIN];
}

-(NSString*)updateWebLayout:(NSDictionary*) paramMap {
    NSString*  left =   [paramMap objectForKey:WEBVIEW_POSITION_LEFT];
    NSString*  top =   [paramMap objectForKey:WEBVIEW_POSITION_TOP];
    NSString*  width =  [paramMap objectForKey:WEBVIEW_WIDTH];
    NSString*  height =   [paramMap objectForKey:WEBVIEW_HEIGHT];
    
     if(self.webView == nil){
        NSLog(@"Error:webView is NULL");
        return FAIL;
    }
    
    CGRect tempFrame = self.webView.frame;
    tempFrame.origin.x = [left floatValue]/self.screenScale;
    tempFrame.origin.y = [top floatValue]/self.screenScale;
    tempFrame.size.height = [height floatValue]/self.screenScale;
    tempFrame.size.width = [width floatValue]/self.screenScale;
    self.webView.frame = tempFrame;
    return SUCCESS;
}

- (void)releaseObject {
    NSLog(@"AceWeb releaseObject");
    if (self.callSyncMethodMap) {
        for (id key in self.callSyncMethodMap) {
            IAceOnCallSyncResourceMethod block = [self.callSyncMethodMap objectForKey:key];
            block = nil;
        }
        [self.callSyncMethodMap removeAllObjects];
        self.callSyncMethodMap = nil;
    }
    
    self.webView = nil;
    self.preferences = nil;
    self.webpagePreferences = nil;
}

- (NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *)getSyncCallMethod{
    return self.callSyncMethodMap;
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"didFailNavigation === ");
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    NSString *param = [NSString stringWithFormat:@"%@",webView.URL];
    [self fireCallback:@"onPageStarted" params:param];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSString *param = [NSString stringWithFormat:@"%@",webView.URL];
    [self fireCallback:@"onPageFinished" params:param];
    
    if(!self.allowZoom){
        NSLog(@"didFinishNavigation allowZoom disable  === ");
        NSString *injectionJSString = @"var script = document.createElement('meta');"
        "script.name = 'viewport';"
        "script.content=\"width=device-width, user-scalable=no\";"
        "document.getElementsByTagName('head')[0].appendChild(script);";
        [webView evaluateJavaScript:injectionJSString completionHandler:nil];
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:( WKNavigation *)navigation withError:(NSError *)error {
    NSString *errorStr = @"";
    if(webView.URL.absoluteString) {
        errorStr = webView.URL.absoluteString;
    } else {
        if (error) {
            NSDictionary *userInfo = error.userInfo;
            errorStr = userInfo[@"NSErrorFailingURLStringKey"];
        }
    }
    
    if(errorStr && error.description) {
        AceWebErrorReceiveInfoObject *obj = new AceWebErrorReceiveInfoObject(std::string([errorStr UTF8String]),
                                                                             std::string([error.description UTF8String]), error.code);
        errorReceiveObject([[self event_hashFormat:@"onErrorReceive"] UTF8String], [@"onErrorReceive" UTF8String], obj);
    }
}

@end
