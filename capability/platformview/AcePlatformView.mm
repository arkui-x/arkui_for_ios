/*
 * Copyright (c) 2024-2026 Huawei Device Co., Ltd.
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
#include "base/log/log.h"

#import "AcePlatformView.h"
#import "AceTextureHolder.h"
#import <AVFoundation/AVFoundation.h>
#import "render/MetalTextureRenderer.h"
#import "StageApplication.h"
#import "WindowView.h"

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <CoreImage/CoreImage.h>

#define PLATFORMVIEW_FLAG      @"platformview@"
#define PARAM_AND       @"#HWJS-&-#"
#define PARAM_EQUALS    @"#HWJS-=-#"
#define PARAM_BEGIN     @"#HWJS-?-#"
#define PARAM_SURFACETYPE     @"surface"
#define METHOD          @"method"
#define EVENT           @"event"

#define SUCCESS         @"success"
#define FAIL            @"fail"
#define KEY_TEXTUREID   @"textureId"

#define PLATFORMVIEW_WIDTH     @"platformViewWidth"
#define PLATFORMVIEW_HEIGHT    @"platformViewHeight"
#define PLATFORMVIEW_TOP       @"platformViewTop"
#define PLATFORMVIEW_LEFT      @"platformViewLeft"
#define SCROLL_EDGE_EFFECT_CLASS        @"ScrollEdgeEffect"
#define SCROLL_EDGE_EFFECT_BACKDROP     @"Backdrop"
#define SCROLL_EDGE_EFFECT_LUMINANCE    @"Luminance"
#define SCROLL_EDGE_EFFECT_POCKETMASK   @"PocketMask"

const static CGFloat PLATFORMVIEW_Z_POSITION = -1000.0f;
const static CGFloat PLATFORMVIEW_DEFAULT_CAMERA_DISTANCE_PX = 576.0f;
const static CGFloat PLATFORMVIEW_INCH = 72.0f;
const static size_t QueueSize = 3;
const static NSInteger PLATFORMVIEW_MIN_ACTIVE_FRAME_RATE = 60;
const static NSInteger PLATFORMVIEW_FRAME_RATE_DIVISOR = 2;
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

@property(nonatomic, assign) CGFloat frameWidth;
@property(nonatomic, assign) CGFloat frameHeight;
@property(nonatomic, assign) CGFloat frameTop;
@property(nonatomic, assign) CGFloat frameLeft;
@property(nonatomic, assign) CGFloat screenScale;

@property(nonatomic, strong) NSDictionary *pendingScaleParams;
@property(nonatomic, strong) NSDictionary *pendingTransformMatrixParams;
@property(nonatomic, strong) NSDictionary *pendingTranslateParams;
@property(nonatomic, strong) NSDictionary *pendingRotateParams;
@property(nonatomic, assign) CATransform3D originalTransform;
@property(nonatomic, strong) MetalTextureRenderer *metalTextureRenderer;
@end

@implementation AcePlatformView
{
    AVPlayer *_player;
    AVPlayerLayer *_playerLayer;
    bool _initView;
    bool _isVideo;
    bool _isRenderFinish;
    UIView *_scrollEdgeEffectView;
}

namespace {
inline CGFloat NormalizeCenterValue(UIView *targetView, NSString *key, CGFloat numberValue, CGFloat defaultValue)
{
    if ([key isEqualToString:@"centerX"]) {
        CGFloat width = targetView.frame.size.width;
        return width > 0 ? numberValue / width : defaultValue;
    }
    if ([key isEqualToString:@"centerY"]) {
        CGFloat height = targetView.frame.size.height;
        return height > 0 ? numberValue / height : defaultValue;
    }
    return numberValue;
}

inline NSString *TrimmedNumberString(NSString *value, NSString *suffix)
{
    static NSCharacterSet *whitespaceSet = nil;
    if (whitespaceSet == nullptr) {
        whitespaceSet = [NSCharacterSet whitespaceCharacterSet];
    }
    return [[value stringByReplacingOccurrencesOfString:suffix withString:@""]
        stringByTrimmingCharactersInSet:whitespaceSet];
}

inline CGFloat ParsePercent(UIView *targetView, NSString *key, NSString *value)
{
    CGFloat percentValue = [TrimmedNumberString(value, @"%") doubleValue] / 100.0f;
    if ([key isEqualToString:@"X"]) {
        return percentValue * targetView.frame.size.width;
    }
    if ([key isEqualToString:@"Y"]) {
        return percentValue * targetView.frame.size.height;
    }
    if ([key isEqualToString:@"Z"]) {
        return 0;
    }
    return percentValue;
}

inline NSString *RunOnMainSync(NSString* (^block)(void))
{
    if ([NSThread isMainThread]) {
        return block();
    }
    __block NSString *result = FAIL;
    dispatch_sync(dispatch_get_main_queue(), ^{
        result = block();
    });
    return result;
}
} // namespace

- (instancetype)initWithEvents:(IAceOnResourceEvent)callback
    id:(int64_t)id abilityInstanceId:(int32_t)abilityInstanceId
    viewdelegate:(NSObject<AcePlatformViewDelegate>*)viewdelegate
{
    if ((self = [super init]) != nullptr) {
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
        self.pendingScaleParams = nil;
        self.pendingTransformMatrixParams = nil;
        self.pendingTranslateParams = nil;
        self.pendingRotateParams = nil;
        self.originalTransform = CATransform3DIdentity;
        _initView = false;
        _isRenderFinish = false;
        _isVideo = false;
        self.callSyncMethodMap = [[NSMutableDictionary alloc] init];
        [self initEventCallback];
    }
    return self;
}

- (void)initEventCallback
{
    [self registerPlatformViewCallback];
    [self registerUpdateLayoutCallback];
    [self registerExchangeBindCallback];
    [self registerPlatformViewTypeCallback];
    [self registerSetRotationCallback];
    [self registerSetScaleCallback];
    [self registerSetTranslateCallback];
    [self registerSetTransformMatrixCallback];
}

- (void)registerPlatformViewCallback
{
    __weak __typeof(self)weakSelf = self;
    IAceOnCallSyncResourceMethod register_callback = ^NSString *(NSDictionary * param){
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf != nullptr) {
            return RunOnMainSync(^NSString *{
                return [strongSelf registerPlatformView:param];
            });
        } else {
            LOGE("AcePlatformView: registerPlatformView fail");
            return FAIL;
        }
    };
    NSString *register__method_hash = [self method_hashFormat:@"registerPlatformView"];
    [self.callSyncMethodMap setObject:[register_callback copy] forKey:register__method_hash];
}

- (void)registerUpdateLayoutCallback
{
    __weak __typeof(self)weakSelf = self;
    NSString *updatelayout_method_hash = [self method_hashFormat:@"updateLayout"];
    IAceOnCallSyncResourceMethod updatelayout_callback = ^NSString *(NSDictionary * param){
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf != nullptr) {
            return RunOnMainSync(^NSString *{
                return [strongSelf updatelayout:param];
            });
        } else {
            LOGE("AcePlatformView: updatelayout fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[updatelayout_callback copy] forKey:updatelayout_method_hash];
}

- (void)registerExchangeBindCallback
{
    __weak __typeof(self)weakSelf = self;
    NSString *exchange_bind_method_hash = [self method_hashFormat:@"exchangeBind"];
    IAceOnCallSyncResourceMethod exchange_bind_callback = ^NSString *(NSDictionary * param){
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf != nullptr) {
            return RunOnMainSync(^NSString *{
                return [strongSelf exchangeBind:param];
            });
        } else {
            LOGE("AcePlatformView: exchangeBind fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[exchange_bind_callback copy] forKey:exchange_bind_method_hash];
}

- (void)registerPlatformViewTypeCallback
{
    __weak __typeof(self)weakSelf = self;
    NSString *platform_view_type_hash = [self method_hashFormat:@"platformViewType"];
    IAceOnCallSyncResourceMethod platform_view_type_callback = ^NSString *(NSDictionary * param){
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf != nullptr) {
            return RunOnMainSync(^NSString *{
                return [strongSelf platformViewType:param];
            });
        } else {
            LOGE("AcePlatformView: platformViewType fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[platform_view_type_callback copy] forKey:platform_view_type_hash];
}

- (void)registerSetRotationCallback
{
    __weak __typeof(self)weakSelf = self;
    NSString *setRotation_method_hash = [self method_hashFormat:@"setRotation"];
    IAceOnCallSyncResourceMethod setRotation_callback = ^NSString *(NSDictionary * param){
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf != nullptr) {
            return RunOnMainSync(^NSString *{
                return [strongSelf setRotation:param];
            });
        } else {
            LOGE("AcePlatformView: SetRotation fail");
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[setRotation_callback copy] forKey:setRotation_method_hash];
}

- (void)registerSetScaleCallback
{
    __weak __typeof(self)weakSelf = self;
    NSString *setScale_method_hash = [self method_hashFormat:@"setScale"];
    IAceOnCallSyncResourceMethod setScale_callback = ^NSString *(NSDictionary * param) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf != nullptr) {
            return RunOnMainSync(^NSString *{
                return [strongSelf setScale:param];
            });
        } else {
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[setScale_callback copy] forKey:setScale_method_hash];
}

- (void)registerSetTranslateCallback
{
    __weak __typeof(self)weakSelf = self;
    NSString *setTranslate_method_hash = [self method_hashFormat:@"setTranslate"];
    IAceOnCallSyncResourceMethod setTranslate_callback = ^NSString *(NSDictionary * param) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf != nullptr) {
            return RunOnMainSync(^NSString *{
                return [strongSelf setTranslate:param];
            });
        } else {
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[setTranslate_callback copy] forKey:setTranslate_method_hash];
}

- (void)registerSetTransformMatrixCallback
{
    __weak __typeof(self)weakSelf = self;
    NSString *setTransformMatrix_method_hash = [self method_hashFormat:@"setTransformMatrix"];
    IAceOnCallSyncResourceMethod setTransformMatrix_callback = ^NSString *(NSDictionary * param) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf != nullptr) {
            return RunOnMainSync(^NSString *{
                return [strongSelf setTransformMatrix:param];
            });
        } else {
            return FAIL;
        }
    };
    [self.callSyncMethodMap setObject:[setTransformMatrix_callback copy] forKey:setTransformMatrix_method_hash];
}

- (CGFloat)getDataFromParams:(UIView *)targetView params:(NSDictionary *)params
    key:(NSString *)key defaultValue:(CGFloat)defaultValue
{
    id value = params[key];
    if (value == nullptr || value == [NSNull null] || targetView == nullptr) {
        return defaultValue;
    }
    if (![value isKindOfClass:[NSString class]] || [(NSString *)value length] == 0) {
        return defaultValue;
    }

    NSString *stringValue = (NSString *)value;
    if ([stringValue containsString:@"%"]) {
        return ParsePercent(targetView, key, stringValue);
    }
    if ([stringValue containsString:@"vp"]) {
        return [TrimmedNumberString(stringValue, @"vp") doubleValue];
    }
    if ([stringValue containsString:@"px"]) {
        return [TrimmedNumberString(stringValue, @"px") doubleValue] / self.screenScale;
    }
    if ([stringValue containsString:@"deg"]) {
        return [TrimmedNumberString(stringValue, @"deg") doubleValue];
    }

    return NormalizeCenterValue(targetView, key, [stringValue doubleValue], defaultValue);
}

- (void)applyScaleToTargetView:(UIView *)targetView
{
    if (targetView == nullptr || self.pendingScaleParams == nullptr) {
        return;
    }
    CGFloat scaleX = [self getDataFromParams:targetView params:self.pendingScaleParams key:@"X" defaultValue:1.0f];
    CGFloat scaleY = [self getDataFromParams:targetView params:self.pendingScaleParams key:@"Y" defaultValue:1.0f];
    CGFloat scaleZ = [self getDataFromParams:targetView params:self.pendingScaleParams key:@"Z" defaultValue:1.0f];
    CGFloat centerX = [self getDataFromParams:targetView params:self.pendingScaleParams key:@"centerX" defaultValue:0];
    CGFloat centerY = [self getDataFromParams:targetView params:self.pendingScaleParams key:@"centerY" defaultValue:0];

    targetView.layer.anchorPoint = CGPointMake(centerX, centerY);
    CATransform3D transform3D = CATransform3DMakeScale(scaleX, scaleY, scaleZ);
    targetView.layer.zPosition = PLATFORMVIEW_Z_POSITION;
    targetView.layer.transform = CATransform3DConcat(targetView.layer.transform, transform3D);
}

- (void)applyTransformMatrixToTargetView:(UIView *)targetView
{
    if (targetView == nullptr || self.pendingTransformMatrixParams == nullptr) {
        return;
    }
    for (int i = 0; i < 16; i++) {
        NSString *key = [NSString stringWithFormat:@"m%d", i];
        if (self.pendingTransformMatrixParams[key] == nullptr) {
            LOGE("AcePlatformView: Transform matrix parameter %{public}d missing", i);
            return;
        }
    }
    CATransform3D transform3D = CATransform3DIdentity;
    transform3D.m11 = (CGFloat)[self.pendingTransformMatrixParams[@"m0"] doubleValue];
    transform3D.m12 = (CGFloat)[self.pendingTransformMatrixParams[@"m1"] doubleValue];
    transform3D.m13 = (CGFloat)[self.pendingTransformMatrixParams[@"m2"] doubleValue];
    transform3D.m14 = (CGFloat)[self.pendingTransformMatrixParams[@"m3"] doubleValue];
    transform3D.m21 = (CGFloat)[self.pendingTransformMatrixParams[@"m4"] doubleValue];
    transform3D.m22 = (CGFloat)[self.pendingTransformMatrixParams[@"m5"] doubleValue];
    transform3D.m23 = (CGFloat)[self.pendingTransformMatrixParams[@"m6"] doubleValue];
    transform3D.m24 = (CGFloat)[self.pendingTransformMatrixParams[@"m7"] doubleValue];
    transform3D.m31 = (CGFloat)[self.pendingTransformMatrixParams[@"m8"] doubleValue];
    transform3D.m32 = (CGFloat)[self.pendingTransformMatrixParams[@"m9"] doubleValue];
    transform3D.m33 = (CGFloat)[self.pendingTransformMatrixParams[@"m10"] doubleValue];
    transform3D.m34 = (CGFloat)[self.pendingTransformMatrixParams[@"m11"] doubleValue];
    transform3D.m41 = (CGFloat)[self.pendingTransformMatrixParams[@"m12"] doubleValue] / self.screenScale;
    transform3D.m42 = (CGFloat)[self.pendingTransformMatrixParams[@"m13"] doubleValue] / self.screenScale;
    transform3D.m43 = (CGFloat)[self.pendingTransformMatrixParams[@"m14"] doubleValue] / self.screenScale;
    transform3D.m44 = (CGFloat)[self.pendingTransformMatrixParams[@"m15"] doubleValue];
    targetView.layer.zPosition = PLATFORMVIEW_Z_POSITION;
    targetView.layer.transform = CATransform3DConcat(targetView.layer.transform, transform3D);
}

- (void)applyPendingTransformations:(UIView *)targetView
{
    if (targetView == nullptr) {
        return;
    }
    [self applyScaleToTargetView:targetView];
    [self applyTranslateToTargetView:targetView];
    [self applyRotateToTargetView:targetView];
    [self applyTransformMatrixToTargetView:targetView];
}

- (void)applyTranslateToTargetView:(UIView *)targetView
{
    if (targetView == nullptr || self.pendingTranslateParams == nullptr) {
        return;
    }
    CGFloat translateX = [self getDataFromParams:targetView params:self.pendingTranslateParams key:@"X" defaultValue:0.0f];
    CGFloat translateY = [self getDataFromParams:targetView params:self.pendingTranslateParams key:@"Y" defaultValue:0.0f];
    CGFloat translateZ = [self getDataFromParams:targetView params:self.pendingTranslateParams key:@"Z" defaultValue:0.0f];

    CATransform3D transform3D = CATransform3DIdentity;
    transform3D.m34 = -1.0f / [self getDefaultCameraDistanceForView:targetView];
    transform3D = CATransform3DTranslate(transform3D, 0.0f, 0.0f, -translateZ);
    targetView.layer.zPosition = PLATFORMVIEW_Z_POSITION;
    targetView.layer.transform = CATransform3DConcat(targetView.layer.transform, transform3D);
    CGPoint basePosition = targetView.layer.position;
    targetView.layer.position = CGPointMake(basePosition.x + translateX, basePosition.y + translateY);
}

- (void)applyRotateToTargetView:(UIView *)targetView
{
    if (targetView == nullptr || self.pendingRotateParams == nullptr) {
        return;
    }
    CGFloat rotationX = [self getDataFromParams:targetView params:self.pendingRotateParams key:@"X" defaultValue:0.0f];
    CGFloat rotationY = [self getDataFromParams:targetView params:self.pendingRotateParams key:@"Y" defaultValue:0.0f];
    CGFloat rotationZ = [self getDataFromParams:targetView params:self.pendingRotateParams key:@"Z" defaultValue:1.0f];
    CGFloat rotationAngle = [self getDataFromParams:targetView params:self.pendingRotateParams key:@"angle" defaultValue:0.0f];
    CGFloat centerX = [self getDataFromParams:targetView params:self.pendingRotateParams key:@"centerX" defaultValue:0.5f];
    CGFloat centerY = [self getDataFromParams:targetView params:self.pendingRotateParams key:@"centerY" defaultValue:0.5f];
    CGFloat centerZ = [self getDataFromParams:targetView params:self.pendingRotateParams key:@"centerZ" defaultValue:0.0f];
    CGFloat perspective = [self getDataFromParams:targetView params:self.pendingRotateParams key:@"perspective" defaultValue:0.0f];

    targetView.layer.anchorPoint = CGPointMake(centerX, centerY);
    targetView.layer.anchorPointZ = centerZ / self.screenScale;
    CATransform3D transform = CATransform3DIdentity;
    if (fabs(perspective) > FLT_EPSILON) {
        transform.m34 = 1.0f / (perspective / self.screenScale * PLATFORMVIEW_INCH);
    } else {
        transform.m34 = -1.0f / [self getDefaultCameraDistanceForView:targetView];
    }

    CGFloat norm = sqrt(rotationX * rotationX + rotationY * rotationY + rotationZ * rotationZ);
    if (norm > FLT_EPSILON) {
        CGFloat angleX = rotationAngle * rotationX / norm;
        CGFloat angleY = rotationAngle * rotationY / norm;
        CGFloat angleZ = rotationAngle * rotationZ / norm;
        transform = CATransform3DRotate(transform, angleX * M_PI / 180.0, 1.0f, 0.0f, 0.0f);
        transform = CATransform3DRotate(transform, angleY * M_PI / 180.0, 0.0f, 1.0f, 0.0f);
        transform = CATransform3DRotate(transform, angleZ * M_PI / 180.0, 0.0f, 0.0f, 1.0f);
        targetView.layer.zPosition = PLATFORMVIEW_Z_POSITION;
        targetView.layer.transform = CATransform3DConcat(targetView.layer.transform, transform);
    }
}

- (NSString *)setRotation:(NSDictionary *)params
{
    if (params == nullptr) {
        return FAIL;
    }
    self.pendingRotateParams = params;
    return SUCCESS;
}

- (NSString *)setScale:(NSDictionary *)params
{
    if (params == nullptr) {
        return FAIL;
    }
    self.pendingScaleParams = params;
    return SUCCESS;
}

- (NSString *)setTranslate:(NSDictionary *)params
{
    if (params == nullptr) {
        return FAIL;
    }
    self.pendingTranslateParams = params;
    return SUCCESS;
}

- (NSString *)setTransformMatrix:(NSDictionary *)params
{
    UIView* targetView = [self getPlatformView];
    if (targetView == nullptr) {
        return FAIL;
    }
    self.pendingTransformMatrixParams = params;
    return SUCCESS;
}

- (void)setPlatformView:(NSObject<IPlatformView>*)platformView
{
    self.curPlatformView = platformView;
    UIView *view = [platformView view];
   if (view != nullptr && view.superview != nullptr) {
       self.originalTransform = view.layer.transform;
   }
    NSObject<IPlatformView>* embeddedView = self.curPlatformView;
    if (embeddedView == nullptr) {
        LOGE("AcePlatformView: setPlatformView failed: platformView is null");
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
    if (params == nullptr) {
        LOGE("AcePlatformView: registerPlatformView failed: params is null");
        return FAIL;
    }
    UIView* platformView = [self getPlatformView];
    if (params[KEY_TEXTUREID] == nil) {
        [self initWithSurfaceView:platformView];
        return SUCCESS;
    }
    self.textureResourceId = [params[KEY_TEXTUREID] longLongValue];
    if (self.renderTexture == nullptr) {
        AceTexture *newTexture = (AceTexture*)[AceTextureHolder getTextureWithId:self.textureResourceId
            inceId:self.instanceId];
        self.renderTexture = newTexture;
    }
    _metalTextureRenderer = [[MetalTextureRenderer alloc] initWithFrame:CGRectZero];
    [self initPlatformView];
    if (_isVideo && _player != nullptr) {
        [_player.currentItem addOutput:self.renderTexture.videoOutput];
        [self initWithEmbeddedView:platformView];
        [self initRenderTexture];
    } else {
        [self.delegate registerBufferWithInstanceId:self.instanceId
                                          textureId:self.textureResourceId
                                 texturePixelBuffer:(__bridge void*)_metalTextureRenderer];
        [self initWithEmbeddedView:platformView];
        [self platformViewReady];
        _initView = true;
    }
    return SUCCESS;
}

- (void)platformViewReady
{
    if (self.onEvent != nullptr) {
        NSString *prepared_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@",
                PLATFORMVIEW_FLAG, self.id, EVENT, PARAM_EQUALS, @"platformViewReady", PARAM_BEGIN];
        LOGI("[PlatformView] platformViewReady");
        self.onEvent(prepared_method_hash, @"");
    }
}

- (NSString *)updatelayout:(NSDictionary *)params
{
    if (params == nullptr) {
        LOGE("AcePlatformView: setSurface failed: params is null");
        return FAIL;
    }

    @try {
        UIView* platformView = [self getPlatformView];
        platformView.layer.transform = self.originalTransform;
        self.frameWidth = [params[PLATFORMVIEW_WIDTH] floatValue];
        self.frameHeight = [params[PLATFORMVIEW_HEIGHT] floatValue];
        self.frameTop = [params[PLATFORMVIEW_TOP] floatValue];
        self.frameLeft = [params[PLATFORMVIEW_LEFT] floatValue];
        [self updateNativeFrame];
        [self applyPendingTransformations:platformView];
    } @catch (NSException *exception) {
        LOGE("AcePlatformView: IOException, updatelayout failed");
        return FAIL;
    }
    return SUCCESS;
}

- (BOOL)initPlatformView
{
    if (self.displayLink != nullptr) {
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        return YES;
    }
    return NO;
}

- (CADisplayLink *)displayLink
{
    if (_displayLink == nullptr) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkDidrefresh)];
        [self updateDisplayLinkFrameRate];
    }
    return _displayLink;
}

- (void)updateDisplayLinkFrameRate
{
    if (_displayLink == nullptr) {
        return;
    }
    NSInteger mainMaxFrameRate = [UIScreen mainScreen].maximumFramesPerSecond;
    NSInteger activeFrameRate = MAX(mainMaxFrameRate, PLATFORMVIEW_MIN_ACTIVE_FRAME_RATE);
    if (@available(iOS 15.0, *)) {
        double targetMaxFrameRate = activeFrameRate;
        double targetMinFrameRate = fmin(activeFrameRate / PLATFORMVIEW_FRAME_RATE_DIVISOR, targetMaxFrameRate);
        _displayLink.preferredFrameRateRange =
            CAFrameRateRangeMake(targetMinFrameRate, targetMaxFrameRate, targetMaxFrameRate);
    } else {
        _displayLink.preferredFramesPerSecond = activeFrameRate;
    }
}

- (void)displayLinkDidrefresh
{
    if (_isVideo) {
        if (self.displayLink != nullptr) {
            [self refreshPixelBuffer];
        }
        return;
    }
    NSObject<IPlatformView>* embeddedView = self.curPlatformView;
    if (embeddedView == nullptr) {
        LOGE("AcePlatformView: register failed: platformView is null");
        return;
    }
    UIView* platformView = [embeddedView view];
    if (@available(iOS 26.0, *) && [platformView isKindOfClass:[WKWebView class]]) {
        [self hideScrollEdgeEffectSubviews:platformView];
    }
    if (_initView) {
        _isRenderFinish = [_metalTextureRenderer startRender:platformView];
    }
    if (self.displayLink != nullptr && _isRenderFinish) {
        [self refreshPixelBuffer];
    }
}

/*
 * For iOS 26 and above, the subview CARenderer of WKWebView named "ScrollEdgeEffect" causes unexpected rendering
 * effects during off-screen rendering.
 */
