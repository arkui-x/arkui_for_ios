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

#import "AceXcomponentTextureView.h"

#import <AVFoundation/AVFoundation.h>
#include <CoreFoundation/CoreFoundation.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <QuartzCore/QuartzCore.h>

#import "AceTextureHolder.h"
#import "AceSurfaceHolder.h"
#import "StageApplication.h"
#import "WindowView.h"
#import "StageViewController.h"
#import "RenderViewXcomponent.h"

#define TEXTURE_FLAG    @"texture@"
#define PARAM_EQUALS    @"#HWJS-=-#"
#define PARAM_BEGIN     @"#HWJS-?-#"
#define METHOD          @"method"
#define EVENT           @"event"

#define TEXTURE_LEFT_KEY @"textureLeft"
#define TEXTURE_TOP_KEY @"textureTop"
#define TEXTURE_WIDTH_KEY @"textureWidth"
#define TEXTURE_HEIGHT_KEY @"textureHeight"

#define SUCCESS @"success"
#define FAIL @"false"
#define KEY_TEXTUREID @"textureId"

typedef NS_ENUM(NSUInteger, RefreshFrequency) {
    RefreshFrequencyHigh = 60,
    RefreshFrequencyLow = 36,
};

@implementation AceXcomponentWeakProxy

+ (instancetype)proxyWithTarget:(id)target
{
    AceXcomponentWeakProxy *proxy = [AceXcomponentWeakProxy alloc];
    proxy->_target = target;
    return proxy;
}

- (id)forwardingTargetForSelector:(SEL)selector
{
    return self.target;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    return [self.target methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    [invocation invokeWithTarget:self.target];
}
@end

@interface AceXcomponentTextureView () {
    RenderViewXcomponent *_renderView;
    UIView *_embeddedView;
    AVPlayer *_player;
    AVPlayer *_lastPlayer;
    AVPlayerLayer *_playerLayer;
    CGRect _currentFrame;
    void *_eglContextPtr;
    BOOL _viewAdded;
    BOOL _isVideo;
    BOOL _observingSublayers;
}

@property (nonatomic, assign) int64_t textureId;
@property (nonatomic, assign) int32_t instanceId;
@property (nonatomic, assign) int64_t textureResourceId;
@property (nonatomic, copy) IAceOnResourceEvent callback;
@property (nonatomic, strong) NSMutableDictionary<NSString*, IAceOnCallSyncResourceMethod>* callMethodMap;
@property (nonatomic, copy) IAceTextureAttachEventCallback attachCallbackHandler;
@property (nonatomic, weak) UIViewController* target;
@property (nonatomic, weak) NSObject<AcePlatformViewDelegate>* delegate;
@property (nonatomic, weak) id<IAceSurface> surfaceDelegate;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) AceTexture *renderTexture;
@property (nonatomic, assign) CGFloat screenScale;

@end

@implementation AceXcomponentTextureView

- (instancetype)initWithId:(int64_t)textureId
                instanceId:(int32_t)instanceId
                callback:(IAceOnResourceEvent)callback
                param:(NSDictionary *)initParam
                superTarget:(UIViewController *)target
                viewdelegate:(NSObject<AcePlatformViewDelegate> *)viewdelegate
                surfaceDelegate:(id<IAceSurface>)surfaceDelegate
{
    if (self = [super init]) {
        self.textureId = textureId;
        self.instanceId = instanceId;
        self.target = target;
        self.delegate = viewdelegate;
        self.surfaceDelegate = surfaceDelegate;
        self.callback = callback;
        self.callMethodMap = [[NSMutableDictionary alloc] init];
        self.screenScale = [UIScreen mainScreen].scale;
        _isVideo = NO;
        _observingSublayers = NO;
        _renderView = [[RenderViewXcomponent alloc] initWithFrame:CGRectZero];
        _renderView.autoresizesSubviews = YES;
        _embeddedView = [[UIView alloc] initWithFrame:CGRectZero];
        _embeddedView.backgroundColor = [UIColor whiteColor];
        _embeddedView.autoresizesSubviews = YES;

        [self layerCreate];
        [self startObservingEmbeddedLayer];
        [self initEventCallback];
    }
    return self;
}

- (void)layerCreate
{
    [AceSurfaceHolder addLayer:_embeddedView.layer withId:self.textureId inceId:self.instanceId];
    [self bringSubviewToFront];
}

