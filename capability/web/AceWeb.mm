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

#import "AceWeb.h"
#import <Security/Security.h>
#import "AceWebPatternBridge.h"
#import "AceWebErrorReceiveInfoObject.h"
#import "AceWebObject.h"
#include "AceWebCallbackObjectWrapper.h"
#import "AceWebControllerBridge.h"
#import "WebMessageChannel.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "AceWebPatternOCBridge.h"
#include "core/components_ng/pattern/scrollable/scrollable_properties.h"
#include "scheme_handler/resource_request.h"
#include "ace_engine_types.h"
#import "AceWebInfoManager.h"

#define WEBVIEW_WIDTH  @"width"
#define WEBVIEW_HEIGHT  @"height"
#define WEBVIEW_POSITION_LEFT  @"left"
#define WEBVIEW_POSITION_TOP  @"top"
#define WEBVIEW_LOADDATA_DATA  @"load_data_data"
#define WEBVIEW_LOADDATA_MIMETYPE  @"load_data_mimetype"
#define WEBVIEW_LOADDATA_ENCODING  @"load_data_encoding"
#define SUCCESS         @"success"
#define FAIL            @"fail"
#define KEY_SOURCE      @"src"
#define KEY_VALUE       @"value"
#define DELAY_TIME      0.3
#define ZOOMIN_SCALE_VALUE   1.2
#define ZOOMOUT_SCALE_VALUE  0.8
#define POLLING_INTERVAL_MS 50
#define TIMEOUT_S 15
#define HTTP_STATUS_GATEWAY_TIMEOUT 504

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
#define NTC_ONWILL_SCROLLSTART            @"onWillScrollStart"
#define NTC_ONSCROLLSTART                 @"onScrollStart"
#define NTC_ONSCROLLEND                   @"onScrollEnd"
#define NTC_ONSCROLL                      @"onScroll"
#define NTC_ONSCALECHANGE                 @"onScaleChange"
#define NTC_ONCONSOLEMESSAGE              @"onConsoleMessage"
#define NTC_RICHTEXT_LOADDATA             @"loadData"
#define NTC_ONFULLSCREENENTER             @"onFullScreenEnter"
#define NTC_ONFULLSCREENEXIT              @"onFullScreenExit"
#define NTC_ONINTERCEPTREQUEST            @"onInterceptRequest"
#define NTC_REGISTEREDONINTERCEPTREQUEST  @"IsRegisteredOnInterceptRequest"
#define NTC_ONREFRESHACCESSED_HISTORYEVENT     @"onRefreshAccessedHistory"
#define CUSTOM_SCHEME                     @"arkuixcustomscheme"
#define CUSTOM_SCHEME_HANDLER             @"arkuixcustomschemehandler"
#define NTC_ONOVERRIDEURLLOADING          @"onOverrideUrlLoading"
#define NTC_ONSSLERROREVENTRECEIVE        @"onSslErrorEventReceive"
#define NTC_ONSSLERROREVENT               @"onSslErrorEvent"
#define NTC_ONCLIENTAUTHENTICATIONREQUEST @"onClientAuthenticationRequest"
#define WEBVIEW_PAGE_HALF                 2
#define NTC_TEXT_ZOOM_RATIO               @"textZoomRatio"

typedef NS_ENUM(NSInteger, NestedScrollMode) {
    SELF_ONLY,
    SELF_FIRST,
    PARENT_FIRST, 
    PARALLEL
};
@interface NestedScrollOptionsExt : NSObject
@property (nonatomic, assign) NestedScrollMode scrollUp;
@property (nonatomic, assign) NestedScrollMode scrollDown;
@property (nonatomic, assign) NestedScrollMode scrollLeft;
@property (nonatomic, assign) NestedScrollMode scrollRight;
@end
@implementation NestedScrollOptionsExt
@end

@interface DownloadTaskInfo : NSObject
@property (nonatomic, assign) bool isDownload;
@property (nonatomic, strong) NSString* filePath;
@property (nonatomic, strong) NSDate* lastUpdateTime;
@property (nonatomic, strong) NSURLSessionDownloadTask* downloadTask;
@end

@implementation DownloadTaskInfo
@end
typedef void (^PostMessageResultMethod)(NSString* ocResult);
typedef void (^PostMessageResultMethodExt)(id ocResult);
typedef void (^OnDownloadBeforeStart)(NSString* guid, NSString* method, NSString* mimeType, NSString* url);
typedef void (^onDownloadUpdated)(NSString* guid, NSString* state, int64_t totalBytes,
                                int64_t receivedBytes, NSString* suggestedFileName);
typedef void (^onDownloadFailed)(NSString* guid, NSString* state, int64_t code);
typedef void (^onDownloadFinish)(NSString* guid, NSString* path);
typedef id (^onJavaScriptFunction)(NSString* objName, NSString* methodName, NSArray* args);
@interface AceWeb()<WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate, 
                    UIScrollViewDelegate, NSURLSessionDownloadDelegate, WKHTTPCookieStoreObserver, WKURLSchemeHandler>
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
@property (nonatomic, assign) bool isLoadRichText;
@property (nonatomic, assign) BOOL javascriptAccessSwitch;
@property (nonatomic, copy) IAceOnResourceEvent onEvent;
@property (nonatomic, strong) NSURLSession* session;
@property (nonatomic, strong) WebMessageChannel* webMessageChannel;
@property (nonatomic, strong) PostMessageResultMethod messageCallBack;
@property (nonatomic, strong) NSString *reloadUrl;
@property (nonatomic, strong) UIView *viewExitFullScreen;
@property (nonatomic, strong) UIViewController *viewControllerExitFull;
@property (nonatomic, copy) NSString *videoSrc;
@property (nonatomic, strong) NSMutableDictionary<NSString *, IAceOnCallSyncResourceMethod> *callSyncMethodMap;
@property (nonatomic, strong) PostMessageResultMethodExt messageCallBackExt;
@property (nonatomic, strong) OnDownloadBeforeStart onDownloadBeforeStartCallBack;
@property (nonatomic, strong) onDownloadUpdated onDownloadUpdatedCallBack;
@property (nonatomic, strong) onDownloadFailed onDownloadFailedCallBack;
@property (nonatomic, strong) onDownloadFinish onDownloadFinishCallBack;
@property (nonatomic, strong) onJavaScriptFunction onJavaScriptFunctionCallBack;
@property (nonatomic, strong) NSMutableDictionary<NSString*, DownloadTaskInfo*>* downloadTasksDic;
@property (nonatomic, strong) NSArray* syncMethodList;
@property (nonatomic, strong) NSArray* asyncMethodList;
@property (nonatomic, strong) NSString* objName;
@property (nonatomic, assign) bool allowIncognitoMode;
@property (nonatomic, assign) BOOL jsReady;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSValue*>* schemeHandlerMap;
@property (nonatomic, assign) ArkWeb_ResourceRequest* currentResourceRequest;
@property (nonatomic, assign) ArkWeb_ResourceHandler* currentResourceHandler;
@property (nonatomic, assign) NSInteger textZoomRatio;
@property (nonatomic, copy) NSString* referrer;
@property (nonatomic, assign) bool isMainFrame;
@property (nonatomic, copy) NSString* mainFrameUrl;
@property (nonatomic, assign) bool isLoadUrl;
@property (nonatomic, strong) NSMutableSet<NSString *> *handleSslErrorUrls;
@property (nonatomic, strong) NestedScrollOptionsExt *nestedOpt;
@property (nonatomic, assign) CGPoint dragStartPoint;
@property (nonatomic, assign) BOOL hasCalledOnScrollStart;
@end

static BOOL _webDebuggingAccessInit = NO;
static NSString *const kJavaScriptURLPrefix = @"javascript:";
using SslError = OHOS::Ace::NG::Converter::SslError;

@implementation AceWeb {
    dispatch_source_t _timer;
}

- (instancetype)init:(int64_t)incId
              target:(UIViewController*)target
             onEvent:(IAceOnResourceEvent)callback
   abilityInstanceId:(int32_t)abilityInstanceId;
{
    return [self init:incId incognitoMode:false target:target onEvent:callback
    abilityInstanceId:abilityInstanceId];
}

- (instancetype)init:(int64_t)incId
              incognitoMode:(bool)incognitoMode
              target:(UIViewController*)target
             onEvent:(IAceOnResourceEvent)callback
   abilityInstanceId:(int32_t)abilityInstanceId
{
    self.onEvent = callback;
    self.incId = incId;
    self.target = target;
    self.javascriptAccessSwitch = YES;
    self.allowIncognitoMode = incognitoMode;
    self.allowZoom = true;
    self.oldScale = 100.0f;
    self.httpErrorCode = 400;
    self.isLoadRichText = false;
    self.jsReady = false;
    self.currentResourceRequest = nullptr;
    self.currentResourceHandler = nullptr;
    self.textZoomRatio = 100;
    self.referrer = @"";
    self.isMainFrame = false;
    self.isLoadUrl = false;
    self.handleSslErrorUrls = [NSMutableSet set];
    [self initConfigure];
    [self initEventCallback];
    [self initWeb];
    return self;
}