- (void)hideScrollEdgeEffectSubviews:(UIView*)view
{
    if (_scrollEdgeEffectView != nullptr) {
        return;
    }
    NSString* className = NSStringFromClass([view class]);
    if ([className containsString:SCROLL_EDGE_EFFECT_CLASS]) {
        view.alpha = 0;
        _scrollEdgeEffectView = view;
        for (UIView* effectSubview in view.subviews) {
            NSString* effectClassName = NSStringFromClass([effectSubview class]);
            if ([effectClassName containsString:SCROLL_EDGE_EFFECT_BACKDROP] ||
                [effectClassName containsString:SCROLL_EDGE_EFFECT_LUMINANCE] ||
                [effectClassName containsString:SCROLL_EDGE_EFFECT_POCKETMASK]) {
                effectSubview.alpha = 0;
            }
        }
        return;
    }
    for (UIView* subview in view.subviews) {
        [self hideScrollEdgeEffectSubviews:subview];
    }
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

- (NSString *)method_hashFormat:(NSString *)method
{
    return [NSString stringWithFormat:@"%@%lld%@%@%@%@", PLATFORMVIEW_FLAG, self.id, METHOD, PARAM_EQUALS, method, PARAM_BEGIN];
}

- (CGFloat)getDefaultCameraDistanceForView:(UIView *)view
{
    CGFloat widthPx = view ? (CGRectGetWidth(view.bounds) * self.screenScale) : 0.0f;
    CGFloat heightPx = view ? (CGRectGetHeight(view.bounds) * self.screenScale) : 0.0f;
    CGFloat zOffsetPx = sqrt(widthPx * widthPx + heightPx * heightPx) / 2.0f;
    CGFloat distancePx = PLATFORMVIEW_DEFAULT_CAMERA_DISTANCE_PX + zOffsetPx;
    CGFloat distancePt = distancePx / self.screenScale;
    return distancePt > FLT_EPSILON ? distancePt : 1.0f;
}

- (CGRect)getTargetPlatformViewFrame
{
    CGFloat scaledLeft = self.frameLeft / self.screenScale;
    CGFloat scaledTop = self.frameTop / self.screenScale;
    StageViewController* controller = [StageApplication getApplicationTopViewController];
    if (!controller.navigationController.navigationBarHidden) {
        scaledTop += [self getSafeAreaHeight];
    }
    CGFloat scaledWidth = self.frameWidth / self.screenScale;
    CGFloat scaledHeight = self.frameHeight / self.screenScale;
    return CGRectMake(scaledLeft, scaledTop, scaledWidth, scaledHeight);
}

- (void)updateNativeFrame
{
    UIView* platformView = [self getPlatformView];
    if (platformView == nullptr) {
        return;
    }
    if (_metalTextureRenderer != nullptr) {
        StageViewController* controller = [StageApplication getApplicationTopViewController];
        if (controller.navigationController.navigationBarHidden) {
            _metalTextureRenderer.frame =
                CGRectMake(0, 0, controller.view.bounds.size.width, controller.view.bounds.size.height);
        } else {
            _metalTextureRenderer.frame = CGRectMake(0, -[self getSafeAreaHeight], controller.view.bounds.size.width,
                controller.view.bounds.size.height + [self getSafeAreaHeight]);
        }
    }
    CGRect targetFrame = [self getTargetPlatformViewFrame];
    if (!CGRectEqualToRect(platformView.frame, targetFrame)) {
        platformView.frame = targetFrame;
    }
    if (_isVideo && _playerLayer != nullptr) {
        _playerLayer.frame = platformView.bounds;
    }
}

-(UIView*)getPlatformView {
    NSObject<IPlatformView>* embeddedView = self.curPlatformView;
    if (embeddedView == nullptr) {
        return nil;
    }
    UIView* platformView = [embeddedView view];
    return platformView;
}

- (void)releaseDisplayLinkAndCallbacks
{
    if (self.displayLink != nullptr) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
    self.onEvent = nil;
    if (self.callSyncMethodMap != nullptr) {
        for (id key in self.callSyncMethodMap) {
            IAceOnCallSyncResourceMethod block = [self.callSyncMethodMap objectForKey:key];
            block = nil;
        }
        [self.callSyncMethodMap removeAllObjects];
        self.callSyncMethodMap = nil;
    }
}

- (void)unregisterBufferIfNeeded:(NSObject<AcePlatformViewDelegate>*)viewDelegate
               textureResourceId:(int64_t)releaseTextureResourceId
                         isVideo:(bool)isVideo
{
    if (!isVideo && releaseTextureResourceId > 0) {
        [viewDelegate unregisterBufferWithInstanceId:self.instanceId textureId:releaseTextureResourceId];
    }
}

- (void)disposePlatformView:(UIView*)platformView
               embeddedView:(NSObject<IPlatformView>*)embeddedView
                   renderer:(MetalTextureRenderer*)renderer
{
    if (renderer != nullptr) {
        [renderer destroy];
    }
    if (platformView == nullptr) {
        if (embeddedView != nullptr) {
            [embeddedView onDispose];
        }
        return;
    }
    platformView.userInteractionEnabled = NO;
    platformView.hidden = YES;
    [platformView removeFromSuperview];
    StageViewController* controller = [StageApplication getApplicationTopViewController];
    UIWindow* window = controller ? controller.view.window : nil;
    if (window != nullptr) {
        [window addSubview:platformView];
    }
    if (embeddedView != nullptr) {
        [embeddedView onDispose];
    }
    [platformView removeFromSuperview];
}

- (void)clearReleaseState
{
    if (self.renderTexture != nullptr) {
        self.renderTexture = nil;
    }
    if (_player != nil) {
        _player = nil;
    }
    if (_playerLayer != nil) {
        _playerLayer = nil;
    }
    self.pendingScaleParams = nil;
    self.pendingTransformMatrixParams = nil;
    self.pendingTranslateParams = nil;
    self.pendingRotateParams = nil;
    self.delegate = nil;
    _scrollEdgeEffectView = nil;
}

- (void)releaseObject
{
    [self releaseDisplayLinkAndCallbacks];
    NSObject<IPlatformView>* embeddedView = self.curPlatformView;
    UIView* platformView = embeddedView ? [embeddedView view] : nil;
    MetalTextureRenderer* renderer = _metalTextureRenderer;
    NSObject<AcePlatformViewDelegate>* viewDelegate = self.delegate;
    int32_t releaseInstanceId = self.instanceId;
    int64_t releaseTextureResourceId = self.textureResourceId;
    bool isVideo = _isVideo;
    self.curPlatformView = nil;
    _metalTextureRenderer = nil;
    void (^releaseBlock)(void) = ^{
      [self unregisterBufferIfNeeded:viewDelegate textureResourceId:releaseTextureResourceId isVideo:isVideo];
      [self disposePlatformView:platformView embeddedView:embeddedView renderer:renderer];
    };
    if ([NSThread isMainThread]) {
        releaseBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), releaseBlock);
    }
    [self clearReleaseState];
}

