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
#import "AceWebObject.h"
#include "AceWebCallbackObjectWrapper.h"
#import "AceWebControllerBridge.h"

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
#define WEBVIEW_SRC     @"event"
#define S_Scale         @"event"
#define CONSOLELOG      @"log"
#define CONSOLEERROR    @"error"
#define CONSOLEINFO     @"info"
#define CONSOLEDEBUG    @"debug"
#define CONSOLEWARN     @"warn"
#define ESTIMATEDPROGRESS  @"estimatedProgress"
#define TITLE           @"title"

#define NTC_ZOOM_ACCESS                   @"zoomAccess"
#define NTC_JAVASCRIPT_ACCESS             @"javascriptAccess"
#define NTC_MINFONTSIZE                   @"minFontSize"
#define NTC_HORIZONTALSCROLLBAR_ACCESS    @"horizontalScrollBarAccess"
#define NTC_VERTICALSCROLLBAR_ACCESS      @"verticalScrollBarAccess"
#define NTC_BACKGROUNDCOLOR               @"backgroundColor"
#define NTC_UPDATELAYOUT                  @"updateLayout"
#define NTC_ONLOADINTERCEPT               @"onLoadIntercept"
#define NTC_ONHTTPERRORRECEIVE            @"onHttpErrorReceive"
#define NTC_ONPROGRESSCHANGED             @"onProgressChanged"
#define NTC_ONRECEIVEDTITLE               @"onReceivedTitle"
#define NTC_ONSCROLL                      @"onScroll"
#define NTC_ONSCALECHANGE                 @"onScaleChange"
#define NTC_ONCONSOLEMESSAGE              @"onConsoleMessage"

@interface AceWeb()<WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate, UIScrollViewDelegate>
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
@property (nonatomic, assign) CGFloat oldScale;
@property (nonatomic, assign) int httpErrorCode;
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
    self.oldScale = 100.0f;
    self.httpErrorCode = 400;
    [self initConfigure];
    [self initEventCallback];
    [self initWeb];
    return self;
}

-(void)initWeb{
    WKWebViewConfiguration* config = [[WKWebViewConfiguration alloc] init];
    WKPreferences* preference = [[WKPreferences alloc] init];
    preference.minimumFontSize = 8;
    WKUserContentController* userContentController = [[WKUserContentController alloc] init];
    [self initConsole:CONSOLELOG controller:userContentController];
    [self initConsole:CONSOLEINFO controller:userContentController];
    [self initConsole:CONSOLEERROR controller:userContentController];
    [self initConsole:CONSOLEDEBUG controller:userContentController];
    [self initConsole:CONSOLEWARN controller:userContentController];
    preference.javaScriptEnabled = self.javascriptAccessSwitch;

    config.preferences = preference;
    config.userContentController = userContentController;
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.UIDelegate = self;
    self.webView.navigationDelegate = self;
    self.webView.scrollView.delegate = self;
    [self.webView addObserver:self forKeyPath:ESTIMATEDPROGRESS options:NSKeyValueObservingOptionNew context:nil];
    [self.webView addObserver:self forKeyPath:TITLE options:NSKeyValueObservingOptionNew context:nil];
}
-(WKWebView*)getWeb {
    return self.webView;
}