-(void)initWeb
{
    WKWebViewConfiguration* config = [[WKWebViewConfiguration alloc] init];
    WKPreferences* preference = [[WKPreferences alloc] init];
    preference.minimumFontSize = 8;
    WKUserContentController* userContentController = [[WKUserContentController alloc] init];
    [self initConsole:CONSOLELOG controller:userContentController];
    [self initConsole:CONSOLEINFO controller:userContentController];
    [self initConsole:CONSOLEERROR controller:userContentController];
    [self initConsole:CONSOLEDEBUG controller:userContentController];
    [self initConsole:CONSOLEWARN controller:userContentController];
    [userContentController addScriptMessageHandler:self name:@"onWebMessagePortMessage"];
    [userContentController addScriptMessageHandler:self name:@"AceWebHandler"];
    NSString *htmlFBody = @"var vSrc = e.target.currentSrc;window.webkit.messageHandlers.videoPlayed.postMessage(vSrc);";
    NSString *htmlFunc = [NSString stringWithFormat:@"function(e) {if (e.target.tagName === 'VIDEO') {%@}}", htmlFBody];
    NSString *htmlJS = [NSString stringWithFormat:@"document.addEventListener('play', %@, true);", htmlFunc];
    
    WKUserScript *script = [[WKUserScript alloc] initWithSource:htmlJS injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [userContentController addUserScript:script];
    [userContentController addScriptMessageHandler:self name:@"videoPlayed"];
    preference.javaScriptEnabled = self.javascriptAccessSwitch;

    config.preferences = preference;
    config.userContentController = userContentController;
    config.allowsInlineMediaPlayback = YES;
    [config setURLSchemeHandler:self forURLScheme:CUSTOM_SCHEME];
    [config setURLSchemeHandler:self forURLScheme:CUSTOM_SCHEME_HANDLER];
    [self incognitoModeWithConfig:config];
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.UIDelegate = self;
    self.webView.navigationDelegate = self;
    self.webView.scrollView.delegate = self;
    if (@available(iOS 11.0, *)) {
        self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    [self.webView addObserver:self forKeyPath:ESTIMATEDPROGRESS options:NSKeyValueObservingOptionNew context:nil];
    [self.webView addObserver:self forKeyPath:TITLE options:NSKeyValueObservingOptionNew context:nil];
    self.hasCalledOnScrollStart = YES;
}

- (void)incognitoModeWithConfig:(WKWebViewConfiguration*) config
{
    if (self.allowIncognitoMode) {
        WKWebsiteDataStore *defaultDataStore = [WKWebsiteDataStore defaultDataStore];
        NSArray *dataTypes = @[WKWebsiteDataTypeCookies];
        [defaultDataStore removeDataOfTypes:[NSSet setWithArray:dataTypes] modifiedSince:[NSDate dateWithTimeIntervalSince1970:0] completionHandler:^{
        }];
        config.processPool = [[WKProcessPool alloc] init];
        WKWebsiteDataStore *nonPersistentDataStore = [WKWebsiteDataStore nonPersistentDataStore];
        [config setWebsiteDataStore:nonPersistentDataStore];
    } else {
        WKWebsiteDataStore *defaultDataStore = [WKWebsiteDataStore defaultDataStore];
        config.websiteDataStore = defaultDataStore;
    }
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (@available(iOS 11.0, *)) {
        [config.websiteDataStore.httpCookieStore addObserver:self];
    }
#endif
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

-(void)loadUrl:(NSString*)url
{
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
    self.isLoadUrl = YES;
}

-(void)loadUrl:(NSString*)url header:(NSDictionary*) httpHeaders
{
    if(url == nil){
        NSLog(@"Error:AceWeb: url is nill");
        return;
    }
    if ([url hasSuffix:@".html"] && ![url hasPrefix:@"file://"] && ![url hasPrefix:@"http"]) {
        url = [NSString stringWithFormat:@"file://%@", url];
    }
    [self.handleSslErrorUrls removeAllObjects];
    if (httpHeaders == nil || httpHeaders.count == 0) {
        if ([self isJavascriptUrl:url]) {
            NSString *js = [url substringFromIndex:kJavaScriptURLPrefix.length];
            if (js.length > 0) {
                NSLog(@"AceWeb: load javascript url");
                [self evaluateJavaScript:js callback:nil];
            } else {
                NSLog(@"Error:AceWeb: javascript url is empty");
            }
        } else {
            [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
            self.isLoadUrl = YES;
        }
        return;
    }

    NSURLRequest *request = [NSURLRequest requestWithURL:[[NSURL alloc] initWithString:url]];
    NSDictionary *headerFields = httpHeaders;
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    [mutableRequest setAllHTTPHeaderFields:headerFields];
    [self.webView loadRequest:mutableRequest];
    self.isLoadUrl = YES;
}

- (BOOL)isJavascriptUrl:(NSString *)url
{
    if (url.length < kJavaScriptURLPrefix.length) {
        return NO;
    }
    return [url.lowercaseString hasPrefix:kJavaScriptURLPrefix];
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

- (void)evaluateJavaScript:(NSString*)script callback:(void (^)(id _Nullable obj, NSError* _Nullable error))callback
{
    NSLog(@"AceWeb: ExecuteJavaScript called");
    [self.webView evaluateJavaScript:script
                completionHandler:^(id _Nullable obj, NSError* _Nullable error) {
                    callback(obj, error);
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

- (void)removeCache:(bool)value
{
    NSSet* websiteDataTypes = [[NSMutableSet alloc] init];
    if (value) {
        websiteDataTypes = [NSSet setWithArray:@[ WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeDiskCache ]];
    } else {
        websiteDataTypes = [NSSet setWithArray:@[ WKWebsiteDataTypeMemoryCache ]];
    }
    NSDate* dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes
                                               modifiedSince:dateFrom
                                           completionHandler:^ {
                                           }];
}

- (void)backOrForward:(NSInteger)step
{
    if (step > 0) {
        if (self.webView.backForwardList.forwardList.count >= step) {
            WKBackForwardListItem* backForwardListItem = [self.webView.backForwardList itemAtIndex:step];
            [self.webView goToBackForwardListItem:backForwardListItem];
        }
    }

    if (step < 0) {
        if (self.webView.backForwardList.backList.count >= abs(step)) {
            WKBackForwardListItem* backForwardListItem = [self.webView.backForwardList itemAtIndex:step];
            [self.webView goToBackForwardListItem:backForwardListItem];
        }
    }
}

- (NSString*)getTitle
{
    return self.webView.title;
}

- (CGFloat)getPageHeight
{
    return self.webView.scrollView.contentSize.height;
}

- (void)createWebMessagePorts:(NSArray*)portsName
{
    self.webMessageChannel = [[WebMessageChannel alloc] init:portsName webView:self.webView];
    [self.webMessageChannel initJsPortInstance];
}

- (void)postWebMessage:(NSString*)message port:(NSString*)port targetUrl:(NSString*)targetUrl
{
    if (self.webMessageChannel == nil) {
        return;
    }
    [self.webMessageChannel postMessage:message portName:port uri:targetUrl];
}

- (void)postMessageEvent:(NSString*)message
{
    if (self.webMessageChannel == nil) {
        return;
    }
    [self.webMessageChannel postMessageEvent:message];
}

- (void)postMessageEventExt:(id)message {
    if (self.webMessageChannel) {
        [self.webMessageChannel postMessageEventExt:message];
    }
}

- (void)onMessageEvent:(void (^)(NSString* ocResult))callback
{
    self.messageCallBack = callback;
}

- (void)onMessageEventExt:(void (^)(id _Nullable ocResult))callback
{
    self.messageCallBackExt = callback;
}

- (void)closePort
{
    if (self.webMessageChannel == nil) {
        return;
    }
    [self.webMessageChannel closePort];
}

+ (bool)saveHttpAuthCredentials:(NSString*)host
                          realm:(NSString*)realm
                       username:(NSString*)username
                       password:(NSString*)password
{
    NSLog(@"AceWeb: saveHttpAuthCredentials called");
    if (host == nil || realm == nil || username == nil || password == nil) {
        return false;
    }

    NSURLCredential* credential =
        [NSURLCredential credentialWithUser:username password:password persistence:NSURLCredentialPersistencePermanent];
    NSURLProtectionSpace* protectionSpace =
        [[NSURLProtectionSpace alloc] initWithHost:host
                                              port:0
                                          protocol:NSURLProtectionSpaceHTTP
                                             realm:realm
                              authenticationMethod:NSURLAuthenticationMethodDefault];
    [[NSURLCredentialStorage sharedCredentialStorage] setDefaultCredential:credential
                                                        forProtectionSpace:protectionSpace];
    return true;
}

+ (NSURLCredential*)getHttpAuthCredentials:(NSString*)host realm:(NSString*)realm
{
    if (host == nil || realm == nil) {
        return nil;
    }
    NSURLProtectionSpace* protectionSpace =
        [[NSURLProtectionSpace alloc] initWithHost:host
                                              port:0
                                          protocol:NSURLProtectionSpaceHTTP
                                             realm:realm
                              authenticationMethod:NSURLAuthenticationMethodDefault];
    NSDictionary* userToCredentialMap =
        [[NSURLCredentialStorage sharedCredentialStorage] credentialsForProtectionSpace:protectionSpace];
    return userToCredentialMap.allValues.lastObject;
}

+ (bool)existHttpAuthCredentials
{
    NSLog(@"AceWeb: existHttpAuthCredentials called");
    NSURLCredentialStorage* store = [NSURLCredentialStorage sharedCredentialStorage];
    if ([[store allCredentials] count] > 0) {
        return true;
    }
    return false;
}

+ (bool)deleteHttpAuthCredentials
{
    NSLog(@"AceWeb: deleteHttpAuthCredentials called");
    NSURLCredentialStorage* store = [NSURLCredentialStorage sharedCredentialStorage];
    if (store == nil) {
        return false;
    }

    for (NSURLProtectionSpace* protectionSpace in [store allCredentials]) {
        NSDictionary* userToCredentialMap =
            [[NSURLCredentialStorage sharedCredentialStorage] credentialsForProtectionSpace:protectionSpace];
        for (NSString* user in userToCredentialMap) {
            NSURLCredential* credential = [userToCredentialMap objectForKey:user];
            [store removeCredential:credential forProtectionSpace:protectionSpace];
        }
    }
    return true;
}

- (bool)accessStep:(NSInteger)step
{
    if(step >= 0 && self.webView.backForwardList.forwardList.count >= step){
        return true;
    }

    if(step < 0 && self.webView.backForwardList.backList.count >= abs(step)){
        return true;
    }
    return false;
}

- (void)scrollTo:(CGFloat)x y:(CGFloat)y
{
    if ([[NSString stringWithFormat:@"%f", x] isEqualToString:@"nan"] || 
        [[NSString stringWithFormat:@"%f", y] isEqualToString:@"nan"]){
        x = 0.f;
        y = 0.f;
    }

    CGFloat offsetX = 0.f;
    CGFloat offsetY = 0.f;
    if (self.webView.scrollView.contentSize.width > self.webView.frame.size.width) {
        offsetX = x < 0 ? 0 : x;
    }
    if (self.webView.scrollView.contentSize.height > self.webView.frame.size.height) {
        offsetY = y < 0 ? 0 : y;
    }
    [self.webView.scrollView setContentOffset:CGPointMake(offsetX, offsetY) animated:YES];
}

- (void)scrollBy:(CGFloat)deltaX deltaY:(CGFloat)deltaY
{
    if ([[NSString stringWithFormat:@"%f", deltaX] isEqualToString:@"nan"] || 
        [[NSString stringWithFormat:@"%f", deltaY] isEqualToString:@"nan"]){
        deltaX = 0.f;
        deltaY = 0.f;
    }

    CGFloat offsetX = 0.f;
    CGFloat offsetY = 0.f;
    if (self.webView.scrollView.contentSize.width > self.webView.frame.size.width) {
        offsetX = self.webView.scrollView.contentOffset.x + deltaX;
    }
    if (self.webView.scrollView.contentSize.height > self.webView.frame.size.height) {
        offsetY = self.webView.scrollView.contentOffset.y + deltaY;
    }
    [self.webView.scrollView setContentOffset:CGPointMake(offsetX < 0 ? 0 : offsetX, offsetY < 0 ? 0 : offsetY)
                                     animated:YES];
}

- (void)zoom:(CGFloat)factor
{
    if(factor > 0 && factor <= 100) {
        [self.webView.scrollView setZoomScale:self.webView.scrollView.zoomScale * factor];
    }
}

- (void)zoomIn {
    UIScrollView *scrollView = self.webView.scrollView;
    CGFloat zoomInValue = scrollView.zoomScale * ZOOMIN_SCALE_VALUE;
    [scrollView setZoomScale:zoomInValue];
}

- (void)zoomOut {
    UIScrollView *scrollView = self.webView.scrollView;
    CGFloat zoomOutValue = scrollView.zoomScale * ZOOMOUT_SCALE_VALUE;
    [scrollView setZoomScale:zoomOutValue];
}

+ (BOOL)getWebDebuggingAccess {
    return _webDebuggingAccessInit;
}

+ (void)setWebDebuggingAccess:(bool)webDebuggingAccess
{
    _webDebuggingAccessInit = webDebuggingAccess == 1 ? YES : NO;
}

- (void)pageDown:(bool)value
{
    UIScrollView *scrollView = self.webView.scrollView;
    CGFloat screenHeight = scrollView.bounds.size.height;
    CGFloat contentHeight = scrollView.contentSize.height - screenHeight;
    CGPoint currentOffset = scrollView.contentOffset;
    CGPoint newOffset;
    if(value) {
        newOffset = CGPointMake(currentOffset.x, contentHeight);
    } else {
        CGFloat halfScreenHeight = screenHeight / WEBVIEW_PAGE_HALF;
        newOffset = CGPointMake(currentOffset.x, MIN(contentHeight, currentOffset.y + halfScreenHeight));
    }
    [scrollView setContentOffset:newOffset animated:YES];
}

- (void)postUrl:(NSString*)url postData:(NSData *)postData {
    if (!url) {
        NSLog(@"Error:AceWeb: url is NULL");
        return;
    }
    NSURL *nsUrl = [NSURL URLWithString:url];
    if (!nsUrl) {
        NSLog(@"Error:AceWeb: nsUrl is NULL");
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:nsUrl];
    if (request) {
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:postData];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [self.webView loadRequest:request];
    }
}

- (void)stop
{
    [self.webView stopLoading];
}

- (bool)isZoomAccess
{
    return self.allowZoom;
}

- (NSString*)getOriginalUrl
{
    if(self.webView &&
        self.webView.backForwardList &&
        self.webView.backForwardList.currentItem &&
        self.webView.backForwardList.currentItem.initialURL)
    {
        return self.webView.backForwardList.currentItem.initialURL.absoluteString;
    }
    return @"";
}

- (void)pageUp:(bool)value
{
    UIScrollView* scrollView = self.webView.scrollView;
    CGFloat contentHeight = scrollView.contentOffset.y;
    CGFloat viewHeight = scrollView.bounds.size.height / WEBVIEW_PAGE_HALF;
    CGPoint offset;
    if (value) {
        offset = CGPointMake(0, 0);
    } else {
        offset = CGPointMake(0, MAX(0, contentHeight - viewHeight));
    }
    [scrollView setContentOffset:offset animated:YES];
}

- (void)setCustomUserAgent:(NSString*)userAgent
{
    [self.webView setCustomUserAgent:userAgent];
}

- (NSString*)getCustomUserAgent
{
    return [self.webView customUserAgent];
}

- (void)initConfigure
{
    self.callSyncMethodMap = [[NSMutableDictionary alloc] init];
    self.downloadTasksDic = [[NSMutableDictionary alloc] init];
    self.schemeHandlerMap = [[NSMutableDictionary alloc] init];
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

-(int64_t)getWebId
{
    return self.incId;
}

-(void)startDownload:(NSString*)url
{
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.HTTPMaximumConnectionsPerHost = 1; 
    if (!self.session) {
        self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    }
    NSURLSessionDownloadTask* downloadTask = [self.session downloadTaskWithURL:[NSURL URLWithString:url]];
    NSString* guid = [NSString stringWithFormat:@"%lld_%lu", self.incId, downloadTask.taskIdentifier];
    NSString* method = downloadTask.originalRequest.HTTPMethod ? downloadTask.originalRequest.HTTPMethod : @"";
    NSString* mimeType = downloadTask.response.MIMEType ? downloadTask.response.MIMEType : @"";
    DownloadTaskInfo* downloadTaskInfo = [[DownloadTaskInfo alloc] init];
    downloadTaskInfo.isDownload = false;
    downloadTaskInfo.downloadTask = downloadTask;
    downloadTaskInfo.filePath = @"";
    downloadTaskInfo.lastUpdateTime = [NSDate date];
    [self.downloadTasksDic setObject:downloadTaskInfo forKey:guid];
    if (self.onDownloadBeforeStartCallBack) {
        self.onDownloadBeforeStartCallBack(guid, method, mimeType, url);
    }
}

-(void)onDownloadBeforeStart:(void (^)(NSString* guid, NSString *method,
                                    NSString *mimeType, NSString *url))callback
{
    self.onDownloadBeforeStartCallBack = callback;
}

- (void)onDownloadUpdated:(void (^)(NSString* guid, NSString* state, int64_t totalBytes,
                                int64_t receivedBytes, NSString *suggestedFileName))callback
{
    self.onDownloadUpdatedCallBack = callback;
}

- (void)onDownloadFailed:(void (^)(NSString* guid, NSString* state, int64_t code))callback
{
    self.onDownloadFailedCallBack = callback;
}

- (void)onDownloadFinish:(void (^)(NSString* guid, NSString* path))callback
{
    self.onDownloadFinishCallBack = callback;
}

-(bool)webDownloadItemStart:(NSString*)guid ocPath:(NSString*) ocPath
{
    DownloadTaskInfo* downloadTaskInfo = [self.downloadTasksDic objectForKey:guid];
    if (!downloadTaskInfo) {
        return false;
    }
    NSURLSessionDownloadTask* downloadTask = downloadTaskInfo.downloadTask;
    if (downloadTask) {
        downloadTaskInfo.isDownload = true;
        downloadTaskInfo.filePath = ocPath;
        [downloadTask resume];
        return true;
    }
    return false;
}

- (bool)webDownloadItemCancel:(NSString*)guid
{
    DownloadTaskInfo* downloadTaskInfo = [self.downloadTasksDic objectForKey:guid];
    if (!downloadTaskInfo) {
        return false;
    }
    NSURLSessionDownloadTask* downloadTask = downloadTaskInfo.downloadTask;
    if (downloadTask) {
        [self.downloadTasksDic removeObjectForKey:guid];
        [downloadTask cancel];
        self.onDownloadFailedCallBack(guid, @"CANCELED", 0);
        for (NSString* key in self.downloadTasksDic) {
            DownloadTaskInfo* info = [self.downloadTasksDic objectForKey:key];
            info.lastUpdateTime = [NSDate date];
        }
        return true;
    }
    return false;
}

- (bool)webDownloadItemPause:(NSString*)guid
{
    DownloadTaskInfo* downloadTaskInfo = [self.downloadTasksDic objectForKey:guid];
    if (!downloadTaskInfo) {
        return false;
    }
    NSURLSessionDownloadTask* downloadTask = downloadTaskInfo.downloadTask;
    if (downloadTask && downloadTaskInfo.isDownload) {
        downloadTaskInfo.isDownload = false;
        [downloadTask suspend];
        self.onDownloadUpdatedCallBack(guid, @"PAUSED", 0, 0, @"");
        for (NSString* key in self.downloadTasksDic) {
            DownloadTaskInfo* info = [self.downloadTasksDic objectForKey:key];
            info.lastUpdateTime = [NSDate date];
        }
        return true;
    }
    return false;
}

- (bool)webDownloadItemResume:(NSString*)guid
{
    DownloadTaskInfo* downloadTaskInfo = [self.downloadTasksDic objectForKey:guid];
    if (!downloadTaskInfo) {
        return false;
    }
    NSURLSessionDownloadTask* downloadTask = downloadTaskInfo.downloadTask;
    if (downloadTask && !downloadTaskInfo.isDownload) {
        downloadTaskInfo.isDownload = true;
        self.onDownloadUpdatedCallBack(guid, @"PENDING", 0, 0, @"");
        for (NSString* key in self.downloadTasksDic) {
            DownloadTaskInfo* info = [self.downloadTasksDic objectForKey:key];
            info.lastUpdateTime = [NSDate date];
        }
        [downloadTask resume];
        return true;
    }
    return false;
}

- (void)registerJavaScriptMethods:(NSArray*)syncMethodList
                  asyncMethodList:(NSArray*)asyncMethodList
                          objName:(NSString*)objName
{
    if ((syncMethodList == nil && asyncMethodList == nil) || objName == nil) {
        NSLog(@"Error: AceWeb: registerJavaScriptMethods parameters are nil");
        return;
    }
    for (NSString* method in syncMethodList) {
        NSString* js = [NSString stringWithFormat:
            @"window.%@ = window.%@ || {};"
            "window.%@.%@ = function(...args) {"
            "window.webkit.messageHandlers.AceWebHandler.postMessage({ class: '%@', method: '%@', params: args });"
            "   return new Promise((resolve, reject) => {"
            "       try {"
            "           window.%@.%@.resolve = resolve;"
            "       } catch (e) {"
            "           reject(e.toString());"
            "       }"
            "   });"
            "};", objName, objName, objName, method, objName, method, objName, method];
        [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError* error) {}];
    }

    for (NSString* method in asyncMethodList) {
        NSString* js = [NSString stringWithFormat:
            @"window.%@ = window.%@ || {};"
            "window.%@.%@ = function(...args) {"
            "window.webkit.messageHandlers.AceWebHandler.postMessage({ class: '%@', method: '%@', params: args });"
            "};", objName, objName, objName, method, objName, method];
        [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError* error) {}];
    }
}

- (void)registerJavaScriptProxy:(NSString*)objName
                 syncMethodList:(NSArray*)syncMethodList
                asyncMethodList:(NSArray*)asyncMethodList
                       callback:(id (^)(NSString* objName, NSString* methodName, NSArray* args))callback
{
    NSLog(@"registerJavaScriptProxy objName is : %@", objName);
    if (!self.jsReady) {
        self.syncMethodList = syncMethodList;
        self.asyncMethodList = asyncMethodList;
        self.objName = objName;
    }
    [self registerJavaScriptMethods:syncMethodList asyncMethodList:asyncMethodList objName:objName];
    self.onJavaScriptFunctionCallBack = callback;
}

- (void)deleteJavaScriptRegister:(NSString*)objName
{
    NSLog(@"deleteJavaScriptRegister objName is : %@", objName);
    NSString* js = [NSString stringWithFormat:@"delete window.%@;", objName];
    [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError* error) {}];
    self.syncMethodList = nil;
    self.asyncMethodList = nil;
    self.objName = nil;
    self.onJavaScriptFunctionCallBack = nil;
}

- (BOOL)setWebSchemeHandler:(NSString*)scheme handler:(const ArkWeb_SchemeHandler*)handler
{
    if (scheme == nil || handler == nullptr) {
        return NO;
    }

    NSValue* existingHandlerValue = [self.schemeHandlerMap objectForKey:scheme];
    if (existingHandlerValue) {
        ArkWeb_SchemeHandler* existingHandler = (ArkWeb_SchemeHandler*)[existingHandlerValue pointerValue];
        if (existingHandler) {
            [self.schemeHandlerMap removeObjectForKey:scheme];
        }
    }
    NSValue* handlerValue = [NSValue valueWithPointer:handler];
    [self.schemeHandlerMap setObject:handlerValue forKey:scheme];
    return YES;
}

- (BOOL)clearWebSchemeHandler
{
    if (self.schemeHandlerMap == nil) {
        return NO;
    }
    [self.schemeHandlerMap removeAllObjects];
    return YES;
}

- (ArkWeb_SchemeHandler*)getSchemeHandler:(NSString*)scheme
{
    if (scheme == nil || self.schemeHandlerMap == nil) {
        return nullptr;
    }
    
    NSValue* handlerValue = [self.schemeHandlerMap objectForKey:scheme];
    if (handlerValue) {
        return (ArkWeb_SchemeHandler*)[handlerValue pointerValue];
    }
    
    return nullptr;
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
    // updateRichText callback
    [self setRichText];
    // updateLayout callback
    [self setUpdateLayout];
    // touchDown callback
    [self setTouchDownCallback];
    // touchMove callback
    [self setTouchMoveCallback];
    // touchUp callback
    [self setTouchUpCallback];
    // textZoomRatio callback
    [self updateTextZoomRatio];

    [self enterFullScreenOrExitFullScreenNotifi];
}

- (void)enterFullScreenOrExitFullScreenNotifi
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(beginFullScreen:) name:UIWindowDidBecomeVisibleNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endFullScreen:) name:UIWindowDidBecomeHiddenNotification object:nil];
}

- (void)beginFullScreen:(NSNotification *)notify
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, DELAY_TIME * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self ergodicKeyWindow];
        [self setVideoSize];
    });
}

