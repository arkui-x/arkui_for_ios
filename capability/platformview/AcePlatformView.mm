/*
 * Copyright (c) 2024-2025 Huawei Device Co., Ltd.
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
const static CGFloat PLATFORMVIEW_Z_POSITION = -1000.0f;
const static CGFloat PLATFORMVIEW_DEFAULT_CAMERA_DISTANCE_PX = 576.0f;
const static CGFloat PLATFORMVIEW_INCH = 72.0f;
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

@property(nonatomic, strong) NSDictionary *pendingScaleParams;
@property(nonatomic, strong) NSDictionary *pendingTransformMatrixParams;
@property(nonatomic, strong) NSDictionary *pendingTranslateParams;
@property(nonatomic, strong) NSDictionary *pendingRotateParams;
@property(nonatomic, assign) CATransform3D originalTransform;

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
    if (!whitespaceSet) {
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
        self.pendingScaleParams = nil;
        self.pendingTransformMatrixParams = nil;
        self.pendingTranslateParams = nil;
        self.pendingRotateParams = nil;
        self.originalTransform = CATransform3DIdentity;
        _initView = false;
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
        if (strongSelf) {
            return RunOnMainSync(^NSString *{
                return [strongSelf registerPlatformView:param];
            });
        } else {
            NSLog(@"AcePlatformView: registerPlatformView fail");
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
        if (strongSelf) {
            return RunOnMainSync(^NSString *{
                return [strongSelf updatelayout:param];
            });
        } else {
            NSLog(@"AcePlatformView: updatelayout fail");
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
        if (strongSelf) {
            return RunOnMainSync(^NSString *{
                return [strongSelf exchangeBind:param];
            });
        } else {
            NSLog(@"AcePlatformView: exchangeBind fail");
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
        if (strongSelf) {
            return RunOnMainSync(^NSString *{
                return [strongSelf platformViewType:param];
            });
        } else {
            NSLog(@"AcePlatformView: platformViewType fail");
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
        if (strongSelf) {
            return RunOnMainSync(^NSString *{
                return [strongSelf setRotation:param];
            });
        } else {
            NSLog(@"AcePlatformView: exchangeBind fail");
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
        if (strongSelf) {
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
        if (strongSelf) {
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
        if (strongSelf) {
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
    if (!value || value == [NSNull null] || !targetView) {
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
    if (!targetView || !self.pendingScaleParams) {
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
    if (!targetView || !self.pendingTransformMatrixParams) {
        return;
    }
    for (int i = 0; i < 16; i++) {
        NSString *key = [NSString stringWithFormat:@"m%d", i];
        if (!self.pendingTransformMatrixParams[key]) {
            NSLog(@"AcePlatformView: Transform matrix parameter m%d missing", i);
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
    if (!targetView) {
        return;
    }
    [self applyScaleToTargetView:targetView];
    [self applyTranslateToTargetView:targetView];
    [self applyTransformMatrixToTargetView:targetView];
}

- (void)applyTranslateToTargetView:(UIView *)targetView
{
    if (!targetView || !self.pendingTranslateParams) {
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
    if (!targetView || !self.pendingRotateParams) {
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
    if (!params) {
        return FAIL;
    }
    self.pendingRotateParams = params;
    return SUCCESS;
}

- (NSString *)setScale:(NSDictionary *)params
{
    if (!params) {
        return FAIL;
    }
    self.pendingScaleParams = params;
    return SUCCESS;
}

- (NSString *)setTranslate:(NSDictionary *)params
{
    if (!params) {
        return FAIL;
    }
    self.pendingTranslateParams = params;
    return SUCCESS;
}

- (NSString *)setTransformMatrix:(NSDictionary *)params
{
    UIView* targetView = [self getPlatformView];
    if (!targetView) {
        return FAIL;
    }
    self.pendingTransformMatrixParams = params;
    return SUCCESS;
}

- (void)setPlatformView:(NSObject<IPlatformView>*)platformView
{
    self.curPlatformView = platformView;
    UIView *view = [platformView view];
   if (view && view.superview) {
       self.originalTransform = view.layer.transform;
   }
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
    UIView* platformView = [self getPlatformView];
    if (params[KEY_TEXTUREID] == nil) {
        [self initWithSurfaceView:platformView];
        return SUCCESS;
    }
    self.textureResourceId = [params[KEY_TEXTUREID] longLongValue];
    [self initPlatformView];
    if (!_isVideo) {
        [self.delegate registerContextPtrWithInstanceId:self.instanceId textureId: self.textureResourceId
            contextPtr: (void*)&_eglContextPtr];
    }
    if (!self.renderTexture) {
        AceTexture *newTexture = (AceTexture*)[AceTextureHolder getTextureWithId:self.textureResourceId
            inceId:self.instanceId];
        self.renderTexture = newTexture;
    }
    _renderView = [[RenderView alloc] initWithFrame:CGRectZero];
    if (_isVideo && _player) {
        [_player.currentItem addOutput:self.renderTexture.videoOutput];
        [self initWithEmbeddedView:platformView];
        [self initRenderTexture];
    } else {
        __weak __typeof(&*self) weakSelf = self;
        self.attachCallbackHandler = ^(int32_t textureName){
            if (weakSelf) {
                [weakSelf textureAttach:textureName];
            }
        };
        [self.renderTexture addAttachEventCallback:self.attachCallbackHandler];
        [self initRenderTexture];
    }
    return SUCCESS;
}

- (void)textureAttach:(int32_t)textureName
{
    dispatch_main_async_safe(^{
        NSObject<IPlatformView>* embeddedView = self.curPlatformView;
        if (!embeddedView) {
            NSLog(@"AcePlatformView: registerPlatformView failed: platformView is null");
            return;
        }
        [_renderView setTextureName:textureName];
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
        UIView* platformView = [self getPlatformView];
        platformView.layer.transform = self.originalTransform;
        self.frameWidth = [params[PLATFORMVIEW_WIDTH] floatValue];
        self.frameHeight = [params[PLATFORMVIEW_HEIGHT] floatValue];
        self.frameTop = [params[PLATFORMVIEW_TOP] floatValue];
        self.frameLeft = [params[PLATFORMVIEW_LEFT] floatValue];

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
            if (_isVideo) {
                _playerLayer.frame = platformView.bounds;
            }
        }
        [self applyPendingTransformations:platformView];
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

- (CGFloat)getDefaultCameraDistanceForView:(UIView *)view
{
    CGFloat widthPx = view ? (CGRectGetWidth(view.bounds) * self.screenScale) : 0.0f;
    CGFloat heightPx = view ? (CGRectGetHeight(view.bounds) * self.screenScale) : 0.0f;
    CGFloat zOffsetPx = sqrt(widthPx * widthPx + heightPx * heightPx) / 2.0f;
    CGFloat distancePx = PLATFORMVIEW_DEFAULT_CAMERA_DISTANCE_PX + zOffsetPx;
    CGFloat distancePt = distancePx / self.screenScale;
    return distancePt > FLT_EPSILON ? distancePt : 1.0f;
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

- (void)initWithSurfaceView:(UIView*)surfaceView {
    StageViewController* controller = [StageApplication getApplicationTopViewController];
    surfaceView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
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
