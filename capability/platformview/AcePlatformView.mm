/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

#include <objc/NSObjCRuntime.h>
#include <sys/_types/_int32_t.h>
#include "StageViewController.h"
#include <vector>

#import "AcePlatformView.h"
#import "AceTextureHolder.h"
#import <AVFoundation/AVFoundation.h>
#import "render/RenderView.h"
#import "StageApplication.h"
#import "WindowView.h"

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <CoreImage/CoreImage.h>

#define PLATFORMVIEW_FLAG      @"platformview@"
#define PARAM_AND       @"#HWJS-&-#"
#define PARAM_EQUALS    @"#HWJS-=-#"
#define PARAM_BEGIN     @"#HWJS-?-#"
#define METHOD          @"method"
#define EVENT           @"event"

#define SUCCESS         @"success"
#define FAIL            @"fail"
#define KEY_TEXTUREID   @"textureId"

#define PLATFORMVIEW_WIDTH     @"platformViewWidth"
#define PLATFORMVIEW_HEIGHT    @"platformViewHeight"
#define PLATFORMVIEW_TOP       @"platformViewTop"
#define PLATFORMVIEW_LEFT      @"platformViewLeft"
const static size_t QueueSize = 3;
@interface AcePlatformView()
@property (nonatomic, assign) int32_t instanceId;
@property (nonatomic, strong) NSObject<AcePlatformViewDelegate>* delegate;

@property (nonatomic, strong) NSMutableDictionary<NSString *, IAceOnCallSyncResourceMethod> *callSyncMethodMap;
@property (nonatomic, strong) NSObject<IPlatformView>* curPlatformView;

@property (nonatomic, strong) CADisplayLink *displayLink;

@property(nonatomic, assign) int64_t id;
@property(nonatomic, assign) int64_t textureResourceId;
@property(nonatomic, copy) IAceOnResourceEvent onEvent;
@property (nonatomic, strong) AceTexture *renderTexture;
@property (nonatomic, copy) IAceTextureAttachEventCallback attachCallbackHandler;

@property(nonatomic, assign) CGFloat frameWidth;
@property(nonatomic, assign) CGFloat frameHeight;
@property(nonatomic, assign) CGFloat frameTop;
@property(nonatomic, assign) CGFloat frameLeft;
@property(nonatomic, assign) CGFloat screenScale;

@end

@implementation AcePlatformView
{
    RenderView *_renderView;
    AVPlayer *_player;
    AVPlayerLayer *_playerLayer;
    void *_eglContextPtr;
    bool _initView;
    bool _isVideo;
    bool _isRenderFinish;
}

- (instancetype)initWithEvents:(IAceOnResourceEvent)callback
    id:(int64_t)id abilityInstanceId:(int32_t)abilityInstanceId
    viewdelegate:(NSObject<AcePlatformViewDelegate>*)viewdelegate
{
    if (self = [super init]) {
        self.instanceId = abilityInstanceId;
        self.onEvent = callback;
        self.id = id;
        self.delegate = viewdelegate;
        self.displayLink = nil;
        self.renderTexture = nil;
        self.screenScale = [UIScreen mainScreen].scale;
        self.frameWidth = 0.00f;
        self.frameHeight = 0.00f;
        self.frameTop = 0.00f;
        self.frameLeft = 0.00f;
        _initView = false;
        _isVideo = false;
        _renderView  = [[RenderView alloc] initWithFrame:CGRectZero];
        self.callSyncMethodMap = [[NSMutableDictionary alloc] init];
        [self initEventCallback];
    }
    return self;
}