- (void)ergodicKeyWindow
{
    NSArray *arr = [[[UIApplication sharedApplication] connectedScenes] allObjects];
    UIWindowScene *windowScene = (UIWindowScene *)arr[0];
    UIWindow *keyWindow = windowScene.keyWindow;
    for (UIView *transitionView in keyWindow.subviews) {
        if ([transitionView isKindOfClass:NSClassFromString(@"UITransitionView")]) {
            [self findFullScreen:transitionView];
        }
    }
}

- (void)setVideoSize
{
    CGFloat width = 0;
    CGFloat height = 0;
    NSURL *url = [NSURL URLWithString:self.videoSrc];
    AVURLAsset *asset = [AVURLAsset assetWithURL:url];
    NSArray *nSAarray = asset.tracks;
    CGSize videoSize = CGSizeZero;
    for (AVAssetTrack *track in nSAarray) {
        if ([track.mediaType isEqualToString:AVMediaTypeVideo]) {
            videoSize = track.naturalSize;
            width = videoSize.width;
            height = videoSize.height;
        }
    }
    
    AceWebFullScreenEnterObject* obj = new AceWebFullScreenEnterObject(width, height);
    FullEnterRequestExitMethod fullEnterRequestExit_callback = ^void() {
      @try {
          if ([self.viewExitFullScreen respondsToSelector:NSSelectorFromString(@"fullScreenButtonWasPressed")]) {
            [self.viewExitFullScreen performSelector:NSSelectorFromString(@"fullScreenButtonWasPressed")];
          } else if (self.viewControllerExitFull && [self.viewControllerExitFull respondsToSelector:NSSelectorFromString(@"doneButtonTapped:")]) {
            [self.viewControllerExitFull performSelector:NSSelectorFromString(@"doneButtonTapped:")];
          } else {
            NSLog(@"Error: exit button not found");
          }
      } @catch (NSException* exception) {
          NSLog(@"Error: ExitScreen call failed, reason: %@", exception.reason);
      }
    };
    obj->SetFullEnterRequestExitCallback(fullEnterRequestExit_callback);
    AceWebObject([[self event_hashFormat:NTC_ONFULLSCREENENTER] UTF8String], [NTC_ONFULLSCREENENTER UTF8String], obj);
}

