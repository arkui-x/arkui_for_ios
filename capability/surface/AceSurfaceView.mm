/*
 * Copyright (c) 2023-2025 Huawei Device Co., Ltd.
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

#import "AceSurfaceView.h"

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#import "AceSurfaceHolder.h"
#import "WindowView.h"
#import "StageViewController.h"
@interface AceSurfaceView (){
    BOOL _viewAdded;
    BOOL _isLock;
    CGRect _currentFrame;
    UIInterfaceOrientation  _initialOrientation;

}
@property (nonatomic, assign) int64_t incId;
@property (nonatomic, assign) int32_t instanceId;
@property (nonatomic, copy) IAceOnResourceEvent callback;
@property (nonatomic, strong) NSMutableDictionary<NSString*, IAceOnCallSyncResourceMethod>* callMethodMap;
@property (nonatomic, weak) UIViewController* target;
@property (nonatomic, weak) id<IAceSurface> surfeceDelegate;
@end

@implementation AceSurfaceView

#define SUCCESS @"success"
#define FAIL @"false"

#define PARAM_EQUALS @"#HWJS-=-#"
#define PARAM_BEGIN @"#HWJS-?-#"
#define METHOD @"method"
#define EVENT @"event"
#define SURFACE_FLAG @"surface@"

#define SURFACE_LEFT_KEY @"surfaceLeft"
#define SURFACE_TOP_KEY @"surfaceTop"
#define SURFACE_WIDTH_KEY @"surfaceWidth"
#define SURFACE_HEIGHT_KEY @"surfaceHeight"
#define SURFACE_SET_BOUNDS @"setSurfaceBounds"
#define IS_LOCK @"isLock"

+ (Class)layerClass {
    return [CALayer class];
}

- (instancetype)initWithId:(int64_t)incId callback:(IAceOnResourceEvent)callback
    param:(NSDictionary*)initParam superTarget:(id)target abilityInstanceId:(int32_t)abilityInstanceId
    delegate:(id<IAceSurface>)delegate
{
    if (self = [super init]) {
        NSLog(@"AceSurfaceView: init initParam: %@  incId: %lld",initParam,incId);
        self.incId = incId;
        self.instanceId = abilityInstanceId;
        self.callback = callback;
        self.callMethodMap = [[NSMutableDictionary alloc] init];
        self.target = target;
        self.surfeceDelegate = delegate;
        self.autoresizesSubviews = YES;

        [self layerCreate];

        __weak AceSurfaceView* weakSelf = self;
        IAceOnCallSyncResourceMethod callSetSurfaceSize = ^NSString*(NSDictionary* param) {
            if (weakSelf) {
                return [weakSelf setSurfaceBounds:param];
            } else {
                 NSLog(@"AceSurfaceView: setSurfaceBounds fail");
                 return FAIL;
            }
           
        };
        [self.callMethodMap setObject:[callSetSurfaceSize copy] forKey:[self method_hashFormat:@"setSurfaceBounds"]];

        IAceOnCallSyncResourceMethod callAttachNativeWindow = ^NSString*(NSDictionary* param) {
            if (weakSelf) {
                return [weakSelf setAttachNativeWindow:param];
            } else {
                 NSLog(@"AceSurfaceView: callAttachNativeWindow fail");
                 return FAIL;
            }
        };
        [self.callMethodMap setObject:[callAttachNativeWindow copy] forKey:[self method_hashFormat:@"attachNativeWindow"]];

        IAceOnCallSyncResourceMethod callSetSurfaceRotation = ^NSString*(NSDictionary* param) {
            if (weakSelf) {
                return [weakSelf setSurfaceRotation:param];
            } else {
                 NSLog(@"AceSurfaceView: callSetSurfaceRotation fail");
                 return FAIL;
            }
        };
        [self.callMethodMap setObject:[callSetSurfaceRotation copy] forKey:[self method_hashFormat:@"setSurfaceRotation"]];

        IAceOnCallSyncResourceMethod callsetSurfaceRect = ^NSString*(NSDictionary* param) {
            if (weakSelf) {
                return [weakSelf setSurfaceRect:param];
            } else {
                 NSLog(@"AceSurfaceView: callsetSurfaceRect fail");
                 return FAIL;
            }
        };
        [self.callMethodMap setObject:[callsetSurfaceRect copy] forKey:[self method_hashFormat:@"setSurfaceRect"]];
    }
    return self;
}

- (void)callSurfaceChange:(CGRect)surfaceRect
{
    UIScreen *screen = [UIScreen mainScreen];
    CGFloat scale = screen.scale;

    CGRect newRect = CGRectMake(surfaceRect.origin.x/scale,
        surfaceRect.origin.y/scale, surfaceRect.size.width/scale, surfaceRect.size.height/scale);
    self.frame = newRect;
    if (self.layer) {
        if (_currentFrame.origin.x != surfaceRect.origin.x
            || _currentFrame.origin.y != surfaceRect.origin.y
            || _currentFrame.size.width != surfaceRect.size.width
            || _currentFrame.size.height != surfaceRect.size.height){
            self.frame = newRect;
            _currentFrame = surfaceRect;
            NSString * param = [NSString stringWithFormat:@"surfaceWidth=%f&surfaceHeight=%f",
                surfaceRect.size.width, surfaceRect.size.height];
            [self fireCallback:@"onChanged" params:param];
        }
    }
}

- (void)layerCreate
{
    [AceSurfaceHolder addLayer:self.layer withId:self.incId inceId:self.instanceId];
    [self bringSubviewToFront];
}

- (NSDictionary<NSString*, IAceOnCallSyncResourceMethod>*)getCallMethod
{
    return [self.callMethodMap copy];
}

- (NSString*)setSurfaceBounds:(NSDictionary*)params
{
    if (!params[SURFACE_WIDTH_KEY] || !params[SURFACE_HEIGHT_KEY]) {
        return FAIL;
    }
    @try {
        CGFloat surface_x = [params[SURFACE_LEFT_KEY] floatValue];
        CGFloat surface_y = [params[SURFACE_TOP_KEY] floatValue];
        CGFloat surface_width = [params[SURFACE_WIDTH_KEY] floatValue];
        CGFloat surface_height = [params[SURFACE_HEIGHT_KEY] floatValue];
        CGRect surfaceRect = CGRectMake(surface_x, surface_y, surface_width, surface_height);

        if (_viewAdded) {
            [self callSurfaceChange:surfaceRect];
            [self layoutIfNeeded];
        } else {
            _viewAdded = YES;
            UIViewController* superViewController = (UIViewController*)self.target;
            self.frame = superViewController.view.bounds;
            self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self callSurfaceChange:surfaceRect];
            [self bringSubviewToFront];
            
        }
    } @catch (NSException* exception) {
        NSLog(@"AceSurfaceView NumberFormatException, setSurfaceSize failed");
        return FAIL;
    }
    return SUCCESS;
}

- (NSString*)setAttachNativeWindow:(NSDictionary*)params
{
    if (!self.surfeceDelegate) {
        NSLog(@"AceSurfaceView IAceSurface is null");
        return FAIL;
    }
    if (![self.surfeceDelegate respondsToSelector:@selector(attachNaitveSurface:)]) {
        NSLog(@"AceSurfaceView IAceSurface attachNaitveSurface null");
        return FAIL;
    }
    uintptr_t nativeWindow = [self.surfeceDelegate attachNaitveSurface:self.layer];
    if (nativeWindow == 0) {
        NSLog(@"AceSurfaceView Surface nativeWindow: null");
        return FAIL;
    }
    NSDictionary * param = @{@"nativeWindow": [NSString stringWithFormat:@"%ld",(long)nativeWindow]};
    return [self convertMapToString:param];
}

- (NSString*)setSurfaceRotation:(NSDictionary*)params
{
    if (!params[IS_LOCK]) {
        return FAIL;
    }
    _isLock = [params[IS_LOCK] boolValue];
    _initialOrientation = [UIApplication sharedApplication].statusBarOrientation;
    return SUCCESS;
}

- (NSString*)setSurfaceRect:(NSDictionary*)params
{
    if (!params[SURFACE_WIDTH_KEY] || !params[SURFACE_HEIGHT_KEY]) {
        return FAIL;
    }
    @try {
        UIScreen *screen = [UIScreen mainScreen];
        CGFloat scale = screen.scale;
        CGFloat x = [params[SURFACE_LEFT_KEY] floatValue];
        CGFloat y = [params[SURFACE_TOP_KEY] floatValue];
        CGFloat width = [params[SURFACE_WIDTH_KEY] floatValue];
        CGFloat height = [params[SURFACE_HEIGHT_KEY] floatValue];
        CGRect surfaceRect = CGRectMake(x / scale, y / scale, width / scale, height / scale);
        CALayer *sublayer = [self.layer.sublayers firstObject];
        if (sublayer) {
            sublayer.frame = surfaceRect;
        }
    } @catch (NSException* exception) {
        NSLog(@"AceSurfaceView NumberFormatException, setSurfaceSize failed");
        return FAIL;
    }
    return SUCCESS;
}

- (UIView *)findWindowViewInView:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[WindowView class]]) {
            return subview;
        } 
    }
    return nil;
}

- (void)orientationDidChange {
    if (_isLock == false) {
        return;
    }
    UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
    CATransform3D rotationTransform = CATransform3DIdentity;
    switch (_initialOrientation) {
        case UIInterfaceOrientationPortrait:
            if (currentOrientation == UIInterfaceOrientationLandscapeLeft) {
                rotationTransform = CATransform3DMakeRotation(M_PI_2, 0, 0, 1);
            } else if (currentOrientation == UIInterfaceOrientationLandscapeRight) {
                rotationTransform = CATransform3DMakeRotation(-M_PI_2, 0, 0, 1);
            }
            else if (currentOrientation == UIInterfaceOrientationPortraitUpsideDown) {
                rotationTransform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
            }
            break;
        case UIInterfaceOrientationLandscapeLeft:
            if (currentOrientation == UIInterfaceOrientationPortrait) {
                rotationTransform = CATransform3DMakeRotation(-M_PI_2, 0, 0, 1);
            } else if (currentOrientation == UIInterfaceOrientationLandscapeRight) {
                rotationTransform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
            } else if (currentOrientation == UIInterfaceOrientationPortraitUpsideDown) {
                rotationTransform = CATransform3DMakeRotation(M_PI_2, 0, 0, 1);
            }
            break;
        case UIInterfaceOrientationLandscapeRight:
            if (currentOrientation == UIInterfaceOrientationPortrait) {
                rotationTransform = CATransform3DMakeRotation(M_PI_2, 0, 0, 1);
            } else if (currentOrientation == UIInterfaceOrientationLandscapeLeft) {
                rotationTransform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
            } else if (currentOrientation == UIInterfaceOrientationPortraitUpsideDown) {
                rotationTransform = CATransform3DMakeRotation(-M_PI_2, 0, 0, 1);
            }
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            if (currentOrientation == UIInterfaceOrientationPortrait) {
                rotationTransform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
            } else if (currentOrientation == UIInterfaceOrientationLandscapeLeft) {
                rotationTransform = CATransform3DMakeRotation(-M_PI_2, 0, 0, 1);
            } else if (currentOrientation == UIInterfaceOrientationLandscapeRight) {
                rotationTransform = CATransform3DMakeRotation(M_PI_2, 0, 0, 1);
            }
            break;
        default:
            break;
    }
    CALayer *sublayer = [self.layer.sublayers firstObject];
    if (sublayer) {
        sublayer.transform = rotationTransform;
    }
}

#pragma mark - fireCallback

- (void)fireCallback:(NSString *)method params:(NSString *)params
{
    NSString *method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", 
        SURFACE_FLAG, self.incId, EVENT, PARAM_EQUALS, method, PARAM_BEGIN];
    if (self.callback) {
        self.callback(method_hash, params);
    }
}

- (NSString *)method_hashFormat:(NSString *)method
{
    return [NSString stringWithFormat:@"%@%lld%@%@%@%@", SURFACE_FLAG, self.incId, METHOD, PARAM_EQUALS, method, PARAM_BEGIN];
}

- (long)getResId
{
    return self.incId;
}

- (void)bringSubviewToFront
{
    if (self.target){
        StageViewController* superViewController = (StageViewController*)self.target;
        if (!superViewController){
            return;
        }
        UIView *windowView = [superViewController getWindowView];
        if (!windowView){
            return;
        }
        [windowView.superview insertSubview:self belowSubview:windowView];
    }
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

- (void)releaseObject
{
    @try {
        NSLog(@"AceSurfaceView releaseObject");
        if (_viewAdded) {
            _viewAdded = false;
        }
        if (self.layer) {
            [AceSurfaceHolder removeLayerWithId:self.incId inceId:self.instanceId];
        }

        if (self.callMethodMap) {
            for (id key in self.callMethodMap) {
                IAceOnCallSyncResourceMethod block = [self.callMethodMap objectForKey:key];
                block = nil;
            }
            [self.callMethodMap removeAllObjects];
            self.callMethodMap = nil;
        }
        self.callback = nil;
        
    } @catch (NSException* exception) {
        NSLog(@"AceSurfaceView releaseObject failed");
    }
}

- (void)dealloc
{
    NSLog(@"AceSurfaceView->%@ dealloc", self);
}

@end