- (void)initConsole:(NSString*)consoleLevel controller:(WKUserContentController*)controller
{
    NSString* jsConsole = @"";
    if ([consoleLevel isEqualToString:CONSOLELOG]) {
        jsConsole = @"console.log = (function(oriLogFunc){ return function(str){ oriLogFunc.call(console,str); "
                    "window.webkit.messageHandlers.log.postMessage(str); } })(console.log);";
    } else if ([consoleLevel isEqualToString:CONSOLEINFO]) {
        jsConsole = @"console.info = (function(oriLogFunc){ return function(str){ oriLogFunc.call(console,str); "
                    "window.webkit.messageHandlers.info.postMessage(str); } })(console.info);";
    } else if ([consoleLevel isEqualToString:CONSOLEERROR]) {
        jsConsole = @"console.error = (function(oriLogFunc){ return function(str){ oriLogFunc.call(console,str); "
                    "window.webkit.messageHandlers.error.postMessage(str); } })(console.error);";
    } else if ([consoleLevel isEqualToString:CONSOLEDEBUG]) {
        jsConsole = @"console.debug = (function(oriLogFunc){ return function(str){ oriLogFunc.call(console,str); "
                    "window.webkit.messageHandlers.debug.postMessage(str); } })(console.debug);";
    } else if ([consoleLevel isEqualToString:CONSOLEWARN]) {
        jsConsole = @"console.warn = (function(oriLogFunc){ return function(str){ oriLogFunc.call(console,str); "
                    "window.webkit.messageHandlers.warn.postMessage(str); } })(console.warn);";
    }
    WKUserScript* script = [[WKUserScript alloc] initWithSource:jsConsole
                                                  injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                               forMainFrameOnly:NO];
    [controller addUserScript:script];
    [controller addScriptMessageHandler:self name:consoleLevel];
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

- (void)loadData:(NSString*)data
        mimeType:(NSString*)mimeType
        encoding:(NSString*)encoding
         baseUrl:(NSString*)baseUrl
      historyUrl:(NSString*)historyUrl
{
    if (@available(iOS 9.0, *)) {
        [self.webView loadData:[data dataUsingEncoding:NSUTF8StringEncoding]
                         MIMEType:mimeType
            characterEncodingName:encoding
                          baseURL:[NSURL fileURLWithPath:baseUrl]];
    } else {
        [self.webView loadHTMLString:data baseURL:[NSURL URLWithString:baseUrl]];
    }
}

- (void)EvaluateJavaScript:(NSString*)script callback:(void (^)(NSString* ocResult))callback
{
    NSLog(@"AceWeb: ExecuteJavaScript called");
    [self.webView evaluateJavaScript:script
                   completionHandler:^(id _Nullable obj, NSError* _Nullable error) {
                     NSString* result = [NSString stringWithFormat:@"%@", obj];
                     callback(result);
                   }];
}

- (NSString*)getUrl
{
    return self.webView.URL == nil ? @"" : [self.webView.URL absoluteString];
}

- (bool)accessBackward
{
    return self.webView.canGoBack;
}

- (bool)accessForward
{
    return self.webView.canGoForward;
}

- (void)backward
{
    [self.webView goBack];
}

- (void)forward
{
    [self.webView goForward];
}

- (void)refresh
{
    [self.webView reload];
}

- (void)initConfigure {
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
    [self.webView removeObserver:self forKeyPath:ESTIMATEDPROGRESS];
    [self.webView removeObserver:self forKeyPath:TITLE];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:CONSOLELOG];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:CONSOLEINFO];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:CONSOLEERROR];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:CONSOLEDEBUG];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:CONSOLEWARN];
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
    
    if(!self.allowZoom){
        NSLog(@"didFinishNavigation allowZoom disable  === ");
        NSString *injectionJSString = @"var script = document.createElement('meta');"
        "script.name = 'viewport';"
        "script.content=\"width=device-width, user-scalable=no\";"
        "document.getElementsByTagName('head')[0].appendChild(script);";
        [webView evaluateJavaScript:injectionJSString completionHandler:nil];
    }
}

