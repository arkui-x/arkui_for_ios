/*
 * Copyright (c) 2025-2026 Huawei Device Co., Ltd.
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
#import <CoreFoundation/CoreFoundation.h>
#import <QuartzCore/QuartzCore.h>

#import "AceTextureHolder.h"
#import "AceSurfaceCaptureHelper.h"
#import "AceSurfaceHolder.h"
#import "StageApplication.h"
#import "WindowView.h"
#import "StageViewController.h"
#import "../platformview/render/MetalTextureRenderer.h"
#import "base/log/log.h"

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

const static NSInteger XC_MIN_ACTIVE_FRAME_RATE = 60;
const static NSInteger XC_FRAME_RATE_DIVISOR = 2;

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
    MetalTextureRenderer *_metalTextureRenderer;
    UIView *_embeddedView;
    AVPlayer *_player;
    AVPlayer *_lastPlayer;
    AVPlayerLayer *_playerLayer;
    CGRect _currentFrame;
    BOOL _viewAdded;
    BOOL _isVideo;
    BOOL _observingSublayers;
    AceSurfaceCaptureHelper* _surfaceCaptureHelper;
}

@property (nonatomic, assign) int64_t textureId;
@property (nonatomic, assign) int32_t instanceId;
@property (nonatomic, assign) int64_t textureResourceId;
@property (nonatomic, copy) IAceOnResourceEvent callback;
@property (nonatomic, strong) NSMutableDictionary<NSString*, IAceOnCallSyncResourceMethod>* callMethodMap;
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
    if ((self = [super init]) != nullptr) {
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
        _metalTextureRenderer = [[MetalTextureRenderer alloc] initWithFrame:CGRectZero];
        _metalTextureRenderer.autoresizesSubviews = YES;
        _embeddedView = [[UIView alloc] initWithFrame:CGRectZero];
        _embeddedView.backgroundColor = [UIColor whiteColor];
        _embeddedView.autoresizesSubviews = YES;
        [_metalTextureRenderer ensureMetalSetup:_embeddedView];
        [_metalTextureRenderer addSubview:_embeddedView];
        __weak __typeof(self) weakSelf = self;
        NSString *strLogTag = @"AceXcomponentTextureView";
        AceSurfaceCaptureConfig* captureConfig = [[AceSurfaceCaptureConfig alloc]
            initWithWidthKey:TEXTURE_WIDTH_KEY
            heightKey:TEXTURE_HEIGHT_KEY
            logTag:[strLogTag UTF8String]
            hostLayerBlock:^CALayer* {
                __strong __typeof(weakSelf) strongSelf = weakSelf;
                return strongSelf ? strongSelf->_embeddedView.layer : nil;
            }
            drawFallbackBlock:^(CGRect bounds) {
                __strong __typeof(weakSelf) strongSelf = weakSelf;
                if (strongSelf && strongSelf->_embeddedView) {
                    [strongSelf->_embeddedView drawViewHierarchyInRect:bounds afterScreenUpdates:NO];
                }
            }];
        _surfaceCaptureHelper = [[AceSurfaceCaptureHelper alloc] initWithConfig:captureConfig];

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
        if (weakSelf != nullptr) {
            return [weakSelf setSurfaceBounds:param];
        } else {
            LOGE("AceXcomponentTextureView: setSurfaceBounds fail");
            return FAIL;
        }
    };
    [self.callMethodMap setObject:[callSetSurfaceSize copy] forKey:[self method_hashFormat:@"setTextureBounds"]];

    IAceOnCallSyncResourceMethod callAttachNativeWindow = ^NSString * (NSDictionary *param) {
        if (weakSelf != nullptr) {
            return [weakSelf setAttachNativeWindow:param];
        } else {
            LOGE("AceXcomponentTextureView: callAttachNativeWindow fail");
            return FAIL;
        }
    };
    [self.callMethodMap setObject:[callAttachNativeWindow copy] forKey:[self method_hashFormat:@"attachNativeWindow"]];

    IAceOnCallSyncResourceMethod callAttachTextureIsVideo = ^NSString * (NSDictionary *param) {
        if (weakSelf != nullptr) {
            return [weakSelf setAttachTextureIsVideo:param];
        } else {
            LOGE("AceXcomponentTextureView: callAttachTextureIsVideo fail");
            return FAIL;
        }
    };
    [self.callMethodMap setObject:[callAttachTextureIsVideo copy] forKey:[self method_hashFormat:@"textureIsVideo"]];

    IAceOnCallSyncResourceMethod callSurfaceCapture = ^NSString*(NSDictionary* param) {
            if (weakSelf) {
                return [weakSelf surfaceCapture:param];
            } else {
                 LOGE("AceXcomponentTextureView: callSurfaceCapture fail");
                 return FAIL;
            }
        };
    [self.callMethodMap setObject:[callSurfaceCapture copy] forKey:[self method_hashFormat:@"surfaceCapture"]];
}

- (NSString*)surfaceCapture:(NSDictionary*)params
{
    CGRect bounds = _embeddedView ? _embeddedView.bounds : CGRectZero;
    return _surfaceCaptureHelper ? [_surfaceCaptureHelper captureSurface:params bounds:bounds] : FAIL;
}

- (void)startObservingEmbeddedLayer
{
    if (_embeddedView != nullptr && !_observingSublayers) {
        [_embeddedView.layer addObserver:self forKeyPath:@"sublayers"
        options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:nil];
        _observingSublayers = YES;
    }
}

- (void)stopObservingEmbeddedLayer
{
    if (_embeddedView != nullptr && _observingSublayers) {
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
    if (params[TEXTURE_WIDTH_KEY] == nullptr || params[TEXTURE_HEIGHT_KEY] == nullptr) {
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
        if (self.renderTexture == nullptr) {
            AceTexture *newTexture = (AceTexture *)[AceTextureHolder getTextureWithId:self.textureResourceId
                                                                            inceId:self.instanceId];
            self.renderTexture = newTexture;
        }
        if (self.delegate != nullptr && !_isVideo && _metalTextureRenderer != nullptr) {
            [self.delegate registerBufferWithInstanceId:self.instanceId
                                              textureId:self.textureResourceId
                                     texturePixelBuffer:(__bridge void*)_metalTextureRenderer];
        }
        [self callSurfaceChange:textureRect];
        [self bringSubviewToFront];
        [self displayLinkPlay];
        [self initRenderTexture];
    } else {
        [self callSurfaceChange:textureRect];
        [_embeddedView layoutIfNeeded];
    }
    return SUCCESS;
}

- (void)bringSubviewToFront
{
    if (self.target != nullptr) {
        StageViewController *superViewController = (StageViewController *)self.target;
        if (superViewController == nullptr) {
            return;
        }
        UIView *windowView = [superViewController getWindowView];
        if (windowView == nullptr) {
            return;
        }
        if (_metalTextureRenderer != nullptr) {
            [windowView.superview insertSubview:_metalTextureRenderer belowSubview:windowView];
        }
    }
}

- (NSString *)setAttachNativeWindow:(NSDictionary *)params
{
    if (self.surfaceDelegate == nullptr) {
        LOGE("AceXcomponentTextureView IAceSurface is null");
        return FAIL;
    }
    if (![self.surfaceDelegate respondsToSelector:@selector(attachNaitveSurface:)]) {
        LOGE("AceXcomponentTextureView IAceSurface attachNaitveSurface null");
        return FAIL;
    }
    uintptr_t nativeWindow = [self.surfaceDelegate attachNaitveSurface:_embeddedView.layer];
    if (nativeWindow == 0) {
        LOGE("AceXcomponentTextureView Surface nativeWindow: null");
        return FAIL;
    }
    NSDictionary *param = @{@"nativeWindow": [NSString stringWithFormat:@"%lu", (unsigned long)nativeWindow]};
    return [self convertMapToString:param];
}

- (NSString*)setSurfaceRect:(NSDictionary*)params
{
    if (params[TEXTURE_WIDTH_KEY] == nullptr || params[TEXTURE_HEIGHT_KEY] == nullptr) {
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
        if (sublayer != nullptr) {
            sublayer.frame = surfaceRect;
        }
    } @catch (NSException* exception) {
        LOGE("AceXcomponentTextureView NumberFormatException, setSurfaceSize failed");
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
    if (_metalTextureRenderer != nullptr) {
        _metalTextureRenderer.frame = newRect;
        _embeddedView.frame = _metalTextureRenderer.bounds;
    } else {
        _embeddedView.frame = newRect;
    }
    if (_embeddedView.layer != nullptr) {
        if (!CGRectEqualToRect(_currentFrame, textureRect)) {
            _currentFrame = textureRect;
            NSString *param = [NSString stringWithFormat:@"textureWidth=%f&textureHeight=%f",
                               textureRect.size.width, textureRect.size.height];
            [self fireCallback:@"onChanged" params:param];
        }
    }
}

- (void)fireCallback:(NSString *)method params:(NSString *)params
{
    if (self.callback != nullptr) {
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
    if (self.renderTexture != nullptr) {
        [self.renderTexture refreshPixelBuffer];
    }
}

- (void)refreshPixelBuffer
{
    if (self.renderTexture != nullptr) {
        [self.renderTexture refreshPixelBuffer];
    }
}

#pragma mark - displayLink update
- (void)displayLinkDidrefresh
{
    if (_displayLink == nullptr) {
        return;
    }
    if (_isVideo && _player != nullptr) {
        [self refreshPixelBuffer];
    } else {
        __weak __typeof(self) weakSelf = self;
        dispatch_main_async_safe(^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf == nullptr) {
                LOGE("error: displayLinkDidrefresh strongSelf is nil");
                return;
            }
            [strongSelf refreshRenderTexture];
        });
    }
}

- (void)refreshRenderTexture
{
    if (_metalTextureRenderer != nullptr && _viewAdded) {
        BOOL isRenderFinish = [_metalTextureRenderer startRender:_embeddedView];
        if (self.displayLink != nullptr && isRenderFinish) {
            [self refreshPixelBuffer];
        }
    }
}

- (BOOL)displayLinkPlay
{
    if (self.displayLink != nullptr) {
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
    if (_player == nullptr || _player.currentItem == nullptr || self.renderTexture == nullptr ||
        self.renderTexture.videoOutput == nullptr) {
        return;
    }
    AVPlayerItem *item = _player.currentItem;
    if (![item isKindOfClass:[AVPlayerItem class]] || item.status != AVPlayerItemStatusReadyToPlay) {
        return;
    }
    [item addOutput:self.renderTexture.videoOutput];
    _isVideo = YES;
    if (self.delegate != nullptr) {
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
    LOGI("AceXcomponentTextureView releaseObject isMainThread: %ld", [NSThread isMainThread]);
    [self stopObservingEmbeddedLayer];

    if (_player != nullptr && _player.currentItem != nullptr && self.renderTexture != nullptr &&
        self.renderTexture.videoOutput != nullptr) {
        [_player.currentItem removeOutput:self.renderTexture.videoOutput];
    }
    _player = nil;
    _playerLayer = nil;

    if (_viewAdded) {
        _viewAdded = NO;
    }
    if (_displayLink != nullptr) {
        [_displayLink invalidate];
        _displayLink = nil;
    }
    if (self.renderTexture != nullptr) {
        self.renderTexture = nil;
    }
    _surfaceCaptureHelper = nil;
    if (self.callMethodMap != nullptr) {
        for (id key in self.callMethodMap) {
            IAceOnCallSyncResourceMethod block = [self.callMethodMap objectForKey:key];
            block = nil;
        }
        [self.callMethodMap removeAllObjects];
        self.callMethodMap = nil;
    }
    if (_callback != nullptr) {
        _callback = nil;
    }
    if (_embeddedView != nullptr) {
        [AceSurfaceHolder removeLayerWithId:self.textureId inceId:self.instanceId];
        [_embeddedView removeFromSuperview];
        _embeddedView = nil;
    }
    if (_metalTextureRenderer != nullptr) {
        [_metalTextureRenderer destroy];
        [_metalTextureRenderer removeFromSuperview];
        _metalTextureRenderer = nil;
    }
}

#pragma mark - lazys
- (CADisplayLink *)displayLink
{
    if (_displayLink == nullptr) {
        id weakProxy = [AceXcomponentWeakProxy proxyWithTarget:self];
        _displayLink = [CADisplayLink displayLinkWithTarget:weakProxy selector:@selector(displayLinkDidrefresh)];
        NSInteger mainMaxFrameRate = [UIScreen mainScreen].maximumFramesPerSecond;
        NSInteger activeFrameRate = MAX(mainMaxFrameRate, XC_MIN_ACTIVE_FRAME_RATE);
        if (@available(iOS 15.0, *)) {
            double targetMaxFrameRate = activeFrameRate;
            double targetMinFrameRate = fmin(activeFrameRate / XC_FRAME_RATE_DIVISOR, targetMaxFrameRate);
            _displayLink.preferredFrameRateRange =
                CAFrameRateRangeMake(targetMinFrameRate, targetMaxFrameRate, targetMaxFrameRate);
        } else {
            _displayLink.preferredFramesPerSecond = activeFrameRate;
        }
    }
    return _displayLink;
}

- (void)dealloc
{
}
@end