- (void)onActivityResume
{
    if (self.displayLink != nullptr) {
        [self updateDisplayLinkFrameRate];
        self.displayLink.paused = NO;
        LOGI("AcePlatformView displayLink resume.");
    }
}

- (void)onActivityPause
{
    if (self.displayLink != nullptr) {
        self.displayLink.paused = YES;
        LOGI("AcePlatformView displayLink paused.");
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

- (void)initWithSurfaceView:(UIView*)surfaceView {
    StageViewController* controller = [StageApplication getApplicationTopViewController];
    surfaceView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    if (![controller isKindOfClass:[StageViewController class]]) {
        return;
    }
    UIView *windowView = [controller getWindowView];
    windowView.backgroundColor = [UIColor clearColor];
    [windowView.superview insertSubview:surfaceView belowSubview:windowView];
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
    if (_metalTextureRenderer != nullptr) {
        [_metalTextureRenderer ensureMetalSetup:embeddedView];
        [_metalTextureRenderer addSubview:embeddedView];
        StageViewController* controller = [StageApplication getApplicationTopViewController];
        embeddedView.autoresizingMask =  (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
        if (![controller isKindOfClass:[StageViewController class]]) {
            return;
        }
        UIView *windowView = [controller getWindowView];
        [windowView.superview insertSubview:_metalTextureRenderer belowSubview:windowView];
    }
}

- (CGFloat)getSafeAreaHeight
{
    CGFloat statusBarHeight = 0;
    if (@available(iOS 13.0, *)) {
        UIWindow* window = [UIApplication sharedApplication].windows.firstObject;
        statusBarHeight = window.safeAreaInsets.top;
    } else {
        statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    }
    CGFloat navigationBarHeight = 0;
    StageViewController* controller = [StageApplication getApplicationTopViewController];
    if (controller.navigationController != nullptr) {
        navigationBarHeight = controller.navigationController.navigationBar.frame.size.height;
    }
    return statusBarHeight + navigationBarHeight;
}

@end