- (void)webView:(WKWebView*)webView
    decidePolicyForNavigationAction:(WKNavigationAction*)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSString* requestURL =
        navigationAction.request.URL.absoluteString ? navigationAction.request.URL.absoluteString : @"";
    AceWebErrorReceiveInfoObject* obj = new AceWebErrorReceiveInfoObject(std::string([requestURL UTF8String]), "", 0);
    if (AceWebObjectWithBoolReturn(
            [[self event_hashFormat:NTC_ONLOADINTERCEPT] UTF8String], [NTC_ONLOADINTERCEPT UTF8String], obj)) {
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView*)webView
    decidePolicyForNavigationResponse:(WKNavigationResponse*)navigationResponse
                      decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    NSHTTPURLResponse* response = (NSHTTPURLResponse*)navigationResponse.response;
    if (response && response.statusCode >= self.httpErrorCode) {
        NSString* requestURL = response.URL.absoluteString ? response.URL.absoluteString : @"";
        NSString* mineType = response.MIMEType ? response.MIMEType : @"";
        NSString* encodingName = response.textEncodingName ? response.textEncodingName : @"";
        AceWebHttpErrorReceiveObject* obj = new AceWebHttpErrorReceiveObject(std::string([requestURL UTF8String]),
            std::string([mineType UTF8String]), std::string([encodingName UTF8String]), response.statusCode);
        AceWebObject(
            [[self event_hashFormat:NTC_ONHTTPERRORRECEIVE] UTF8String], [NTC_ONHTTPERRORRECEIVE UTF8String], obj);
    }
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id>*)change
                       context:(void*)context
{
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(estimatedProgress))] && object == _webView) {
        NSString* param = [NSString stringWithFormat:@"%.f", _webView.estimatedProgress * 100];
        [self fireCallback:NTC_ONPROGRESSCHANGED params:param];
    } else if ([keyPath isEqualToString:TITLE] && object == _webView) {
        _webView.title == nil ? [self fireCallback:NTC_ONRECEIVEDTITLE params:@""]
                              : [self fireCallback:NTC_ONRECEIVEDTITLE params:_webView.title];
    }
}

- (void)scrollViewDidScroll:(UIScrollView*)scrollView
{
    float x = 0.f;
    float y = 0.f;
    if (scrollView.contentOffset.x) {
        x = scrollView.contentOffset.x;
    }
    if (scrollView.contentOffset.y) {
        y = scrollView.contentOffset.y;
    }
    AceWebOnScrollObject* obj = new AceWebOnScrollObject(x, y);
    AceWebObject([[self event_hashFormat:NTC_ONSCROLL] UTF8String], [NTC_ONSCROLL UTF8String], obj);
}

- (void)scrollViewDidZoom:(UIScrollView*)scrollView
{
    float newScale = 0.f;
    if (scrollView.zoomScale) {
        newScale = scrollView.zoomScale * 100;
        AceWebOnScaleChangeObject* obj = new AceWebOnScaleChangeObject(newScale, self.oldScale);
        AceWebObject([[self event_hashFormat:NTC_ONSCALECHANGE] UTF8String], [NTC_ONSCALECHANGE UTF8String], obj);
        if (newScale != self.oldScale) {
            self.oldScale = newScale;
        }
    }
}

- (void)userContentController:(WKUserContentController*)userContentController
      didReceiveScriptMessage:(WKScriptMessage*)message
{
    int messageLevel = 2;
    NSString* messageBody = message.body ? (NSString*)message.body : @"";
    if ([message.name hasPrefix:CONSOLEDEBUG]) {
        messageLevel = 1;
    } else if ([message.name hasPrefix:CONSOLEERROR]) {
        messageLevel = 4;
    } else if ([message.name hasPrefix:CONSOLEINFO] || [message.name hasPrefix:CONSOLELOG]) {
        messageLevel = 2;
    } else if ([message.name hasPrefix:CONSOLEWARN]) {
        messageLevel = 3;
    }
    AceWebOnConsoleObject* obj = new AceWebOnConsoleObject(std::string([messageBody UTF8String]), messageLevel);
    AceWebObjectWithBoolReturn(
        [[self event_hashFormat:NTC_ONCONSOLEMESSAGE] UTF8String], [NTC_ONCONSOLEMESSAGE UTF8String], obj);
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
        AceWebObject([[self event_hashFormat:@"onErrorReceive"] UTF8String], [@"onErrorReceive" UTF8String], obj);
    }
}

@end
