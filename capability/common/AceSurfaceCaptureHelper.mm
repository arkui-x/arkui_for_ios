/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
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

#import "AceSurfaceCaptureHelper.h"

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#include "base/log/log.h"

static NSString* const SURFACE_CAPTURE_SUCCESS = @"success";
static NSString* const SURFACE_CAPTURE_FAILED = @"false";
static NSString* const SURFACE_CAPTURE_NATIVE_BUFFER_KEY = @"nativeBuffer";
static const size_t MAX_CAPTURE_DIMENSION = 4096;
static const size_t MAX_CAPTURE_BUFFER_SIZE = 64 * 1024 * 1024;
static const size_t BYTES_PER_PIXEL = 4;
static const int64_t TIMEOUT_MS = 2000;

@implementation AceSurfaceCaptureConfig

- (instancetype)initWithWidthKey:(NSString*)widthKey
                       heightKey:(NSString*)heightKey
                          logTag:(const char*)logTag
                   hostLayerBlock:(HostLayerBlock)hostLayerBlock
               drawFallbackBlock:(SurfaceFallbackDrawBlock)drawFallbackBlock
{
    self = [super init];
    if (self) {
        _widthKey = [widthKey copy];
        _heightKey = [heightKey copy];
        _logTag = logTag;
        _hostLayerBlock = hostLayerBlock ? [hostLayerBlock copy] : nil;
        _drawFallbackBlock = drawFallbackBlock ? [drawFallbackBlock copy] : nil;
    }
    return self;
}

@end

@interface AceSurfaceCaptureHelper () {
    AceSurfaceCaptureConfig* _config;
    AVAsset* _cachedAsset;
    AVAssetImageGenerator* _cachedImageGenerator;
}

- (AVPlayerLayer*)findPlayerLayer:(CALayer*)hostLayer;
- (CGContextRef)createSurfaceCaptureContext:(void*)buffer
                                     width:(size_t)width
                                    height:(size_t)height
                                colorSpace:(CGColorSpaceRef*)colorSpace;
- (NSString*)drawCurrentVideoFrame:(AVPlayerLayer*)playerLayer bounds:(CGRect)bounds;
- (NSString*)drawSurfaceCaptureContent:(CGContextRef)ctx height:(size_t)height bounds:(CGRect)bounds;
- (NSString*)captureSurfaceOnMainThread:(NSDictionary*)params bounds:(CGRect)bounds;

@end

@implementation AceSurfaceCaptureHelper

- (instancetype)initWithConfig:(AceSurfaceCaptureConfig*)config
{
    self = [super init];
    if (self) {
        _config = config;
    }
    return self;
}

- (NSString*)captureSurface:(NSDictionary*)params bounds:(CGRect)bounds
{
    if ([NSThread isMainThread]) {
        return [self captureSurfaceOnMainThread:params bounds:bounds];
    }

    __block NSString* result = SURFACE_CAPTURE_FAILED;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_main_queue(), ^{
        result = [self captureSurfaceOnMainThread:params bounds:bounds];
        dispatch_semaphore_signal(semaphore);
    });

    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, TIMEOUT_MS * NSEC_PER_MSEC);
    if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
        LOGE("%{public}s: surfaceCapture timeout", _config.logTag);
        return SURFACE_CAPTURE_FAILED;
    }

    return result;
}

- (AVPlayerLayer*)findPlayerLayer:(CALayer*)hostLayer
{
    for (CALayer* sublayer in hostLayer.sublayers) {
        if ([sublayer isKindOfClass:[AVPlayerLayer class]]) {
            return (AVPlayerLayer*)sublayer;
        }
    }
    return nil;
}

