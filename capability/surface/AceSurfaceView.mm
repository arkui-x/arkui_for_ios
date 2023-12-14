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

#import "AceSurfaceHolder.h"
#import "AceSurfaceView.h"
#import "WindowView.h"

@interface AceSurfaceView () {
    float _surfaceLeft;
    float _surfaceTop;
    float _surfaceWidth;
    float _surfaceHeight;
    BOOL _viewAdded;
}
@property (nonatomic, assign) int64_t incId;
@property (nonatomic, assign) int32_t instanceId;
@property (nonatomic, copy) IAceOnResourceEvent callback;
@property (nonatomic, strong) NSMutableDictionary<NSString*, IAceOnCallSyncResourceMethod>* callMethodMap;
@property (nonatomic, weak) UIViewController* target;
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

+ (Class)layerClass
{
    return [AVPlayerLayer class];
}

- (AVPlayerLayer *)playerLayer
{
    return (AVPlayerLayer *)self.layer;
}

- (instancetype)initWithId:(int64_t)incId callback:(IAceOnResourceEvent)callback
    param:(NSDictionary*)initParam superTarget:(id)target abilityInstanceId:(int32_t)abilityInstanceId
{
    if (self = [super init]) {
        NSLog(@"AceSurfaceView: init initParam: %@  incId: %lld",initParam,incId);
        self.incId = incId;
        self.instanceId = abilityInstanceId;
        self.callback = callback;
        self.callMethodMap = [[NSMutableDictionary alloc] init];
        self.target = target;
        self.autoresizesSubviews = YES;
        self.backgroundColor = UIColor.blackColor;
        [self layerCreate];

        __weak AceSurfaceView* weakSelf = self;
        IAceOnCallSyncResourceMethod callSetSurfaceSize = ^NSString*(NSDictionary* param) {
            NSLog(@"AceSurfaceView: setSurfaceBounds");
            if (weakSelf) {
                return [weakSelf setSurfaceBounds:param];
            }else {
                 NSLog(@"AceSurfaceView: setSurfaceBounds fail");
                 return FAIL;
            }
           
        };
        [self.callMethodMap setObject:[callSetSurfaceSize copy] forKey:[self method_hashFormat:@"setSurfaceBounds"]];
    }
    return self;
}

- (void)callSurfaceChange:(CGRect)oldRect
{
    if (self.playerLayer) {
        CGRect newRect = self.playerLayer.frame;
        if (oldRect.origin.x != newRect.origin.x
            || oldRect.origin.y != newRect.origin.y
            || oldRect.size.width != newRect.size.width
            || oldRect.size.height != newRect.size.height){
            CGFloat width = newRect.size.width;
            CGFloat height = newRect.size.height;
            NSString * param = [NSString stringWithFormat:@"surfaceWidth=%f&surfaceHeight=%f",width,height];
            NSLog(@"AceSurfaceView callSurfaceChange (%f, %f) - (%f x %f) ", 
                newRect.origin.x, newRect.origin.y, newRect.size.width, newRect.size.height);
            [self fireCallback:@"onChanged" params:param];
        }
    }
}

- (void)layerCreate
{
    self.playerLayer.backgroundColor = UIColor.blackColor.CGColor;
    self.playerLayer.hidden = true;
    NSMutableDictionary *newActions = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSNull null], @"bounds", [NSNull null], @"position", nil];
    self.playerLayer.actions = newActions;
    self.playerLayer.videoGravity = AVLayerVideoGravityResize;
    [AceSurfaceHolder addLayer:self withId:self.incId inceId:self.instanceId];
    NSLog(@"AceSurfaceView Surface Created");

    UIViewController* superViewController = (UIViewController*)self.target;
    WindowView *windowView = (WindowView *)[self findWindowViewInView:superViewController.view];
    [superViewController.view addSubview:self];
    superViewController.view.backgroundColor = UIColor.blackColor;
    self.hidden = true;
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
        UIScreen *screen = [UIScreen mainScreen];
        CGFloat scale = screen.scale;

        _surfaceLeft = [params[SURFACE_LEFT_KEY] floatValue] / scale;
        _surfaceTop = [params[SURFACE_TOP_KEY] floatValue] / scale;
        _surfaceWidth = [params[SURFACE_WIDTH_KEY] floatValue] / scale;
        _surfaceHeight = [params[SURFACE_HEIGHT_KEY] floatValue] / scale;
        
        NSLog(@"AceSurfaceView setSurfaceBounds (%f, %f) - (%f x %f) ", 
            _surfaceLeft, _surfaceTop, _surfaceWidth, _surfaceHeight);
        
        CGRect oldRect = self.frame;
        self.frame = CGRectMake(_surfaceLeft, _surfaceTop, _surfaceWidth, _surfaceHeight);
        [self callSurfaceChange:oldRect];
       
        if (_viewAdded) {
            [self layoutIfNeeded];
        } else {
            _viewAdded = YES;
            self.hidden = false;
            UIViewController* superViewController = (UIViewController*)self.target;
            self.frame = superViewController.view.bounds;
            self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            WindowView *windowView = (WindowView *)[self findWindowViewInView:superViewController.view];
            [superViewController.view bringSubviewToFront:windowView];
            [self performSelector:@selector(delaySetClearColor:) withObject:windowView afterDelay:0.5f];
        }
    } @catch (NSException* exception) {
        NSLog(@"AceSurfaceView NumberFormatException, setSurfaceSize failed");
        return FAIL;
    }
    return SUCCESS;
}

- (void)delaySetClearColor:(UIView *)view
{
    if (view) {
        view.backgroundColor = UIColor.clearColor;
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

- (AVPlayerLayer*)getSurface
{
    return self.playerLayer;
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

- (void)releaseObject
{
    @try {
        NSLog(@"AceSurfaceView releaseObject");
        if (_viewAdded) {
            _viewAdded = false;
        }
        if (self.playerLayer) {
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