- (void)initEventCallback
{
    __weak __typeof(self) weakSelf = self;
    IAceOnCallSyncResourceMethod callSetSurfaceSize = ^NSString * (NSDictionary *param) {
        if (weakSelf) {
            return [weakSelf setSurfaceBounds:param];
        } else {
            NSLog(@"AceSurfaceView: setSurfaceBounds fail");
            return FAIL;
        }
    };
    [self.callMethodMap setObject:[callSetSurfaceSize copy] forKey:[self method_hashFormat:@"setTextureBounds"]];

    IAceOnCallSyncResourceMethod callAttachNativeWindow = ^NSString * (NSDictionary *param) {
        if (weakSelf) {
            return [weakSelf setAttachNativeWindow:param];
        } else {
            NSLog(@"AceSurfaceView: callAttachNativeWindow fail");
            return FAIL;
        }
    };
    [self.callMethodMap setObject:[callAttachNativeWindow copy] forKey:[self method_hashFormat:@"attachNativeWindow"]];

    IAceOnCallSyncResourceMethod callAttachTextureIsVideo = ^NSString * (NSDictionary *param) {
        if (weakSelf) {
            return [weakSelf setAttachTextureIsVideo:param];
        } else {
            NSLog(@"AceSurfaceView: callAttachNativeWindow fail");
            return FAIL;
        }
    };
    [self.callMethodMap setObject:[callAttachTextureIsVideo copy] forKey:[self method_hashFormat:@"textureIsVideo"]];
}

- (void)startObservingEmbeddedLayer
{
    if (_embeddedView && !_observingSublayers) {
        [_embeddedView.layer addObserver:self forKeyPath:@"sublayers"
        options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:nil];
        _observingSublayers = YES;
    }
}

- (void)stopObservingEmbeddedLayer
{
    if (_embeddedView && _observingSublayers) {
        [_embeddedView.layer removeObserver:self forKeyPath:@"sublayers"];
        _observingSublayers = NO;
    }
}

- (NSString *)setAttachTextureIsVideo:(NSDictionary *)params
{
    NSDictionary * param = @{@"type": [NSString stringWithFormat:@"%d", _isVideo]};
    return [self convertMapToString:param];
}

- (NSString *)setSurfaceBounds:(NSDictionary *)params
{
    if (!params[TEXTURE_WIDTH_KEY] || !params[TEXTURE_HEIGHT_KEY]) {
        return FAIL;
    }
    CGFloat surfaceX = [params[TEXTURE_LEFT_KEY] floatValue];
    CGFloat surfaceY = [params[TEXTURE_TOP_KEY] floatValue];
    CGFloat surfaceWidth = [params[TEXTURE_WIDTH_KEY] floatValue];
    CGFloat surfaceHeight = [params[TEXTURE_HEIGHT_KEY] floatValue];
    CGRect textureRect = CGRectMake(surfaceX, surfaceY, surfaceWidth, surfaceHeight);
    if (!_viewAdded) {
        _viewAdded = YES;
        self.textureResourceId = [params[KEY_TEXTUREID] longLongValue];
        if (self.delegate) {
            [self.delegate registerContextPtrWithInstanceId:self.instanceId
                                                textureId:self.textureResourceId
                                                contextPtr:(void *)&_eglContextPtr];
        }
        if (!self.renderTexture) {
            AceTexture *newTexture = (AceTexture *)[AceTextureHolder getTextureWithId:self.textureResourceId
                                                                            inceId:self.instanceId];
            self.renderTexture = newTexture;
        }
        [self callSurfaceChange:textureRect];
        [self bringSubviewToFront];
        __weak __typeof(self) weakSelf = self;
        self.attachCallbackHandler = ^(int32_t textureName) {
            if (weakSelf) {
                [weakSelf textureAttach:textureName];
            }
        };
        [self.renderTexture addAttachEventCallback:self.attachCallbackHandler];
        [self initRenderTexture];
    } else {
        [self callSurfaceChange:textureRect];
        [_embeddedView layoutIfNeeded];
    }
    return SUCCESS;
}

- (void)bringSubviewToFront
{
    if (self.target) {
        StageViewController *superViewController = (StageViewController *)self.target;
        if (!superViewController) {
            return;
        }
        UIView *windowView = [superViewController getWindowView];
        if (!windowView) {
            return;
        }
        [windowView.superview insertSubview:_renderView belowSubview:windowView];
        [windowView.superview insertSubview:_embeddedView belowSubview:windowView];
    }
}

- (NSString *)setAttachNativeWindow:(NSDictionary *)params
{
    if (!self.surfaceDelegate) {
        NSLog(@"AceSurfaceView IAceSurface is null");
        return FAIL;
    }
    if (![self.surfaceDelegate respondsToSelector:@selector(attachNaitveSurface:)]) {
        NSLog(@"AceSurfaceView IAceSurface attachNaitveSurface null");
        return FAIL;
    }
    uintptr_t nativeWindow = [self.surfaceDelegate attachNaitveSurface:_embeddedView.layer];
    if (nativeWindow == 0) {
        NSLog(@"AceSurfaceView Surface nativeWindow: null");
        return FAIL;
    }
    NSDictionary *param = @{@"nativeWindow": [NSString stringWithFormat:@"%lu", (unsigned long)nativeWindow]};
    return [self convertMapToString:param];
}