- (CGContextRef)createSurfaceCaptureContext:(void*)buffer
                                     width:(size_t)width
                                    height:(size_t)height
                                colorSpace:(CGColorSpaceRef*)colorSpace
{
    *colorSpace = CGColorSpaceCreateDeviceRGB();
    if (!*colorSpace) {
        LOGE("%{public}s: failed to create color space", _config.logTag);
        return nullptr;
    }

    size_t bytesPerRow = width * 4;
    CGContextRef ctx = CGBitmapContextCreate(buffer, width, height, 8, bytesPerRow, *colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    if (!ctx) {
        CGColorSpaceRelease(*colorSpace);
        *colorSpace = nullptr;
    }
    return ctx;
}

- (NSString*)drawCurrentVideoFrame:(AVPlayerLayer*)playerLayer bounds:(CGRect)bounds
{
    AVAsset* asset = playerLayer.player.currentItem.asset;
    if (!asset) {
        LOGE("%{public}s: video asset is nil", _config.logTag);
        return SURFACE_CAPTURE_FAILED;
    }

    if (_cachedAsset != asset) {
        _cachedAsset = asset;
        _cachedImageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        _cachedImageGenerator.appliesPreferredTrackTransform = YES;
    }

    CMTime currentTime = playerLayer.player.currentTime;
    NSError* error = nil;
    CGImageRef cgImage = [_cachedImageGenerator copyCGImageAtTime:currentTime actualTime:NULL error:&error];
    if (!cgImage) {
        NSString* errorMessage = error ? error.localizedDescription : @"unknown error";
        LOGE("%{public}s: extract video frame failed: %{public}s", _config.logTag, errorMessage.UTF8String);
        return SURFACE_CAPTURE_FAILED;
    }

    UIImage* videoFrame = [UIImage imageWithCGImage:cgImage];
    [videoFrame drawInRect:bounds];
    CGImageRelease(cgImage);
    return SURFACE_CAPTURE_SUCCESS;
}

- (NSString*)drawSurfaceCaptureContent:(CGContextRef)ctx height:(size_t)height bounds:(CGRect)bounds
{
    BOOL pushedContext = NO;
    NSString* captureResult = SURFACE_CAPTURE_SUCCESS;
    CGContextSaveGState(ctx);
    @try {
        CGFloat screenScale = [UIScreen mainScreen].scale;
        CGContextTranslateCTM(ctx, 0, height);
        CGContextScaleCTM(ctx, 1.0, -1.0);
        CGContextScaleCTM(ctx, screenScale, screenScale);
        UIGraphicsPushContext(ctx);
        pushedContext = YES;

        CALayer* hostLayer = _config.hostLayerBlock ? _config.hostLayerBlock() : nil;
        AVPlayerLayer* playerLayer = hostLayer ? [self findPlayerLayer:hostLayer] : nil;
        if (playerLayer && playerLayer.player && playerLayer.player.currentItem) {
            captureResult = [self drawCurrentVideoFrame:playerLayer bounds:bounds];
        } else if (_config.drawFallbackBlock) {
            _config.drawFallbackBlock(bounds);
        }
    } @catch (NSException* exception) {
        NSString* exceptionMessage = exception.reason ? exception.reason : exception.name;
        if (!exceptionMessage) {
            exceptionMessage = @"unknown exception";
        }
        LOGE("%{public}s: surfaceCapture exception: %{public}s", _config.logTag, exceptionMessage.UTF8String);
        captureResult = SURFACE_CAPTURE_FAILED;
    } @finally {
        if (pushedContext) {
            UIGraphicsPopContext();
        }
        CGContextRestoreGState(ctx);
    }
    return captureResult;
}

- (NSString*)captureSurfaceOnMainThread:(NSDictionary*)params bounds:(CGRect)bounds
{
    NSString* pointerStr = params[SURFACE_CAPTURE_NATIVE_BUFFER_KEY];
    if (!pointerStr) {
        LOGE("%{public}s: surfaceCapture missing nativeBuffer param", _config.logTag);
        return SURFACE_CAPTURE_FAILED;
    }

    void* buffer = reinterpret_cast<void*>(static_cast<uintptr_t>(pointerStr.longLongValue));
    if (!buffer) {
        LOGE("%{public}s: surfaceCapture invalid nativeBuffer", _config.logTag);
        return SURFACE_CAPTURE_FAILED;
    }

    NSInteger widthValue = [params[_config.widthKey] integerValue];
    NSInteger heightValue = [params[_config.heightKey] integerValue];
    if (widthValue <= 0 || heightValue <= 0) {
        LOGE("%{public}s: surfaceCapture invalid size, w=%{public}ld, h=%{public}ld", _config.logTag,
            static_cast<long>(widthValue), static_cast<long>(heightValue));
        return SURFACE_CAPTURE_FAILED;
    }

    size_t width = static_cast<size_t>(widthValue);
    size_t height = static_cast<size_t>(heightValue);

    if (width > MAX_CAPTURE_DIMENSION || height > MAX_CAPTURE_DIMENSION) {
        LOGE("%{public}s: surfaceCapture dimensions exceed limit, w=%zu, h=%zu", _config.logTag, width, height);
        return SURFACE_CAPTURE_FAILED;
    }

    size_t bufferSize = width * height * BYTES_PER_PIXEL;
    if (bufferSize > MAX_CAPTURE_BUFFER_SIZE) {
        LOGE("%{public}s: surfaceCapture bufferSize exceeds limit, w=%zu, h=%zu, bufferSize=%zu",
            _config.logTag, width, height, bufferSize);
        return SURFACE_CAPTURE_FAILED;
    }

    CGColorSpaceRef colorSpace = nullptr;
    CGContextRef ctx = [self createSurfaceCaptureContext:buffer width:width height:height colorSpace:&colorSpace];
    if (!ctx) {
        return SURFACE_CAPTURE_FAILED;
    }

    NSString* captureResult = [self drawSurfaceCaptureContent:ctx height:height bounds:bounds];
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    return captureResult;
}

@end