- (void)initEventCallback
{
    __weak __typeof(self)weakSelf = self;
    // registerPlatformView callback
    IAceOnCallSyncResourceMethod register_callback = ^NSString *(NSDictionary * param){
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf registerPlatformView:param];
            return SUCCESS;
        } else {
            NSLog(@"AcePlatformView: registerPlatformView fail");
            return FAIL;
        }
    };
    NSString *register__method_hash = [self method_hashFormat:@"registerPlatformView"];
    [self.callSyncMethodMap setObject:[register_callback copy] forKey:register__method_hash];

    // updatelayout callback 
    NSString *updatelayout_method_hash = [self method_hashFormat:@"updateLayout"];
    IAceOnCallSyncResourceMethod updatelayout_callback = ^NSString *(NSDictionary * param){
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf) {
            return [strongSelf updatelayout:param];
        } else {
            NSLog(@"AcePlatformView: updatelayout fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[updatelayout_callback copy] forKey:updatelayout_method_hash];

    // exchangeBind callback
    NSString *exchange_bind_method_hash = [self method_hashFormat:@"exchangeBind"];
    IAceOnCallSyncResourceMethod exchange_bind_callback = ^NSString *(NSDictionary * param){
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf) {
            return [strongSelf exchangeBind:param];
        } else {
            NSLog(@"AcePlatformView: exchangeBind fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[exchange_bind_callback copy] forKey:exchange_bind_method_hash];

    // platformViewType callback
    NSString *platform_view_type_hash = [self method_hashFormat:@"platformViewType"];
    IAceOnCallSyncResourceMethod platform_view_type_callback = ^NSString *(NSDictionary * param){
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf) {
            return [strongSelf platformViewType:param];
        } else {
            NSLog(@"AcePlatformView: platformViewType fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[platform_view_type_callback copy] forKey:platform_view_type_hash];
}

- (void)setPlatformView:(NSObject<IPlatformView>*)platformView
{
    self.curPlatformView = platformView;
    NSObject<IPlatformView>* embeddedView = self.curPlatformView;
    if (!embeddedView) {
        NSLog(@"AcePlatformView: setPlatformView failed: platformView is null");
        return ;
    }
    UIView* pv = [embeddedView view];
    [pv.layer.sublayers enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[AVPlayerLayer class]]) {
            AVPlayerLayer *pLayer = ((AVPlayerLayer *)obj);
            _isVideo = true;
            _playerLayer = pLayer;
            _player = pLayer.player;
        } else {
            *stop = YES;
        }
    }];
}

- (NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *)getSyncCallMethod
{
    return self.callSyncMethodMap;
}

- (NSString *)exchangeBind:(NSDictionary *)params
{
    if (_renderView != nullptr) {
        [_renderView exchangeBind];
    }
    return SUCCESS;
}

- (NSString *)platformViewType:(NSDictionary *)params
{
    NSDictionary * param = @{@"type": [NSString stringWithFormat:@"%d", _isVideo]};
    return [self convertMapToString:param];
}

- (NSString *)convertMapToString:(NSDictionary *)data
{
    NSArray *pairs = [data.allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSMutableString *string = [[NSMutableString alloc] init];
    for (NSString *key in pairs) {
        id value = data[key];
        [string appendFormat:@"%@=%@;", key, value];
    }
    [string deleteCharactersInRange:NSMakeRange(string.length - 1, 1)];
    return string;
}

- (NSString *)registerPlatformView:(NSDictionary *)params
{
    if (!params) {
        NSLog(@"AcePlatformView: registerPlatformView failed: params is null");
        return FAIL;
    }
    [self initPlatformView];
    self.textureResourceId = [params[KEY_TEXTUREID] longLongValue];
    if (!_isVideo) {
        [self.delegate registerContextPtrWithInstanceId:self.instanceId textureId: self.textureResourceId
            contextPtr: (void*)&_eglContextPtr];
    }
    NSObject<IPlatformView>* embeddedView = self.curPlatformView;
    if (!embeddedView) {
        NSLog(@"AcePlatformView: registerPlatformView failed: platformView is null");
        return FAIL;
    }

    UIView* platformView = [embeddedView view];
    if (!self.renderTexture) {
        AceTexture *newTexture = (AceTexture*)[AceTextureHolder getTextureWithId:self.textureResourceId
            inceId:self.instanceId];
        self.renderTexture = newTexture;
    }

    if (_isVideo && _player) {
        [_player.currentItem addOutput:self.renderTexture.videoOutput];
        [self initWithEmbeddedView:platformView];
        [self initRenderTexture];
    } else {
        __weak __typeof(&*self) weakSelf = self;
        self.attachCallbackHandler = ^(int32_t textureName){
            if (weakSelf) {
                [weakSelf textureAttach];
            }
        };
        [self.renderTexture addAttachEventCallback:self.attachCallbackHandler];
        [self initRenderTexture];
    }

    return SUCCESS;
}

- (void)textureAttach
{
    dispatch_main_async_safe(^{
        NSObject<IPlatformView>* embeddedView = self.curPlatformView;
        if (!embeddedView) {
            NSLog(@"AcePlatformView: registerPlatformView failed: platformView is null");
            return;
        }
        UIView* platformView = [embeddedView view];
        [self initWithEmbeddedView:platformView];
        [self platformViewReady];
        _initView = true;
    });
}

- (void)platformViewReady
{
    if (self.onEvent) {
        NSString *prepared_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@",
                PLATFORMVIEW_FLAG, self.id, EVENT, PARAM_EQUALS, @"platformViewReady", PARAM_BEGIN];
        NSLog(@"[PlatformView] platformViewReady");
        self.onEvent(prepared_method_hash, @"");
    }
}

- (NSString *)updatelayout:(NSDictionary *)params
{
    if (!params) {
        NSLog(@"AcePlatformView: setSurface failed: params is null");
        return FAIL;
    }

    @try {
        NSObject<IPlatformView>* embeddedView = self.curPlatformView;
        if (!embeddedView) {
            NSLog(@"AcePlatformView: register failed: platformView is null");
            return FAIL;
        }
        UIView* platformView = [embeddedView view];

        CGFloat width = [params[PLATFORMVIEW_WIDTH] floatValue];
        CGFloat height = [params[PLATFORMVIEW_HEIGHT] floatValue];
        CGFloat top = [params[PLATFORMVIEW_TOP] floatValue];
        CGFloat left = [params[PLATFORMVIEW_LEFT] floatValue];
        if (self.frameWidth != width || self.frameHeight != height || self.frameTop != top || self.frameLeft != left) {
            self.frameWidth = width;
            self.frameHeight = height;
            self.frameTop = top;
            self.frameLeft = left;
        }

        CGRect tempFrame = platformView.frame;

        tempFrame.origin.x = self.frameLeft / self.screenScale;
        tempFrame.origin.y = self.frameTop / self.screenScale;
        tempFrame.size.height = self.frameHeight / self.screenScale;
        tempFrame.size.width = self.frameWidth / self.screenScale;
        if (!_isVideo && _renderView) {
            _renderView.frame = tempFrame;
            platformView.frame = _renderView.bounds;
        } else {
            platformView.frame = tempFrame;
        }
    } @catch (NSException *exception) {
        NSLog(@"AcePlatformView: IOException, updatelayout failed");
        return FAIL;
    }
    return SUCCESS;
}

- (BOOL)initPlatformView
{
    if (self.displayLink) {
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        return YES;
    }
    return NO;
}

- (CADisplayLink *)displayLink
{
    if (!_displayLink) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkDidrefresh)];
        auto mainMaxFrameRate = [UIScreen mainScreen].maximumFramesPerSecond;
        double maxFrameRate = fmin(mainMaxFrameRate, 60);
        double minFrameRate = fmin(mainMaxFrameRate / 2, maxFrameRate);
        if(@available(iOS 15.0,*)){
            _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(minFrameRate, maxFrameRate, maxFrameRate);
        } else{
            _displayLink.preferredFramesPerSecond = 60;
        }
    }
    return _displayLink;
}

