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
#import "AceWebPatternBridge.h"
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

#define NTC_ZOOM_ACCESS                   @"zoomAccess"
#define NTC_JAVASCRIPT_ACCESS             @"javascriptAccess"
#define NTC_MINFONTSIZE                   @"minFontSize"
#define NTC_HORIZONTALSCROLLBAR_ACCESS    @"horizontalScrollBarAccess"
#define NTC_VERTICALSCROLLBAR_ACCESS      @"verticalScrollBarAccess"
#define NTC_BACKGROUNDCOLOR               @"backgroundColor"

@interface AceWeb()<WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate>
/**webView*/
@property (nonatomic, assign) WKWebView *webView;
@property (nonatomic, assign) int64_t incId;
@property (nonatomic, strong) WKPreferences *preferences;
@property (nonatomic, strong) WKWebpagePreferences *webpagePreferences;
@property (nonatomic, weak) UIViewController *target;
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
    preference.minimumFontSize = 8;
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
    
    if ([url hasSuffix:@".html"] && ![url hasPrefix:@"file://"] && ![url hasPrefix:@"http"]) {
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
    // zoomAccess callback
    [self setZoomAccessCallback];
    // javaScriptAccess callback
    [self setJavaScriptAccessCallback];
    // minFontSize callback
    [self setMinFontSizeCallback];
    // horizontalScrollBarAccess callback
    [self setHorizontalScrollBarAccessCallback];
    // verticalScrollBarAccesss callback
    [self setVerticalScrollBarAccessCallback];
    // backgroundColor callback
    [self setBackGroundColorCallback];
    // updateLayout callback
    [self setUpdateLayout];
    // touchDown callback
    [self setTouchDownCallback];
    // touchMove callback
    [self setTouchMoveCallback];
    // touchUp callback
    [self setTouchUpCallback];
}

- (void)setZoomAccessCallback
{
    // zoom callback
    __weak __typeof(self) weakSelf = self;
    NSString *zoom_method_hash = [self method_hashFormat:NTC_ZOOM_ACCESS];
    IAceOnCallSyncResourceMethod zoom_callback =
    ^NSString *(NSDictionary * param){
        bool isZoomEnable = [[param objectForKey:NTC_ZOOM_ACCESS] boolValue];
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf) {
            if(self.allowZoom == isZoomEnable) {
                NSLog(@"AceWeb: isZoomEnable same");
                return SUCCESS;
            }
            [self.webView reload];
            self.allowZoom = isZoomEnable;
            WKUserContentController *userController = [WKUserContentController new];
            NSString *injectionJSString;
            if(!self.allowZoom) {
                injectionJSString = @"var script = document.createElement('meta');"
                "script.name = 'viewport';"
                "script.content=\"width=device-width, initial-scale=1.0,maximum-scale-1.0,user-scalable=no\";"
                "document.getElementsByTagName('head')[0].appendChild(script);";
            } else {
                injectionJSString = @"var script = document.createElement('meta');"
                "script.name = 'viewport';"
                "script.content=\"width=device-width, initial-scale=1.0,user-scalable=yes\";"
                "document.getElementsByTagName('head')[0].appendChild(script);";
            }
            WKUserScript *script = [[WKUserScript alloc] initWithSource:injectionJSString injectionTime:
                                    WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO];
            [userController addUserScript:script];
            [self.webView.configuration.userContentController addUserScript:script];
            return SUCCESS;
        } else {
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[zoom_callback copy] forKey:zoom_method_hash];
}