- (void)findFullScreen:(UIView *)view
{
    for (UIView *subView in view.subviews) {
        id nextResponder = [subView nextResponder];
        if ([nextResponder isKindOfClass:NSClassFromString(@"AVFullScreenViewController")]) {

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, DELAY_TIME * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self findCloseBtn:subView];
            });
            break;
        } else if ([subView isKindOfClass:NSClassFromString(@"UIDropShadowView")]) {
            [self findFullScreen:subView];
            break;
        } else if ([nextResponder isKindOfClass:NSClassFromString(@"AVPlayerViewController")]) {
            self.viewControllerExitFull = nextResponder;
            break;
        } else if ([nextResponder isKindOfClass:[UIViewController class]]) {
            [self findFullScreen:subView];
            break;
        } 
    }
}

- (void)findCloseBtn:(UIView *)view
{
    for (int i = 0; i < view.subviews.count; i++) {
        UIView *viewTemp = view.subviews[i];

        if ([viewTemp isKindOfClass:NSClassFromString(@"AVPlayerViewControllerContentView")]) {
            [self findCloseBtn:viewTemp];
            return;
        }

        if ([viewTemp isKindOfClass:NSClassFromString(@"AVMobileChromelessControlsView")]) {
            [self findCloseBtn:viewTemp];
            return;
        }

        if ([viewTemp isKindOfClass:NSClassFromString(@"AVMobileChromelessDisplayModeControlsView")]) {
            NSLog(@"find success");
            self.viewExitFullScreen = viewTemp;
            return;
        }
    }
}

- (void)endFullScreen:(NSNotification *)notify
{
    AceWebFullScreenExitObject* obj = new AceWebFullScreenExitObject();
    AceWebObject([[self event_hashFormat:NTC_ONFULLSCREENEXIT] UTF8String], [NTC_ONFULLSCREENEXIT UTF8String], obj);
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

- (void)setRichText
{
    __weak __typeof(self) weakSelf = self;
    NSString* richText_method_hash = [self method_hashFormat:NTC_RICHTEXT_LOADDATA];
    IAceOnCallSyncResourceMethod richText_callback = ^NSString*(NSDictionary* param)
    {
        NSString* data = [param objectForKey:WEBVIEW_LOADDATA_DATA];
        NSString* type = [param objectForKey:WEBVIEW_LOADDATA_MIMETYPE];
        NSString* encodingName = [param objectForKey:WEBVIEW_LOADDATA_ENCODING];
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            strongSelf.isLoadRichText = true;
            [strongSelf loadData:data mimeType:type encoding:encodingName baseUrl:@"" historyUrl:@""];
            return SUCCESS;
        } else {
            NSLog(@"AceWeb: set richText fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[richText_callback copy] forKey:richText_method_hash];
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

- (void)updateTextZoomRatio
{
    __weak __typeof(self) weakSelf = self;
    NSString *text_zoom_ratio_hash = [self method_hashFormat:NTC_TEXT_ZOOM_RATIO];
    IAceOnCallSyncResourceMethod text_zoom_ratio_callback = ^NSString *(NSDictionary * param) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        NSInteger textZoomRatio = [[param objectForKey:NTC_TEXT_ZOOM_RATIO] integerValue];
        if (strongSelf) {
            strongSelf.textZoomRatio = textZoomRatio;
            if (strongSelf.jsReady) {
                [strongSelf updateTextZoomRatio:textZoomRatio];
            }
            return SUCCESS;
        } else {
            NSLog(@"AceWeb: textZoomRatio fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[text_zoom_ratio_callback copy] forKey:text_zoom_ratio_hash];
}

- (void)updateTextZoomRatio:(NSInteger)textZoomRatio {
    NSString* js = [NSString stringWithFormat:
        @"var style = document.createElement('style');"
        @"style.innerHTML = 'body { -webkit-text-size-adjust: %d%% !important; }';"
        @"document.head.appendChild(style);",
        textZoomRatio];
    [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError* error) {
        if (error) {
            NSLog(@"AceWeb: updateTextZoomRatio evaluateJavaScript error: %@", error.localizedDescription);
        }
    }];
}

- (NSString *)method_hashFormat:(NSString *)method
{
    return [NSString stringWithFormat:@"%@%lld%@%@%@%@", WEB_FLAG, self.incId, METHOD, PARAM_EQUALS, method, PARAM_BEGIN];
}

- (NSString *)event_hashFormat:(NSString *)method
{
    return [NSString stringWithFormat:@"%@%lld%@%@%@%@", WEB_FLAG, self.incId, EVENT, PARAM_EQUALS, method, PARAM_BEGIN];
}

-(NSString*)updateWebLayout:(NSDictionary*)paramMap
{
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

- (void)releaseObject
{
    NSLog(@"AceWeb releaseObject");
    [self.webView removeObserver:self forKeyPath:ESTIMATEDPROGRESS];
    [self.webView removeObserver:self forKeyPath:TITLE];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:CONSOLELOG];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:CONSOLEINFO];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:CONSOLEERROR];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:CONSOLEDEBUG];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:CONSOLEWARN];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.callSyncMethodMap) {
        for (id key in self.callSyncMethodMap) {
            IAceOnCallSyncResourceMethod block = [self.callSyncMethodMap objectForKey:key];
            block = nil;
        }
        [self.callSyncMethodMap removeAllObjects];
        self.callSyncMethodMap = nil;
    }
    [self.webView removeFromSuperview];
    self.webView = nil;
    self.preferences = nil;
    self.webpagePreferences = nil;
    self.target = nil;
    [self stopGCDTimer];

    if (self.schemeHandlerMap) {
        for (NSString* scheme in self.schemeHandlerMap) {
            NSValue* handlerValue = [self.schemeHandlerMap objectForKey:scheme];
            if (handlerValue) {
                ArkWeb_SchemeHandler* handler = (ArkWeb_SchemeHandler*)[handlerValue pointerValue];
                if (handler) {
                    delete handler;
                }
            }
        }
        [self.schemeHandlerMap removeAllObjects];
        self.schemeHandlerMap = nil;
    }
}

