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
@property (nonatomic, strong) AVPlayerLayer* playerLayer;
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

        __weak __typeof(&*self) weakSelf = self;
        IAceOnCallSyncResourceMethod callSetSurfaceSize = ^NSString*(NSDictionary* param) {
            NSLog(@"AceSurfaceView: setSurfaceBounds");
            return [weakSelf setSurfaceBounds:param];
        };
        [self.callMethodMap setObject:callSetSurfaceSize forKey: [self method_hashFormat:@"setSurfaceBounds"]];
    }
    return self;
}

- (void)callSurfaceChange:(CGRect)oldRect
{
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

- (void)layerCreate
{
    AVPlayerLayer * playerLayer = [[AVPlayerLayer alloc] init];
    playerLayer.backgroundColor = UIColor.blackColor.CGColor;
    playerLayer.hidden = true;
    NSMutableDictionary *newActions = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSNull null], @"bounds", [NSNull null], @"position", nil];
    playerLayer.actions = newActions;
    // playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.playerLayer = playerLayer;
    if (self.playerLayer) {
        [AceSurfaceHolder addLayer:self.playerLayer  withId:self.incId inceId:self.instanceId]; 
    }
    NSLog(@"AceSurfaceView Surface Created");
}

- (NSDictionary<NSString*, IAceOnCallSyncResourceMethod>*)getCallMethod
{
    return self.callMethodMap;
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
        
        CGRect oldRect = self.playerLayer.frame;
        ///Remove animation
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.playerLayer.frame = CGRectMake(_surfaceLeft, _surfaceTop, _surfaceWidth, _surfaceHeight);
        [CATransaction commit];
        [self callSurfaceChange:oldRect];
       
        if (_viewAdded) {
            [self layoutIfNeeded];
        } else {
            _viewAdded = YES;
            NSLog(@"AceSurfaceView AceSurfaceView added");
            UIViewController* superViewController = (UIViewController*)self.target;
            self.frame = superViewController.view.bounds;
            self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            WindowView *windowView = (WindowView *)[self findWindowViewInView:superViewController.view];
            [superViewController.view addSubview:self];
            [superViewController.view bringSubviewToFront:windowView];
            [self.layer addSublayer:self.playerLayer];
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

- (void)releaseObject
{
    if (_viewAdded) {
        NSLog(@"AceSurfaceView Surface removed");
        [self removeFromSuperview];
        _viewAdded = false;
    }
}

- (void)dealloc
{
    if (self.playerLayer) {
        [self.playerLayer removeFromSuperlayer];
        self.playerLayer = nil;
        [AceSurfaceHolder removeLayerWithId:self.incId inceId:self.instanceId];
    }
    self.callback = nil;
    self.callMethodMap = nil;
    NSLog(@"AceSurfaceView->%@ dealloc", self);
    //    [super dealloc];
}

@end