- (NSString*)setSurfaceRect:(NSDictionary*)params
{
    if (!params[TEXTURE_WIDTH_KEY] || !params[TEXTURE_HEIGHT_KEY]) {
        return FAIL;
    }
    @try {
        UIScreen *screen = [UIScreen mainScreen];
        CGFloat scale = screen.scale;
        if (scale <= 0) {
            scale = 1.0;
        }
        CGFloat x = [params[TEXTURE_LEFT_KEY] floatValue];
        CGFloat y = [params[TEXTURE_TOP_KEY] floatValue];
        CGFloat width = [params[TEXTURE_WIDTH_KEY] floatValue];
        CGFloat height = [params[TEXTURE_HEIGHT_KEY] floatValue];
        CGRect surfaceRect = CGRectMake(x / scale, y / scale, width / scale, height / scale);
        CALayer *sublayer = [_embeddedView.layer.sublayers firstObject];
        if (sublayer) {
            sublayer.frame = surfaceRect;
        }
    } @catch (NSException* exception) {
        NSLog(@"AceSurfaceView NumberFormatException, setSurfaceSize failed");
        return FAIL;
    }
    return SUCCESS;
}

- (NSString *)convertMapToString:(NSDictionary *)data
{
    NSArray *pairs = [data.allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSMutableString *string = [[NSMutableString alloc] init];
    for (NSString *key in pairs) {
        id value = data[key];
        [string appendFormat:@"%@=%@;", key, value];
    }
    if (string.length > 0) {
        [string deleteCharactersInRange:NSMakeRange(string.length - 1, 1)];
    }
    return string;
}

- (void)callSurfaceChange:(CGRect)textureRect
{
    UIScreen *screen = [UIScreen mainScreen];
    CGFloat scale = screen.scale;
    if (scale <= 0) {
        scale = 1.0;
    }
    CGRect newRect = CGRectMake(textureRect.origin.x / scale,
                                textureRect.origin.y / scale,
                                textureRect.size.width / scale,
                                textureRect.size.height / scale);
    _embeddedView.frame = newRect;
    _renderView.frame = newRect;
    if (_embeddedView.layer) {
        if (!CGRectEqualToRect(_currentFrame, textureRect)) {
            _currentFrame = textureRect;
            NSString *param = [NSString stringWithFormat:@"textureWidth=%f&textureHeight=%f",
                               textureRect.size.width, textureRect.size.height];
            [self fireCallback:@"onChanged" params:param];
        }
    }
}

- (void)textureAttach:(int32_t)textureId
{
    __weak __typeof(self) weakSelf = self;
    dispatch_main_async_safe(^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            NSLog(@"error: textureAttach strongSelf is nil");
            return;
        }
        if (strongSelf->_eglContextPtr == nullptr) {
            NSLog(@"error: textureAttach _eglContextPtr is null");
            return;
        }
        [strongSelf->_renderView setEAGLContext:(__bridge EAGLContext*)strongSelf->_eglContextPtr];
        [strongSelf->_renderView setTextureName:textureId];
        [strongSelf->_renderView initXComponent:strongSelf->_embeddedView];
        [strongSelf displayLinkPlay];
    });
}

- (void)fireCallback:(NSString *)method params:(NSString *)params
{
    if (self.callback) {
        NSString *method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", 
        TEXTURE_FLAG, self.textureId, EVENT, PARAM_EQUALS, method, PARAM_BEGIN];
        self.callback(method_hash, params);
    }
}

- (NSString *)method_hashFormat:(NSString *)method
{
    return [NSString stringWithFormat:@"%@%lld%@%@%@%@",
            TEXTURE_FLAG, self.textureId, METHOD, PARAM_EQUALS, method, PARAM_BEGIN];
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

#pragma mark - displayLink update
- (void)displayLinkDidrefresh
{
    if (!_displayLink) {
        return;
    }
    if (_isVideo && _player) {
        [self refreshPixelBuffer];
    } else {
        __weak AceXcomponentTextureView *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf == nil) {
                return;
            }
            [weakSelf refreshRenderTexture];
        });
    }
}

- (void)refreshRenderTexture
{
    if (_renderView != nullptr && _viewAdded) {
        if (_renderView.isTouchIng) {
            [self adjustRefreshRate:RefreshFrequencyHigh];
        } else {
            [self adjustRefreshRate:RefreshFrequencyLow];
        }
        [_renderView startRenderXComponent:_embeddedView];
        if (self.displayLink) {
            [self refreshPixelBuffer];
        }
    }
}