- (NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *)getSyncCallMethod
{
    return self.callSyncMethodMap;
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    NSLog(@"didFailNavigation === ");
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
    NSString *param = [NSString stringWithFormat:@"%@",webView.URL];
    if (self.isLoadRichText) {
        return;
    }
    [self fireCallback:@"onPageStarted" params:param];
    [self fireCallback:@"onPageVisible" params:param];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    if(!self.jsReady) {
        [self registerJavaScriptMethods:self.syncMethodList 
            asyncMethodList:self.asyncMethodList objName:self.objName];
    }
    self.jsReady = true;
    [self updateTextZoomRatio:self.textZoomRatio];
    NSString *param = [NSString stringWithFormat:@"%@",webView.URL];
    if (self.isLoadRichText) {
        self.isLoadRichText = false;
        return;
    }
    [self fireCallback:@"onPageFinished" params:param];
    bool isRefreshed = false;
    NSString *currrentUrl= webView.URL.absoluteString;
    if (self.reloadUrl && [currrentUrl isEqualToString:self.reloadUrl]) {
        isRefreshed = true;
        self.reloadUrl = @"";
    }
    NSString *url = self.webView.URL.absoluteString;
    AceWebRefreshAccessedHistoryObject *obj = new AceWebRefreshAccessedHistoryObject(std::string([url UTF8String]), isRefreshed);
    AceWebObject([[self event_hashFormat:NTC_ONREFRESHACCESSED_HISTORYEVENT] UTF8String], [NTC_ONREFRESHACCESSED_HISTORYEVENT UTF8String], obj);
}

- (void)releaseResourceRequest {
    if (self.currentResourceRequest) {
        delete self.currentResourceRequest;
        self.currentResourceRequest = nullptr;
    }
    if (self.currentResourceHandler) {
        delete self.currentResourceHandler;
        self.currentResourceHandler = nullptr;
    }
}

- (void)handleInterceptedRequest:(NSString*)requestURL 
                         handler:(ArkWeb_SchemeHandler*)handler
                         webView:(WKWebView*)webView {
    if (!self.currentResourceHandler || !self.currentResourceHandler->response_) {
        return;
    }

    if (self.currentResourceHandler->response_->errorCode_ != 0) {
            AceWebErrorReceiveInfoObject *obj = new AceWebErrorReceiveInfoObject(std::string([requestURL UTF8String]),
            self.currentResourceHandler->response_->errorDescription_,
            self.currentResourceHandler->response_->errorCode_);
        AceWebObject([[self event_hashFormat:@"onErrorReceive"] UTF8String], [@"onErrorReceive" UTF8String], obj);
    } else if (self.currentResourceHandler->isFailed_) {
        AceWebErrorReceiveInfoObject *obj = new AceWebErrorReceiveInfoObject(std::string([requestURL UTF8String]),
            self.currentResourceHandler->errorDescription_, self.currentResourceHandler->errorCode_);
        AceWebObject([[self event_hashFormat:@"onErrorReceive"] UTF8String], [@"onErrorReceive" UTF8String], obj);
    } 

    if (self.currentResourceHandler->response_->url_.empty()) {
        NSString* customURL = [NSString stringWithFormat:@"%@://%@", CUSTOM_SCHEME_HANDLER, requestURL];
        NSURLRequest* newRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:customURL]];
        [webView loadRequest:newRequest];
    } else if (self.currentResourceHandler->response_->errorCode_ == 0) {
        NSString* responseURL = [NSString stringWithUTF8String:self.currentResourceHandler->response_->url_.c_str()];
        NSURL* url = [NSURL URLWithString:responseURL];
        if (url == nil || url.scheme == nil) {
            NSString* combinedURL = [NSString stringWithFormat:@"%@%@", requestURL, responseURL];
            url = [NSURL URLWithString:combinedURL];
        }
        NSURLRequest* newRequest = [NSURLRequest requestWithURL:url];
        [webView loadRequest:newRequest];
    }
    
    if (handler->on_request_stop && (self.currentResourceHandler->isFinished_ ||
        self.currentResourceHandler->isFailed_ || self.currentResourceHandler->response_->errorCode_ != 0)) {
        handler->on_request_stop(handler, self.currentResourceRequest);
    }
    if (!self.currentResourceHandler->response_->url_.empty()) {
        [self releaseResourceRequest];
    }
}

- (void)handleCustomSchemeRequest:(NSURLRequest*)request 
                     responseData:(NSData**)responseData 
                         response:(NSHTTPURLResponse**)response {
    if (self.currentResourceHandler && self.currentResourceHandler->response_) {
        *responseData = [NSData dataWithBytes:self.currentResourceHandler->buffer_.c_str()
            length:self.currentResourceHandler->bufferLen_];
        if (self.currentResourceHandler->response_->mimeType_.empty() ||
            self.currentResourceHandler->response_->mimeType_.length() <= 0) {
            const_cast<ArkWeb_Response*>(self.currentResourceHandler->response_)->mimeType_ = "text/html";
        }
        NSString* contentType = [NSString stringWithFormat:@"%@;charset=%@;",
            [NSString stringWithUTF8String:self.currentResourceHandler->response_->mimeType_.c_str()],
            [NSString stringWithUTF8String:self.currentResourceHandler->response_->encoding_.c_str()]];
        NSMutableDictionary* headers = [NSMutableDictionary dictionaryWithDictionary:@{
            @"Content-Type": contentType,
            @"Content-Length": [@((*responseData).length) stringValue],
            @"Reason-Phrase": [NSString stringWithUTF8String:self.currentResourceHandler->response_->statusText_.c_str()]
        }];
        for (const auto& header : self.currentResourceHandler->response_->headers_) {
            NSString* key = [NSString stringWithUTF8String:header.first.c_str()];
            NSString* value = [NSString stringWithUTF8String:header.second.c_str()];
            [headers setObject:value forKey:key];
        }
        *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
            statusCode:self.currentResourceHandler->response_->status_ HTTPVersion:@"HTTP/1.1"
            headerFields:headers];
    }
    [self releaseResourceRequest];
}

- (void)handleAceWebResponse:(id<WKURLSchemeTask>)urlSchemeTask {
    const auto& AceWebResponse = AceWebObjectGetResponse();
    if (!AceWebResponse) {
        NSLog(@"AceWeb: onInterceptRequest fail");
        NSError *error = [NSError errorWithDomain:@"onInterceptRequest fail" code:HTTP_STATUS_GATEWAY_TIMEOUT userInfo:nil];
        [urlSchemeTask didFailWithError:error];
        return;
    }
    __weak __typeof(self) weakSelf = self;
    [self startGCDTimer:^(bool timeout) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (!strongSelf) {
            NSLog(@"AceWeb: onInterceptRequest fail");
            NSError *error = [NSError errorWithDomain:@"onInterceptRequest fail" code:HTTP_STATUS_GATEWAY_TIMEOUT userInfo:nil];
            [urlSchemeTask didFailWithError:error];
            return;
        }
        NSURLRequest* request = urlSchemeTask.request;
        if (timeout) {
            dispatch_async(dispatch_get_main_queue(), ^{
                const std::string& rawData = "<html><body><h1>Response Timeout</h1><p>The request has timed out.</p></body></html>";
                NSData* responseData = [NSData dataWithBytes:rawData.c_str() length:rawData.size()];
                NSString* contentType = @"text/html;charset=tf-8;";
                NSMutableDictionary* headers = [NSMutableDictionary dictionaryWithDictionary:@{
                    @"Content-Type": contentType,
                    @"Content-Length": [@(responseData.length) stringValue],
                    @"Reason-Phrase": @"Response timed out"
                }];
                NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                    statusCode:HTTP_STATUS_GATEWAY_TIMEOUT HTTPVersion:@"HTTP/1.1"
                    headerFields:headers];
                [urlSchemeTask didReceiveResponse:response];
                [urlSchemeTask didReceiveData:responseData];
                [urlSchemeTask didFinish];
                [strongSelf stopGCDTimer];
            });
            return;
        }
        bool isReady = AceWebResponse->GetResponseStatus();
        if (isReady) {
            dispatch_async(dispatch_get_main_queue(), ^{
                const std::string& rawData = AceWebResponse->GetData();
                NSData* responseData = [NSData dataWithBytes:rawData.c_str() length:rawData.size()];
                NSString* contentType = [NSString stringWithFormat:@"%@;charset=%@;",
                    [NSString stringWithUTF8String:AceWebResponse->GetMimeType().c_str()],
                    [NSString stringWithUTF8String:AceWebResponse->GetEncoding().c_str()]];
                NSMutableDictionary* headers = [NSMutableDictionary dictionaryWithDictionary:@{
                    @"Content-Type": contentType,
                    @"Content-Length": [@(responseData.length) stringValue],
                    @"Reason-Phrase": [NSString stringWithUTF8String:AceWebResponse->GetReason().c_str()]
                }];
                const auto& cppHeaders = AceWebResponse->GetHeaders();
                for (const auto& header : cppHeaders) {
                    NSString* key = [NSString stringWithUTF8String:header.first.c_str()];
                    NSString* value = [NSString stringWithUTF8String:header.second.c_str()];
                    [headers setObject:value forKey:key];
                }
                NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                    statusCode:AceWebResponse->GetStatusCode() HTTPVersion:@"HTTP/1.1"
                    headerFields:headers];
                [urlSchemeTask didReceiveResponse:response];
                [urlSchemeTask didReceiveData:responseData];
                [urlSchemeTask didFinish];
                [strongSelf stopGCDTimer];
            });
        }
    }];
}

- (void)startGCDTimer:(nonnull void (^)(bool timeout))block {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(TIMEOUT_S * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (_timer) {
            block(true);
        }
    });
    if (!_timer) {
        dispatch_queue_t queue = dispatch_queue_create("com.arkuix.timer.queue", DISPATCH_QUEUE_SERIAL);
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, POLLING_INTERVAL_MS * NSEC_PER_MSEC, 10 * NSEC_PER_MSEC);
        dispatch_source_set_event_handler(_timer, ^{
            block(false);
        });
        dispatch_resume(_timer);
    }
}

