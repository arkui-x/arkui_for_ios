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

#import "AcePlatformView.h"
#include <sys/_types/_int32_t.h>
#include <objc/NSObjCRuntime.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#include <vector>
#import "AceTextureHolder.h"
#include "StageViewController.h"
#import "StageApplication.h"
#import "WindowView.h"

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

@property(nonatomic, assign) CGFloat frameWidth;
@property(nonatomic, assign) CGFloat frameHeight;
@property(nonatomic, assign) CGFloat frameTop;
@property(nonatomic, assign) CGFloat frameLeft;
@property(nonatomic, assign) CGFloat screenScale;

@property (nonatomic) CVPixelBufferRef textureBufferRef1;
@property (nonatomic) CVPixelBufferRef textureBufferRef2;
@property (nonatomic) CVPixelBufferRef textureBufferRef3;
@property (nonatomic, assign) BOOL bufferReady;
@property (nonatomic, assign) NSInteger index;
@end

@implementation AcePlatformView
{
    std::vector<CVPixelBufferRef*> bufferArray_;
    NSLock *lock_;
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
        lock_ = [[NSLock alloc]init];

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
}

- (void)setPlatformView:(NSObject<IPlatformView>*)platformView
{
    self.curPlatformView = platformView;
}

- (NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *)getSyncCallMethod
{
    return self.callSyncMethodMap;
}

- (NSString *)registerPlatformView:(NSDictionary *)params
{
    if (!params) {
        NSLog(@"AcePlatformView: registerPlatformView failed: params is null");
        return FAIL;
    }
    [self initPlatformView];
    self.textureResourceId = [params[KEY_TEXTUREID] longLongValue];
    // register PixelBuffer to rosen 
    [self.delegate registerBufferWithInstanceId:self.instanceId textureId: self.textureResourceId
        texturePixelBuffer:(void*)[self getPixelBuffer]];

    NSObject<IPlatformView>* embeddedView = self.curPlatformView;
    if (!embeddedView) {
        NSLog(@"AcePlatformView: registerPlatformView failed: platformView is null");
        return FAIL;
    }

    UIView* platformView = [embeddedView view];
    
    [self initWithEmbeddedView:platformView];
    
    if (!self.renderTexture) {
        AceTexture *newTexture = (AceTexture*)[AceTextureHolder getTextureWithId:self.textureResourceId
            inceId:self.instanceId];
        self.renderTexture = newTexture;
    }
    [self platformViewReady];
    return SUCCESS;
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
            [self initPixelBuffer];
        }

        CGRect tempFrame = platformView.frame;

        tempFrame.origin.x = self.frameLeft / self.screenScale;
        tempFrame.origin.y = self.frameTop / self.screenScale;
        tempFrame.size.height = self.frameHeight / self.screenScale;
        tempFrame.size.width = self.frameWidth / self.screenScale;

        platformView.frame = tempFrame;
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