- (BOOL)displayLinkPlay
{
    if (self.displayLink) {
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        return YES;
    }
    return NO;
}

- (void)updateEmbeddedPlayerState {
    __block BOOL found = NO;
    [_embeddedView.layer.sublayers enumerateObjectsUsingBlock:
    ^(__kindof CALayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[AVPlayerLayer class]]) {
            AVPlayerLayer *pLayer = (AVPlayerLayer *)obj;
            _playerLayer = pLayer;
            _player = pLayer.player;
            found = YES;
            *stop = YES;
        }
    }];
    if (!found) {
        _playerLayer = nil;
        _player = nil;
    }
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if (!(object == _embeddedView.layer && [keyPath isEqualToString:@"sublayers"])) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    [self updateEmbeddedPlayerState];
    if (!_player || !_player.currentItem || !self.renderTexture || !self.renderTexture.videoOutput) {
        return;
    }
    AVPlayerItem *item = _player.currentItem;
    if (![item isKindOfClass:[AVPlayerItem class]] || item.status != AVPlayerItemStatusReadyToPlay) {
        return;
    }
    [item addOutput:self.renderTexture.videoOutput];
    _isVideo = YES;
    if (self.delegate) {
        [self.delegate registerContextPtrWithInstanceId:self.instanceId
                                              textureId:self.textureResourceId
                                              contextPtr:(__bridge void*)self.renderTexture.videoOutput];
    }
}

#pragma mark - public
- (NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *)getCallMethod
{
    return self.callMethodMap;
}

- (void)releaseObject {
    NSLog(@"AceSurfaceView releaseObject isMainThread: %ld", [NSThread isMainThread]);
    [self stopObservingEmbeddedLayer];

    if (_player && _player.currentItem && self.renderTexture && self.renderTexture.videoOutput) {
        [_player.currentItem removeOutput:self.renderTexture.videoOutput];
    }
    _player = nil;
    _playerLayer = nil;

    if (_viewAdded) {
        _viewAdded = NO;
    }
    if (_displayLink) {
        [_displayLink invalidate];
        _displayLink = nil;
    }
    if (_attachCallbackHandler) {
        _attachCallbackHandler = nil;
    }
    if (self.renderTexture) {
        self.renderTexture = nil;
    }
    if (self.callMethodMap) {
        for (id key in self.callMethodMap) {
            IAceOnCallSyncResourceMethod block = [self.callMethodMap objectForKey:key];
            block = nil;
        }
        [self.callMethodMap removeAllObjects];
        self.callMethodMap = nil;
    }
    if (_callback) {
        _callback = nil;
    }
    if (_embeddedView) {
        [AceSurfaceHolder removeLayerWithId:self.textureId inceId:self.instanceId];
        [_embeddedView removeFromSuperview];
        _embeddedView = nil;
    }
    if (_renderView) {
        [_renderView releaseObject];
        [_renderView removeFromSuperview];
        _renderView = nil;
    }
}

#pragma mark - lazys
- (CADisplayLink *)displayLink
{
    if (!_displayLink) {
        id weakProxy = [AceXcomponentWeakProxy proxyWithTarget:self];
        _displayLink = [CADisplayLink displayLinkWithTarget:weakProxy
                                                   selector:@selector(displayLinkDidrefresh)];
        auto mainMaxFrameRate = [UIScreen mainScreen].maximumFramesPerSecond;
        double maxFrameRate = fmin(mainMaxFrameRate, (double)RefreshFrequencyHigh);
        double minFrameRate = fmin(mainMaxFrameRate / 2, maxFrameRate);
        if (@available(iOS 15.0, *)) {
            _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(
                minFrameRate, maxFrameRate, maxFrameRate);
        } else {
            _displayLink.preferredFramesPerSecond = RefreshFrequencyHigh;
        }
    }
    return _displayLink;
}

- (void)adjustRefreshRate:(RefreshFrequency)frequency
{
    if (_displayLink.preferredFramesPerSecond != frequency) {
        if (@available(iOS 15.0, *) && frequency == RefreshFrequencyHigh) {
            auto mainMaxFrameRate = [UIScreen mainScreen].maximumFramesPerSecond;
            double maxFrameRate = fmin(mainMaxFrameRate, (double)RefreshFrequencyHigh);
            double minFrameRate = fmin(mainMaxFrameRate / 2, maxFrameRate);
            _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(
                minFrameRate, maxFrameRate, maxFrameRate);
        } else {
            _displayLink.preferredFramesPerSecond = frequency;
        }
    }
}

- (void)dealloc
{
}
@end