- (void)setJavaScriptAccessCallback
{
    __weak __typeof(self) weakSelf = self;
     NSString *javascriptAccess_method_hash = [self method_hashFormat:NTC_JAVASCRIPT_ACCESS];
    IAceOnCallSyncResourceMethod javascriptAccess_callback =
    ^NSString *(NSDictionary * param){
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf) {
            bool isJavaScriptEnable = [[param objectForKey:NTC_JAVASCRIPT_ACCESS] boolValue];
            if(self.javascriptAccessSwitch == isJavaScriptEnable) {
                NSLog(@"AceWeb: javaScriptEnabled same");
                return SUCCESS;
            }
            BOOL jsWillOpen = isJavaScriptEnable ? YES : NO;
            if (@available(iOS 14.0, *)) {
                self.webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = jsWillOpen;
                self.webView.configuration.preferences.javaScriptEnabled = jsWillOpen;
            } else {
                self.webView.configuration.preferences.javaScriptEnabled = jsWillOpen;
            }
            [self.webView reload];
            self.javascriptAccessSwitch = isJavaScriptEnable? YES : NO;

            return SUCCESS;
        } else {
            NSLog(@"AceWeb: javaScriptAccess fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[javascriptAccess_callback copy] forKey:javascriptAccess_method_hash];
}

- (void)setUpdateLayout
{
    __weak __typeof(self) weakSelf = self;
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
}

- (void)setMinFontSizeCallback
{
    __weak __typeof(self) weakSelf = self;
    NSString* minfontsize_method_hash = [self method_hashFormat:NTC_MINFONTSIZE];
    IAceOnCallSyncResourceMethod minFontSize_callback = ^NSString*(NSDictionary* param)
    {
        float minFontSize = [[param objectForKey:NTC_MINFONTSIZE] floatValue];
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            self.webView.configuration.preferences.minimumFontSize = (minFontSize / 96) * 72;
            return SUCCESS;
        } else {
            NSLog(@"AceWeb: minFontSize fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[minFontSize_callback copy] forKey:minfontsize_method_hash];
}

- (void)setHorizontalScrollBarAccessCallback
{
    __weak __typeof(self) weakSelf = self;
    NSString* horizontalScrollBarAccess_method_hash = [self method_hashFormat:NTC_HORIZONTALSCROLLBAR_ACCESS];
    IAceOnCallSyncResourceMethod horizontalScrollBarAccess_callback = ^NSString*(NSDictionary* param)
    {
        bool isHorizontalScrollBarEnable = [[param objectForKey:NTC_HORIZONTALSCROLLBAR_ACCESS] boolValue];
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            if (!isHorizontalScrollBarEnable) {
                self.webView.scrollView.showsHorizontalScrollIndicator = NO;
            } else {
                self.webView.scrollView.showsHorizontalScrollIndicator = YES;
            }
            return SUCCESS;
        } else {
            NSLog(@"AceWeb: horizontalScrollBar fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[horizontalScrollBarAccess_callback copy]
                               forKey:horizontalScrollBarAccess_method_hash];
}

- (void)setVerticalScrollBarAccessCallback
{
    __weak __typeof(self) weakSelf = self;
    NSString* verticalScrollBarAccess_method_hash = [self method_hashFormat:NTC_VERTICALSCROLLBAR_ACCESS];
    IAceOnCallSyncResourceMethod verticalScrollBarAccess_callback = ^NSString*(NSDictionary* param)
    {
        bool isVerticalScrollBarEnable = [[param objectForKey:NTC_VERTICALSCROLLBAR_ACCESS] boolValue];
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            if (!isVerticalScrollBarEnable) {
                self.webView.scrollView.showsVerticalScrollIndicator = NO;
            } else {
                self.webView.scrollView.showsVerticalScrollIndicator = YES;
            }
            return SUCCESS;
        } else {
            NSLog(@"AceWeb: horizontalScrollBar fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[verticalScrollBarAccess_callback copy]
                               forKey:verticalScrollBarAccess_method_hash];
}

- (UIColor*)hexToColor:(int)hex
{
    return [UIColor colorWithRed:(hex >> 16 & 0xff) / 255.f
                           green:(hex >> 8 & 0xff) / 255.f
                            blue:(hex & 0xff) / 255.f
                           alpha:1];
}

- (void)setBackGroundColorCallback
{
    __weak __typeof(self) weakSelf = self;
    NSString* backGroundColor_method_hash = [self method_hashFormat:NTC_BACKGROUNDCOLOR];
    IAceOnCallSyncResourceMethod backGroundColor_callback = ^NSString*(NSDictionary* param)
    {
        int backgroundColor = [[param objectForKey:NTC_BACKGROUNDCOLOR] intValue];
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            if (@available(iOS 15.0, *)) {
                self.webView.underPageBackgroundColor = [self hexToColor:backgroundColor];
            } else {
                self.webView.backgroundColor = [self hexToColor:backgroundColor];
            }
            [self.webView setOpaque:NO];
            self.webView.scrollView.backgroundColor = [self hexToColor:backgroundColor];
            return SUCCESS;
        } else {
            NSLog(@"AceWeb: backgroundColor fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[backGroundColor_callback copy] forKey:backGroundColor_method_hash];
}

- (void)setTouchDownCallback
{
    __weak __typeof(self) weakSelf = self;
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
}

- (void)setTouchMoveCallback
{
    __weak __typeof(self) weakSelf = self;
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
}

- (void)setTouchUpCallback
{
    __weak __typeof(self) weakSelf = self;
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
    self.target = nil;
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