- (void)stopGCDTimer {
    if (_timer) {
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
}

#pragma mark - WKURLSchemeHandler
- (void)webView:(WKWebView *)webView startURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask {
    NSURLRequest* request = urlSchemeTask.request;
    if ([request.URL.scheme isEqualToString:CUSTOM_SCHEME_HANDLER]) {
        NSHTTPURLResponse* response = nil;
        NSData* responseData = nil;
        NSError* error = nil;
        [self handleCustomSchemeRequest:request responseData:&responseData response:&response];
        [urlSchemeTask didReceiveResponse:response];
        [urlSchemeTask didReceiveData:responseData];
        [urlSchemeTask didFinish];
    } else {
        [self handleAceWebResponse:urlSchemeTask];
    }
}

- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask {
    ArkWeb_SchemeHandler* handler = [self getSchemeHandler:urlSchemeTask.request.URL.scheme];
    if (handler && handler->on_request_stop) {
        handler->on_request_stop(handler, self.currentResourceRequest);
    }
    [self stopGCDTimer];
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSString* requestURL =
            navigationAction.request.URL.absoluteString ? navigationAction.request.URL.absoluteString : @"";
    NSString *referer = navigationAction.request.allHTTPHeaderFields[@"Referer"];
    self.referrer = referer ? referer : @"";
    if (navigationAction.targetFrame.isMainFrame) {
        self.isMainFrame = YES;
        self.mainFrameUrl = requestURL;
    }
    if (navigationAction.navigationType == WKNavigationTypeReload ||
        (navigationAction.navigationType == WKNavigationTypeBackForward &&
        requestURL &&
        [requestURL isEqualToString:webView.backForwardList.currentItem.URL.absoluteString])) {
        self.reloadUrl = requestURL;
    }
    if ([self handleOverrideUrlLoading:navigationAction decisionHandler:decisionHandler]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    AceWebErrorReceiveInfoObject* obj = new AceWebErrorReceiveInfoObject(std::string([requestURL UTF8String]), "", 0);
    if (AceWebObjectWithBoolReturn(
            [[self event_hashFormat:NTC_ONLOADINTERCEPT] UTF8String], [NTC_ONLOADINTERCEPT UTF8String], obj)) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    if (![requestURL hasPrefix:[NSString stringWithFormat:@"%@://", CUSTOM_SCHEME]] && AceWebObjectWithResponseReturn(
            [[self event_hashFormat:NTC_ONINTERCEPTREQUEST] UTF8String], [NTC_ONINTERCEPTREQUEST UTF8String], obj)) {
        NSString* customURL = [NSString stringWithFormat:@"%@://%@", CUSTOM_SCHEME, requestURL];
        NSURLRequest* newRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:customURL]];
        [webView loadRequest:newRequest];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    NSString* requestScheme = navigationAction.request.URL.scheme;
    ArkWeb_SchemeHandler* handler = [self getSchemeHandler:requestScheme];
    if (handler && handler->on_request_start) {
        bool intercept = false;
        self.currentResourceRequest = CreateResourceRequest(navigationAction);
        self.currentResourceHandler = new ArkWeb_ResourceHandler();
        handler->on_request_start(handler, self.currentResourceRequest,
            self.currentResourceHandler, &intercept);
        if (intercept) {
            [self handleInterceptedRequest:requestURL
                                   handler:handler
                                   webView:webView];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        } else {
            [self releaseResourceRequest];
        }
    }
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 140500
    if (@available(iOS 14.5, *)) {
        if (navigationAction.shouldPerformDownload) {
            decisionHandler(WKNavigationActionPolicyDownload);
            return;
        }
    }
#endif
    decisionHandler(WKNavigationActionPolicyAllow);
    return;
}

- (BOOL)handleOverrideUrlLoading:(WKNavigationAction *)navigationAction decisionHandler:
(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSString* url =
            navigationAction.request.URL.absoluteString ? navigationAction.request.URL.absoluteString : @"";

    if (![self iSTraggerOverrideUrlLoading:navigationAction url:url]) {
        return NO;
    }

    AceWebErrorReceiveInfoObject* obj = new AceWebErrorReceiveInfoObject(std::string([url UTF8String]), "", 0);
    if (AceWebObjectWithBoolReturn(
            [[self event_hashFormat:NTC_ONOVERRIDEURLLOADING] UTF8String], 
            [NTC_ONOVERRIDEURLLOADING UTF8String], 
            obj)) {
        return YES;
    }
    return NO;
}

- (BOOL)iSTraggerOverrideUrlLoading:(WKNavigationAction *)navigationAction url:(NSString *)url
{
    if ([[navigationAction.request.HTTPMethod uppercaseString] isEqualToString:@"POST"]) {
        return NO;
    }

    if ([url hasPrefix:@"javascript:"]) {
        return NO;
    }

    if (self.isLoadUrl) {
        self.isLoadUrl = NO;
        return NO;
    }
    BOOL isIFrame = (navigationAction.targetFrame != nil) && 
                !navigationAction.targetFrame.isMainFrame;
    BOOL isWebURL = [url hasPrefix:@"http://"] || [url hasPrefix:@"https://"];
    if (isIFrame) {
        if (isWebURL || [url hasPrefix:@"about:blank"]) {
            return NO;
        }
    } else  {
        if (navigationAction.navigationType != WKNavigationTypeLinkActivated) {
            return NO;
        }
    }
    return YES;
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
    if (@available(iOS 14.5, *)) {
        if (!navigationResponse.canShowMIMEType) {
            decisionHandler(WKNavigationResponsePolicyDownload);
            return;
        }
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

#pragma mark - UIScrollViewDelegate
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    AceWebOnScrollObject* obj = new AceWebOnScrollObject(scrollView.contentOffset.x, scrollView.contentOffset.y);
    AceWebObject([[self event_hashFormat:NTC_ONWILL_SCROLLSTART] UTF8String], [NTC_ONWILL_SCROLLSTART UTF8String], obj);
    self.dragStartPoint = scrollView.contentOffset;
    self.hasCalledOnScrollStart = NO;
}

- (void)scrollViewDidScroll:(UIScrollView*)scrollView
{
   float x = scrollView.contentOffset.x;
   float y = scrollView.contentOffset.y;
    if (!self.hasCalledOnScrollStart) {
        float velocityX = x - self.dragStartPoint.x;
        float velocityY = y - self.dragStartPoint.y;
        AceWebOnScrollObject* obj = new AceWebOnScrollObject(velocityX, velocityY);
        AceWebObject([[self event_hashFormat:NTC_ONSCROLLSTART] UTF8String], [NTC_ONSCROLLSTART UTF8String], obj);
        self.hasCalledOnScrollStart = YES;
        return;
    }
    float contentWidth = scrollView.contentSize.width;
    float contentHeight = scrollView.contentSize.height;
    float frameWidth = scrollView.bounds.size.width;
    float frameHeight = scrollView.bounds.size.height;
    AceWebOnScrollObject* obj = new AceWebOnScrollObject(x, y, contentWidth, contentHeight, frameWidth, frameHeight);
    AceWebObject([[self event_hashFormat:NTC_ONSCROLL] UTF8String], [NTC_ONSCROLL UTF8String], obj); 
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self scrollViewDidEndScrolling:scrollView];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [self scrollViewDidEndScrolling:scrollView];
    }
}

