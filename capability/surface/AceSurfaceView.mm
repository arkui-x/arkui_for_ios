/*
 * Copyright (c) 2023-2024 Huawei Device Co., Ltd.
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

@interface AceSurfaceView (){
    BOOL _viewAdded;
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
    }
    return self;
}

- (void)callSurfaceChange:(CGRect)surfaceRect
{
    UIScreen *screen = [UIScreen mainScreen];
    CGFloat scale = screen.scale;
    
    CGRect oldRect = self.frame;
    CGRect newRect = CGRectMake(surfaceRect.origin.x/scale,
        surfaceRect.origin.y/scale, surfaceRect.size.width/scale, surfaceRect.size.height/scale);
    self.frame = newRect;
    if (self.layer) {
        if (oldRect.origin.x != newRect.origin.x
            || oldRect.origin.y != newRect.origin.y
            || oldRect.size.width != newRect.size.width
            || oldRect.size.height != newRect.size.height){
            self.frame = newRect;
            NSString * param = [NSString stringWithFormat:@"surfaceWidth=%f&surfaceHeight=%f",
                surfaceRect.size.width, surfaceRect.size.height];
            [self fireCallback:@"onChanged" params:param];
        }
    }
}

- (void)layerCreate
{
    [AceSurfaceHolder addLayer:self.layer withId:self.incId inceId:self.instanceId];

    UIViewController* superViewController = (UIViewController*)self.target;
    WindowView *windowView = (WindowView *)[self findWindowViewInView:superViewController.view];
    [superViewController.view addSubview:self];
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
        NSLog(@"AceSurfaceView setSurfaceBounds (%f, %f) - (%f x %f) ", 
            surface_x, surface_y, surface_width, surface_height);
        CGRect surfaceRect = CGRectMake(surface_x, surface_y, surface_width, surface_height);
        [self callSurfaceChange:surfaceRect];
       
        if (_viewAdded) {
            [self layoutIfNeeded];
        } else {
            _viewAdded = YES;
            UIViewController* superViewController = (UIViewController*)self.target;
            self.frame = superViewController.view.bounds;
            self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            WindowView *windowView = (WindowView *)[self findWindowViewInView:superViewController.view];
            [superViewController.view bringSubviewToFront:windowView];
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

- (UIView *)findWindowViewInView:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[WindowView class]]) {
            return subview;
        } 
    }
    return nil;
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
        UIViewController* superViewController = (UIViewController*)self.target;
        if (!superViewController){
            return;
        }
        WindowView *windowView = (WindowView *)[self findWindowViewInView:superViewController.view];
        if (!windowView){
            return;
        }
        [superViewController.view insertSubview:self belowSubview:windowView];
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