- (void)displayLinkDidrefresh
{
    if (_isVideo) {
        if (self.displayLink) {
            [self refreshPixelBuffer];
        }
        return;
    }

    NSObject<IPlatformView>* embeddedView = self.curPlatformView;
    if (!embeddedView) {
        NSLog(@"AcePlatformView: register failed: platformView is null");
        return;
    }
    UIView* platformView = [embeddedView view];
    _isRenderFinish = false;
    if (_initView && _renderView != nullptr) {
        _isRenderFinish = [_renderView startRender:platformView];
        if (self.displayLink && _isRenderFinish) {
            [self refreshPixelBuffer];
        }
    }
}

- (void)initRenderTexture
{
    if (self.renderTexture) {
        [self.renderTexture refreshPixelBuffer];
    }
}

- (void)refreshPixelBuffer
{
    if (self.renderTexture) {
        [self.renderTexture refreshPixelBuffer];
    }
}

- (NSString *)method_hashFormat:(NSString *)method
{
    return [NSString stringWithFormat:@"%@%lld%@%@%@%@", PLATFORMVIEW_FLAG, self.id, METHOD, PARAM_EQUALS, method, PARAM_BEGIN];
}

-(UIView*)getPlatformView {
    NSObject<IPlatformView>* embeddedView = self.curPlatformView;
    if (!embeddedView) {
        return nil;
    }

    UIView* platformView = [embeddedView view];
    return platformView;
}

- (void)releaseObject
{
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }

    self.onEvent = nil;

    if (self.callSyncMethodMap) {
        for (id key in self.callSyncMethodMap) {
            IAceOnCallSyncResourceMethod block = [self.callSyncMethodMap objectForKey:key];
            block = nil;
        }
        [self.callSyncMethodMap removeAllObjects];
        self.callSyncMethodMap = nil;
    }

    self.attachCallbackHandler = nil;
    NSObject<IPlatformView>* embeddedView = self.curPlatformView;
    if (!embeddedView) {
        NSLog(@"AcePlatformView: releaseObject failed: platformView is null");
        return;
    }

    [[embeddedView view] removeFromSuperview];
    [embeddedView onDispose];

    [_renderView removeFromSuperview];
    _renderView = nil;

    if (self.renderTexture) {
        self.renderTexture = nil;
    }

    if (_player != nil) {
        _player = nil;
    }

    if (_playerLayer != nil) {
        _playerLayer = nil;
    }
}

- (void)dealloc
{
}

- (void)onActivityResume
{
    if (self.displayLink) {
        self.displayLink.paused = NO;
        NSLog(@"AcePlatformView displayLink resume.");
    }
}

- (void)onActivityPause
{
    if (self.displayLink) {
        self.displayLink.paused = YES;
        NSLog(@"AcePlatformView displayLink paused.");
    }
}

- (UIView *)findWindowViewInView:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[WindowView class]]) {
            return subview;
        } 
    }
    return nil;
}

- (void)initWithEmbeddedView:(UIView*)embeddedView {
    if (_isVideo) {
        StageViewController* controller = [StageApplication getApplicationTopViewController];
        embeddedView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
        if (![controller isKindOfClass:[StageViewController class]]) {
            return;
        }
        UIView *windowView = [controller getWindowView];
        [windowView.superview insertSubview:embeddedView belowSubview:windowView];
        return;
    }
    if (_renderView) {
        [_renderView setEAGLContext: (__bridge EAGLContext*)_eglContextPtr];
        [_renderView init];
        [_renderView addSubview: embeddedView];

        StageViewController* controller = [StageApplication getApplicationTopViewController];
        embeddedView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
        UIView *windowView = [controller getWindowView];
        [windowView.superview insertSubview:_renderView belowSubview:windowView];
        
    }
}

@end