- (void)scrollViewDidEndScrolling:(UIScrollView *)scrollView {
    NSLog(@"AceWeb: scrollViewDidEndScrolling called");
    float x = scrollView.contentOffset.x;
    float y = scrollView.contentOffset.y;
    AceWebOnScrollObject* obj = new AceWebOnScrollObject(x, y);
    AceWebObject([[self event_hashFormat:NTC_ONSCROLLEND] UTF8String], [NTC_ONSCROLLEND UTF8String], obj);
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

- (NSString*)generateJavaScriptForResult:(id)result className:(NSString*)className methodName:(NSString*)methodName
{
    if ([result isKindOfClass:[NSNumber class]]) {
        if (strcmp([result objCType], @encode(char)) == 0) {
            return [NSString stringWithFormat:@"window.%@.%@.resolve(%@);", className, methodName,
                [result boolValue] ? @"true" : @"false"];
        } else if (strcmp([result objCType], @encode(int)) == 0) {
            return [NSString stringWithFormat:@"window.%@.%@.resolve(%d);", className, methodName, [result intValue]];
        } else if (strcmp([result objCType], @encode(double)) == 0) {
            return [NSString stringWithFormat:@"window.%@.%@.resolve(%f);", className, methodName, [result doubleValue]];
        }
    } else if ([result isKindOfClass:[NSArray class]] || [result isKindOfClass:[NSDictionary class]]) {
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
        NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return [NSString stringWithFormat:@"window.%@.%@.resolve(%@);", className, methodName, jsonString];
    } else {
        return [NSString stringWithFormat:@"window.%@.%@.resolve('%@');", className, methodName, result];
    }
}

- (void)userContentController:(WKUserContentController*)userContentController
      didReceiveScriptMessage:(WKScriptMessage*)message
{
    int messageLevel = 2;
    NSString* messageBody = message.body ? [NSString stringWithFormat:@"%@", message.body] : @"";
    if ([message.name hasPrefix:CONSOLEDEBUG]) {
        messageLevel = 1;
    } else if ([message.name hasPrefix:CONSOLEERROR]) {
        messageLevel = 4;
    } else if ([message.name hasPrefix:CONSOLEINFO] || [message.name hasPrefix:CONSOLELOG]) {
        messageLevel = 2;
    } else if ([message.name hasPrefix:CONSOLEWARN]) {
        messageLevel = 3;
    } else if ([message.name hasPrefix:@"onWebMessagePortMessage"]) {
        if (self.messageCallBack != nil) {
            self.messageCallBack(messageBody);
        }
        if (self.messageCallBackExt != nil) {
            self.messageCallBackExt(message.body);
        }
        return;
    } else if ([message.name isEqualToString:@"videoPlayed"]) {
        NSString *videoSrc = message.body;
        self.videoSrc = videoSrc;
        return;
    } else if ([message.name isEqualToString:@"AceWebHandler"] && self.onJavaScriptFunctionCallBack) {
        NSDictionary* messageBody = (NSDictionary *)message.body;
        NSString* className = messageBody[@"class"];
        NSString* methodName = messageBody[@"method"];
        NSArray* params = [NSArray array];
        if ([messageBody[@"params"] isKindOfClass:NSArray.class]) {
            params = [NSArray arrayWithArray:messageBody[@"params"]];
        } else {
            NSString* jsonString = [NSString stringWithFormat:@"%@", messageBody[@"params"]];
            NSData* jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
            NSError* error;
            NSArray* array = [NSJSONSerialization JSONObjectWithData:jsonData
                                options:NSJSONReadingMutableContainers error:&error];
            if (!array) {
                NSLog(@"Failed to parse JSON:: %@", error);
            } else {
                params = array;
            }
        }
        id result = self.onJavaScriptFunctionCallBack(className, methodName, params);
        if (result != nil && ![result isEqual:@""]) {
            NSString* js = [self generateJavaScriptForResult:result className:className methodName:methodName];
            [self.webView evaluateJavaScript:js completionHandler:nil];
        }
        return;
    }
    AceWebOnConsoleObject* obj = new AceWebOnConsoleObject(std::string([messageBody UTF8String]), messageLevel);
    AceWebObjectWithBoolReturn(
        [[self event_hashFormat:NTC_ONCONSOLEMESSAGE] UTF8String], [NTC_ONCONSOLEMESSAGE UTF8String], obj);
}

- (void)webView:(WKWebView*)webView
    runJavaScriptAlertPanelWithMessage:(NSString*)message
                      initiatedByFrame:(WKFrameInfo*)frame
                     completionHandler:(void (^)(void))completionHandler
{
    NSString* url = [self getUrl];
    DialogResultMethod dialogResult_callback = ^void(int action, std::string promptResult) {
      @try {
          if (action == static_cast<int>(AceWebHandleResult::CONFIRM)) {
              completionHandler();
              return;
          } else if (action == static_cast<int>(AceWebHandleResult::CANCEL)) {
              completionHandler();
              return;
          }
          completionHandler();
      } @catch (NSException* exception) {
          NSLog(@"Error: alert dialog completionHandler call failed");
      }
    };
    AceWebDialogObject* obj =
        new AceWebDialogObject(std::string([url UTF8String]), std::string([message UTF8String]), "");
    obj->SetDialogResultCallback(dialogResult_callback);
    if (!AceWebObjectWithBoolReturn([[self event_hashFormat:@"onAlert"] UTF8String], [@"onAlert" UTF8String], obj)) {
        @try {
            completionHandler();
        } @catch (NSException* exception) {
            NSLog(@"Error: alert dialog completionHandler call failed");
        }
    }
}

- (void)webView:(WKWebView*)webView
    runJavaScriptConfirmPanelWithMessage:(NSString*)message
                        initiatedByFrame:(WKFrameInfo*)frame
                       completionHandler:(void (^)(BOOL result))completionHandler
{
    NSString* url = [self getUrl];
    DialogResultMethod dialogResult_callback = ^void(int action, std::string promptResult) {
      @try {
          if (action == static_cast<int>(AceWebHandleResult::CONFIRM)) {
              completionHandler(true);
              return;
          } else if (action == static_cast<int>(AceWebHandleResult::CANCEL)) {
              completionHandler(false);
              return;
          }
          completionHandler(false);
      } @catch (NSException* exception) {
          NSLog(@"Error: confirm dialog completionHandler call failed");
      }
    };
    AceWebDialogObject* obj =
        new AceWebDialogObject(std::string([url UTF8String]), std::string([message UTF8String]), "");
    obj->SetDialogResultCallback(dialogResult_callback);
    if (!AceWebObjectWithBoolReturn(
            [[self event_hashFormat:@"onConfirm"] UTF8String], [@"onConfirm" UTF8String], obj)) {
        @try {
            completionHandler(false);
        } @catch (NSException* exception) {
            NSLog(@"Error: confirm dialog completionHandler call failed");
        }
    }
}

- (void)webView:(WKWebView*)webView
    runJavaScriptTextInputPanelWithPrompt:(NSString*)prompt
                              defaultText:(NSString*)defaultText
                         initiatedByFrame:(WKFrameInfo*)frame
                        completionHandler:(void (^)(NSString* result))completionHandler
{
    NSString* url = [self getUrl];
    DialogResultMethod dialogResult_callback = ^void(int action, std::string promptResult) {
      @try {
          NSString* nsResult =
              [NSString stringWithCString:promptResult.c_str() encoding:[NSString defaultCStringEncoding]];
          if (action == static_cast<int>(AceWebHandleResult::PROMPTCONFIRM)) {
              completionHandler(nsResult);
              return;
          } else if (action == static_cast<int>(AceWebHandleResult::CANCEL)) {
              completionHandler(nil);
              return;
          }
          completionHandler(nil);
      } @catch (NSException* exception) {
          NSLog(@"Error: prompt dialog completionHandler call failed");
      }
    };
    AceWebDialogObject* obj = new AceWebDialogObject(
        std::string([url UTF8String]), std::string([prompt UTF8String]), std::string([defaultText UTF8String]));
    obj->SetDialogResultCallback(dialogResult_callback);
    if (!AceWebObjectWithBoolReturn([[self event_hashFormat:@"onPrompt"] UTF8String], [@"onPrompt" UTF8String], obj)) {
        @try {
            completionHandler(nil);
        } @catch (NSException* exception) {
            NSLog(@"Error: prompt dialog completionHandler call failed");
        }
    }
}

- (void)webView:(WKWebView*)webView
    requestMediaCapturePermissionForOrigin:(WKSecurityOrigin*)origin
                          initiatedByFrame:(WKFrameInfo*)frame
                                      type:(WKMediaCaptureType)type
                           decisionHandler:(void (^)(WKPermissionDecision decision))decisionHandler
    API_AVAILABLE(ios(15.0))
{
    NSString* host = origin.host ? origin.host : @"";
    int permissionType = 0;
    switch (type) {
        case WKMediaCaptureTypeCamera:
            permissionType = 1;
            break;
        case WKMediaCaptureTypeMicrophone:
            permissionType = 2;
            break;
        case WKMediaCaptureTypeCameraAndMicrophone:
            permissionType = 3;
            break;
        default:
            break;
    }
    PermissionRequestMethod permissionRequest_callback = ^void(int action, int ResourcesId) {
      @try {
          if (action == static_cast<int>(AceWebHandleResult::DENY)) {
              decisionHandler(WKPermissionDecisionDeny);
              return;
          } else if (ResourcesId > 0 && action == static_cast<int>(AceWebHandleResult::GRANT)) {
              decisionHandler(WKPermissionDecisionGrant);
              return;
          }
          decisionHandler(WKPermissionDecisionPrompt);
      } @catch (NSException* exception) {
          NSLog(@"Error: request permission completionHandler call failed");
      }
    };
    AceWebPermissionRequestObject* obj =
        new AceWebPermissionRequestObject(std::string([host UTF8String]), permissionType);
    obj->SetPermissionResultCallback(permissionRequest_callback);
    if (!AceWebObjectWithBoolReturn(
            [[self event_hashFormat:@"onPermissionRequest"] UTF8String], [@"onPermissionRequest" UTF8String], obj)) {
        @try {
            decisionHandler(WKPermissionDecisionPrompt);
        } @catch (NSException* exception) {
            NSLog(@"Error: request permission completionHandler call failed");
        }
    }
}

- (void)webView:(WKWebView*)webView
    didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge*)challenge
                    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition,
                                          NSURLCredential* credential))completionHandler
{
    if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust) {
        [self handleAuthenticationMethodServerTrustWithUrl:
            [NSString stringWithFormat:@"%@://%@/", challenge.protectionSpace.protocol, challenge.protectionSpace.host]
            challenge:challenge completionHandler:completionHandler];
        return;
    }
    NSString* host = challenge.protectionSpace.host ? challenge.protectionSpace.host : @"";
    NSString* realm = challenge.protectionSpace.realm ? challenge.protectionSpace.realm : @"";

    HttpAuthRequestMethod authRequest_callback = ^bool(int action, std::string name, std::string pwd) {
      NSString* nsName = [NSString stringWithCString:name.c_str() encoding:[NSString defaultCStringEncoding]];
      NSString* nsPwd = [NSString stringWithCString:pwd.c_str() encoding:[NSString defaultCStringEncoding]];
      @try {
          if (action == static_cast<int>(AceWebHandleResult::CONFIRM)) {
              NSURLCredential* credential = [NSURLCredential credentialWithUser:nsName
                                                                       password:nsPwd
                                                                    persistence:NSURLCredentialPersistencePermanent];
              completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
              return true;
          } else if (action == static_cast<int>(AceWebHandleResult::CANCEL)) {
              completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
              return false;
          } else if (action == static_cast<int>(AceWebHandleResult::HTTPAUTHINFOSAVED)) {
              NSURLCredential* credential = [AceWeb getHttpAuthCredentials:host realm:realm];
              if (credential == nil) {
                  return false;
              }
              completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
              return true;
          }
          completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
          return false;
      } @catch (NSException* exception) {
          NSLog(@"Error: Http auth request completionHandler call failed");
          return false;
      }
    };
    AceWebOnHttpAuthRequestObject* obj =
        new AceWebOnHttpAuthRequestObject(std::string([host UTF8String]), std::string([realm UTF8String]));
    obj->SetAuthResultCallback(authRequest_callback);
    if (!AceWebObjectWithBoolReturn(
            [[self event_hashFormat:@"onHttpAuthRequest"] UTF8String], [@"onHttpAuthRequest" UTF8String], obj)) {
        @try {
            completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        } @catch (NSException* exception) {
            NSLog(@"Error: Http auth request completionHandler call failed");
        }
    }
}

- (void)handleAuthenticationMethodServerTrustWithUrl:(NSString *)url challenge:(NSURLAuthenticationChallenge*)challenge
    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition,
                          NSURLCredential* credential))completionHandler 
{
    NSString *challengeKey = [NSString stringWithFormat:@"%@:%@:%ld", 
        challenge.protectionSpace.protocol, challenge.protectionSpace.host, (long)challenge.protectionSpace.port];
    if ([self.handleSslErrorUrls containsObject:challengeKey] ||
        [[AceWebInfoManager sharedManager].authChallengeUseCredentials containsObject:challengeKey]) {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        return;
    }
    [self.handleSslErrorUrls addObject:challengeKey];
    SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
    SecTrustResultType result;
    OSStatus status = errSecSuccess;
    int errorCode = 0;
    if (@available(iOS 12.0, *)) {
        BOOL isTrusted = NO;
        CFErrorRef errorRef = NULL;
        isTrusted = SecTrustEvaluateWithError(serverTrust, &errorRef);
        result = isTrusted ? kSecTrustResultProceed : kSecTrustResultRecoverableTrustFailure;
        if (errorRef) {
            NSError *error = (__bridge NSError *)errorRef;
            errorCode = [self handleSslErrorEventErrorCode:(int)error.code];
            CFRelease(errorRef);
        }
    } else {
        status = SecTrustEvaluate(serverTrust, &result);
    }
    if (status == errSecSuccess && (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified)) {
        NSURLCredential *credential = [NSURLCredential credentialForTrust:serverTrust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    } else {
        __block BOOL completionHandlerCalled = NO;
        void (^safeCompletionHandler)(NSURLSessionAuthChallengeDisposition, NSURLCredential *) =
            ^(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential) {
                if (!completionHandlerCalled) {
                    completionHandlerCalled = YES;
                    completionHandler(disposition, credential);
                    if (disposition == NSURLSessionAuthChallengeUseCredential) {
                        [[AceWebInfoManager sharedManager].authChallengeUseCredentials addObject:challengeKey];
                    }
                }
            };
        NSString *host = challenge.protectionSpace.host;
        BOOL isMainFrame = [self.mainFrameUrl containsString:host];
        [self handleSslErrorEventWithUrl:url isMainFrame:isMainFrame
            serverTrust:serverTrust errorCode:errorCode completionHandler:safeCompletionHandler];
    }
}

- (int)handleSslErrorEventErrorCode:(NSInteger)errorCode {
    SslError error = SslError::INVALID;
    switch (errorCode) {
    case errSecHostNameMismatch:
        error = SslError::HOST_MISMATCH;
        break;
    case errSecCreateChainFailed:
    case errSecCertificateExpired:
    case errSecCertificateNotValidYet:
        error = SslError::DATE_INVALID;
        break;
    case errSecNotTrusted:
    case errSecVerifyActionFailed:
        error = SslError::UNTRUSTED;
        break;
    }
    return static_cast<int32_t>(error);
}

- (void)handleSslErrorEventWithUrl:(NSString *)url isMainFrame:(BOOL)isMainFrame 
    serverTrust:(SecTrustRef)serverTrust errorCode:(int)errorCode
    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition,
                          NSURLCredential* credential))completionHandler
{
    SslEventMethod sslErrorEventConfirm_callback = ^void(int action) {
        @try {
            NSURLCredential *credential = [NSURLCredential credentialForTrust:serverTrust];
            completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
        } @catch (NSException* exception) {
            completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
            NSLog(@"AceWeb error: alert dialog confirm call failed");
        }
    };
    SslErrorEventCancelMethod sslErrorEventCancel_callBack = ^void(bool abortLoading) {
        @try {
            completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, nil);
        } @catch (NSException* exception) {
            completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
            NSLog(@"AceWeb error: alert dialog cancel call failed");
        }
    };
    NSArray *certificateChain = [self getCertificateChainFromTrust:serverTrust];
    std::vector<std::string> certChainData = convertCertificateChainToDer(certificateChain);
    AceWebSslErrorEventObject* obj = new AceWebSslErrorEventObject(errorCode, std::string([[self getUrl] UTF8String]),
        std::string([url UTF8String]), std::string([self.referrer UTF8String]), 
        false, isMainFrame, certChainData);
    obj->SetSslErrorEventConfirmCallBack(sslErrorEventConfirm_callback);
    obj->SetSslErrorEventCancelCallBack(sslErrorEventCancel_callBack);
    BOOL onSslErrorEventFail = NO;
    if (!AceWebObjectWithBoolReturn(
        [[self event_hashFormat:NTC_ONSSLERROREVENT] UTF8String], [NTC_ONSSLERROREVENT UTF8String], obj)) {
        onSslErrorEventFail = YES;
    }
    if (self.isMainFrame && isMainFrame) {
        [self handleSslErrorEventReceiveWithServerTrust:serverTrust errorCode:errorCode
            certChainData:certChainData onSslErrorEventFail:onSslErrorEventFail completionHandler:completionHandler];
    } else {
        if (onSslErrorEventFail) {
            @try {
                completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
            } @catch (NSException* exception) {
                NSLog(@"AceWeb error: ssl error event completionHandler call failed");
            }
        }
    }
}