- (void)initPixelBuffer
{
    [lock_ lock];
    NSDictionary *options = @{(NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES,
                              (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,
                              (NSString*)kCVPixelBufferIOSurfacePropertiesKey: [NSDictionary dictionary]};
    if (self->_textureBufferRef1) {
        CFRelease(self->_textureBufferRef1);
        self->_textureBufferRef1 = nullptr;
    }
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          self.frameWidth,
                                          self.frameHeight,
                                          kCVPixelFormatType_32BGRA,
                                          (__bridge CFDictionaryRef) options,
                                          &self->_textureBufferRef1);
    if (status != kCVReturnSuccess || self.textureBufferRef1 == nil) {
        self.bufferReady = NO;
        self.textureOutput = nullptr;
        NSLog(@"AcePlatformView: initPixelBuffer failed");
        return;
    }
    if (self->_textureBufferRef2) {
        CFRelease(self->_textureBufferRef2);
        self->_textureBufferRef2 = nullptr;
    }
    status = CVPixelBufferCreate(kCFAllocatorDefault,
                                self.frameWidth,
                                self.frameHeight,
                                kCVPixelFormatType_32BGRA,
                                (__bridge CFDictionaryRef) options,
                                &self->_textureBufferRef2);
    if (status != kCVReturnSuccess || self.textureBufferRef2 == nil) {
        self.bufferReady = NO;
        self.textureOutput = nullptr;
        NSLog(@"AcePlatformView: initPixelBuffer failed");
        return;
    }
    if (self->_textureBufferRef3) {
        CFRelease(self->_textureBufferRef3);
        self->_textureBufferRef3 = nullptr;
    }
    status = CVPixelBufferCreate(kCFAllocatorDefault,
                                self.frameWidth,
                                self.frameHeight,
                                kCVPixelFormatType_32BGRA,
                                (__bridge CFDictionaryRef) options,
                                &self->_textureBufferRef3);
    if (status != kCVReturnSuccess || self.textureBufferRef3 == nil) {
        self.bufferReady = NO;
        self.textureOutput = nullptr;
        NSLog(@"AcePlatformView: initPixelBuffer failed");
        return;
    }
    if (self.bufferReady != true) {
        bufferArray_.emplace_back(&self->_textureBufferRef1);
        bufferArray_.emplace_back(&self->_textureBufferRef2);
        bufferArray_.emplace_back(&self->_textureBufferRef3);
        self.bufferReady = true;
    }
  self.textureOutput = nullptr;
  [lock_ unlock];
}

- (CVPixelBufferRef _Nullable)copyPixelBuffer
{
    if (!self.bufferReady) {
        return nullptr;
    }
    NSObject<IPlatformView>* embeddedView = self.curPlatformView;
    if (!embeddedView) {
        NSLog(@"AcePlatformView: register failed: platformView is null");
        return nil;
    }

    UIView* platformView = [embeddedView view];
    [lock_ lock];
    CVPixelBufferRef outputRef = *bufferArray_[self.index];
    if (!outputRef) {
        NSLog(@"AcePlatformView: textureOutput is null.");
        [lock_ unlock];
        return nullptr;
    }
    self.index  = (self.index + 1) % QueueSize;
    CFRetain(outputRef);
    CVPixelBufferLockBaseAddress(outputRef, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(outputRef);
    
    if(pxdata != nil){
        CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
        NSUInteger bytesPerRow = CVPixelBufferGetBytesPerRow(outputRef);
        CGContextRef context = CGBitmapContextCreate(pxdata, self.frameWidth, self.frameHeight, 8, 
                            bytesPerRow, rgbColorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);

        if(context){
            CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
            CGAffineTransform flipVertical = CGAffineTransformMake( 1, 0, 0, -1, 0, self.frameHeight);
            CGContextConcatCTM(context, flipVertical);
            CGContextScaleCTM(context, [UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
            UIGraphicsPushContext(context); 
            [platformView.layer renderInContext:context];
            UIGraphicsPopContext();

            CGColorSpaceRelease(rgbColorSpace);
            CGContextRelease(context);
        }
    }
    CVPixelBufferUnlockBaseAddress(outputRef, 0);
    CFRelease(outputRef);
    self.textureOutput = outputRef;
    [lock_ unlock];
    return self.textureOutput;
}

- (CADisplayLink *)displayLink
{
    if (!_displayLink) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkDidrefresh)];
        // auto preferredFPS = _displayLink.preferredFramesPerSecond;
        auto mainMaxFrameRate = [UIScreen mainScreen].maximumFramesPerSecond;
        double maxFrameRate = fmin(mainMaxFrameRate / 2, 30);
        double minFrameRate = fmin(mainMaxFrameRate / 2, 10);
        if(@available(iOS 15.0,*)){
            _displayLink.preferredFrameRateRange = CAFrameRateRangeMake(minFrameRate,maxFrameRate,maxFrameRate);
        } else{
            _displayLink.preferredFramesPerSecond = 30;
        }
        
    }
    return _displayLink;
}

- (void)displayLinkDidrefresh
{
    [self copyPixelBuffer];
    if (self.displayLink) {
        [self refreshPixelBuffer];
    }
}

- (void)refreshPixelBuffer
{
    if (self.renderTexture) {
        [self.renderTexture refreshPixelBuffer];
    }
}

- (void*)getPixelBuffer
{
    return &self->_textureOutput;
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
    NSLog(@"AcePlatformView releaseObject");
    if (self.textureOutput) {
        self.textureOutput = nil;
    }
    if (self.displayLink) {
        [self.displayLink invalidate];
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

    NSObject<IPlatformView>* embeddedView = self.curPlatformView;
    if (!embeddedView) {
        NSLog(@"AcePlatformView: releaseObject failed: platformView is null");
        return;
    }
    [[embeddedView view] removeFromSuperview];
    [embeddedView onDispose];
}

- (void)dealloc
{
    NSLog(@"AcePlatformView->%@ dealloc", self);
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
    StageViewController* controller = [StageApplication getApplicationTopViewController];
    embeddedView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    [controller.view addSubview: embeddedView];
    WindowView *windowView = (WindowView *) [self findWindowViewInView: controller.view];
    [controller.view bringSubviewToFront:windowView];
}

@end