- (void)handleSslErrorEventReceiveWithServerTrust:(SecTrustRef)serverTrust errorCode:(int)errorCode
    certChainData:(std::vector<std::string>&)certChainData onSslErrorEventFail:(BOOL)onSslErrorEventFail
    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition,
                          NSURLCredential* credential))completionHandler {
    SslEventMethod sslErrorEventReceiveEventCancel_callback = ^void(int action) {
        @try {
            if (action == static_cast<int>(AceWebHandleResult::CONFIRM)) {
                NSURLCredential *credential = [NSURLCredential credentialForTrust:serverTrust];
                completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
            } else {
                completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, nil);
            }
        } @catch (NSException* exception) {
            completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
            NSLog(@"AceWeb error: alert dialog completionHandler call failed");
        }
    };
    AceWebOnSslErrorEventReceiveEventObject *obj = new AceWebOnSslErrorEventReceiveEventObject(errorCode, certChainData);
    obj->SetWebOnSslErrorEventReceiveCallBack(sslErrorEventReceiveEventCancel_callback);
    BOOL onSslErrorEventReceiveFail = NO;
    if (!AceWebObjectWithBoolReturn(
        [[self event_hashFormat:NTC_ONSSLERROREVENTRECEIVE] UTF8String], [NTC_ONSSLERROREVENTRECEIVE UTF8String], obj)) {
        onSslErrorEventReceiveFail = YES;
    }
    if (onSslErrorEventFail && onSslErrorEventReceiveFail) {
        @try {
            completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        } @catch (NSException* exception) {
            NSLog(@"AceWeb error: ssl error event completionHandler call failed");
        }
    }
}

- (NSArray *)getCertificateChainFromTrust:(SecTrustRef)trust {
    CFIndex certificateCount = SecTrustGetCertificateCount(trust);
    NSMutableArray *certificateChain = [NSMutableArray arrayWithCapacity:certificateCount];
    for (CFIndex i = 0; i < certificateCount; i++) {
        SecCertificateRef certificate = SecTrustGetCertificateAtIndex(trust, i);
        [certificateChain addObject:(__bridge id)certificate];
    }
    return [certificateChain copy];
}

std::string certificateToDerString(SecCertificateRef cert) {
    CFDataRef derData = SecCertificateCopyData(cert);
    if (!derData) {
        NSLog(@"AceWeb error: SecCertificateCopyData failed");
        return "";
    }
    const UInt8 *bytes = CFDataGetBytePtr(derData);
    CFIndex length = CFDataGetLength(derData);
    std::string der(reinterpret_cast<const char*>(bytes), length);
    CFRelease(derData);
    return der;
}

std::vector<std::string> convertCertificateChainToDer(NSArray *certificateChain) {
    std::vector<std::string> result;
    for (id certObj in certificateChain) {
        SecCertificateRef cert = (__bridge SecCertificateRef)certObj;
        result.push_back(certificateToDerString(cert));
    }
    return result;
}

- (void)webView:(WKWebView*)webView
    navigationResponse:(WKNavigationResponse*)navigationResponse
     didBecomeDownload:(WKDownload*)download
    API_AVAILABLE(ios(14.5))
{
    NSHTTPURLResponse* response = (NSHTTPURLResponse*)navigationResponse.response;
    NSString* downloadURL = response.URL.absoluteString ? response.URL.absoluteString : @"";
    NSString* mimeType = response.MIMEType ? response.MIMEType : @"";
    long contentLength = response.expectedContentLength ? response.expectedContentLength : 0;
    [webView evaluateJavaScript:@"navigator.userAgent" completionHandler:^(id result, NSError *error) {
        NSString *userAgent = result ? result : @"";
        AceWebDownloadResponseObject* obj = new AceWebDownloadResponseObject(std::string([downloadURL UTF8String]), 
            std::string([mimeType UTF8String]), contentLength, std::string([userAgent UTF8String]));
        AceWebObject([[self event_hashFormat:@"onDownloadStart"] UTF8String], [@"onDownloadStart" UTF8String], obj);
    }];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:( WKNavigation *)navigation withError:(NSError *)error
{
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

- (void)cookiesDidChangeInCookieStore:(WKHTTPCookieStore *)cookieStore
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (@available(iOS 11.0, *)) {
        [cookieStore getAllCookies:^(NSArray* cookies) {
            for (NSHTTPCookie *cookie in cookies) {
                [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
            }
        }];
    }
#endif
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask 
                                           didWriteData:(int64_t)bytesWritten 
                                      totalBytesWritten:(int64_t)totalBytesWritten 
                              totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    @synchronized (self) {
        NSString* guid = [NSString stringWithFormat:@"%lld_%lu", self.incId, downloadTask.taskIdentifier];
        DownloadTaskInfo* downloadTaskInfo = [self.downloadTasksDic objectForKey:guid];
        if (!downloadTaskInfo || !self.onDownloadUpdatedCallBack) {
            return;
        }
        static NSDate* lastUpdateTime;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            lastUpdateTime = [NSDate dateWithTimeIntervalSince1970:0];
        });
        
        NSString* earliestGuid = guid;
        NSDate* earliestDate = [NSDate date];
        for (NSString* key in self.downloadTasksDic) {
            DownloadTaskInfo* info = [self.downloadTasksDic objectForKey:key];
            if ([info.lastUpdateTime compare:earliestDate] == NSOrderedAscending && info.isDownload) {
                earliestDate = info.lastUpdateTime;
                earliestGuid = key;
            }
        }
        NSDate* now = [NSDate date];
        if ([now timeIntervalSinceDate:lastUpdateTime] > 1 && [guid isEqualToString:earliestGuid]) {
            NSString* suggestedFilename = downloadTask.response.suggestedFilename;
            downloadTaskInfo.lastUpdateTime = now;
            lastUpdateTime = now;
            dispatch_async(dispatch_get_main_queue(), ^{
                self.onDownloadUpdatedCallBack(guid, @"IN_PROGRESS", totalBytesExpectedToWrite, totalBytesWritten, suggestedFilename);
            });
        }
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask 
    didFinishDownloadingToURL:(NSURL *)location {
    NSString* guid = [NSString stringWithFormat:@"%lld_%lu", self.incId, downloadTask.taskIdentifier];
    NSString* suggestedFilename = downloadTask.response.suggestedFilename;
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString* path = documentsPath;
    DownloadTaskInfo* downloadTaskInfo = [self.downloadTasksDic objectForKey:guid];
    if (downloadTaskInfo) {
        path = [documentsPath stringByAppendingPathComponent:downloadTaskInfo.filePath];
    }
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString* destinationPath = [path stringByAppendingPathComponent:suggestedFilename];
    if ([fileManager fileExistsAtPath:destinationPath]) {
        [fileManager removeItemAtPath:destinationPath error:nil];
    }
    NSURL* destinationURL = [NSURL fileURLWithPath:destinationPath];
    NSError* fileError = nil;
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:destinationURL error:&fileError];
    for (NSString* key in self.downloadTasksDic) {
        DownloadTaskInfo* info = [self.downloadTasksDic objectForKey:key];
        info.lastUpdateTime = [NSDate date];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.onDownloadFinishCallBack(guid, path);
    });
    [self.downloadTasksDic removeObjectForKey:guid];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task 
    didCompleteWithError:(nullable NSError *)error {
    if (error) {
        for (NSString* key in self.downloadTasksDic) {
            DownloadTaskInfo* info = [self.downloadTasksDic objectForKey:key];
            info.lastUpdateTime = [NSDate date];
        }
        NSString* guid = [NSString stringWithFormat:@"%lld_%lu", self.incId, task.taskIdentifier];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.onDownloadFailedCallBack(guid, @"INTERRUPTED", error.code);
        });
        [self.downloadTasksDic removeObjectForKey:guid];
    }
}

- (void)setNestedScrollOptionsExt:(void *)options {
    OHOS::Ace::NestedScrollOptionsExt* cppOptions = reinterpret_cast<OHOS::Ace::NestedScrollOptionsExt*>(options);
    self.nestedOpt = [[NestedScrollOptionsExt alloc] init];
    self.nestedOpt.scrollUp = static_cast<NestedScrollMode>(cppOptions->scrollUp);
    self.nestedOpt.scrollDown = static_cast<NestedScrollMode>(cppOptions->scrollDown);
    self.nestedOpt.scrollLeft = static_cast<NestedScrollMode>(cppOptions->scrollLeft);
    self.nestedOpt.scrollRight = static_cast<NestedScrollMode>(cppOptions->scrollRight);
    self.webView.scrollView.directionalLockEnabled = NO;
    self.webScrollEnabled = YES;
}

- (void)setWebScrollEnabled:(BOOL)webScrollEnabled {
    if (_webScrollEnabled != webScrollEnabled) {
        _webScrollEnabled = webScrollEnabled;
    }
    if (_webScrollEnabled != self.webView.scrollView.scrollEnabled) {
        self.webView.scrollView.scrollEnabled = _webScrollEnabled;
    }
}
@end
