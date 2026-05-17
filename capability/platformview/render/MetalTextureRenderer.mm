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

#import "MetalTextureRenderer.h"

#import <CoreVideo/CVPixelBufferIOSurface.h>
#import <Metal/Metal.h>
#import <QuartzCore/CARenderer.h>
#import <WebKit/WebKit.h>

#include <atomic>
#include <CoreVideo/CVPixelBuffer.h>
#include <Foundation/Foundation.h>
#include <Foundation/NSObjCRuntime.h>
#include <QuartzCore/QuartzCore.h>

#include "base/log/log.h"

namespace {
constexpr NSUInteger REDUCED_TEXTURE_SIZE = 32;
constexpr uint32_t FRAME_DIFF_THRESHOLD = 1024;
constexpr NSUInteger DIFF_BUFFER_COUNT = 2;
constexpr NSUInteger RENDER_TARGET_COUNT = 6;
constexpr NSUInteger RESET_BASELINE_COMPARE_FRAMES = 90;
constexpr NSUInteger RESET_BASELINE_WARMUP_FRAMES = 2;
constexpr NSUInteger FRAME_DIFF_SAMPLE_INTERVAL = 2;
constexpr NSUInteger MAX_THREADGROUP_HEIGHT = 8;
static char kFrameDiffQueueSpecificKeyVar;

NSString* const kFrameDiffShaderSource = @"using namespace metal;\n"
                                         @"kernel void downsampleTexture(texture2d<half, access::read> source "
                                         @"[[texture(0)]],\n"
                                         @"                              texture2d<half, access::write> reduced "
                                         @"[[texture(1)]],\n"
                                         @"                              uint2 gid [[thread_position_in_grid]])\n"
                                         @"{\n"
                                         @"    uint dw = reduced.get_width();\n"
                                         @"    uint dh = reduced.get_height();\n"
                                         @"    if (gid.x >= dw || gid.y >= dh) {\n"
                                         @"        return;\n"
                                         @"    }\n"
                                         @"    uint sw = source.get_width();\n"
                                         @"    uint sh = source.get_height();\n"
                                         @"    uint x0 = min((gid.x * sw) / dw, sw - 1);\n"
                                         @"    uint y0 = min((gid.y * sh) / dh, sh - 1);\n"
                                         @"    uint nextX = max(((gid.x + 1) * sw) / dw, x0 + 1);\n"
                                         @"    uint nextY = max(((gid.y + 1) * sh) / dh, y0 + 1);\n"
                                         @"    uint x1 = min(nextX - 1, sw - 1);\n"
                                         @"    uint y1 = min(nextY - 1, sh - 1);\n"
                                         @"    half4 c0 = source.read(uint2(x0, y0));\n"
                                         @"    half4 c1 = source.read(uint2(x1, y0));\n"
                                         @"    half4 c2 = source.read(uint2(x0, y1));\n"
                                         @"    half4 c3 = source.read(uint2(x1, y1));\n"
                                         @"    reduced.write((c0 + c1 + c2 + c3) * half(0.25), gid);\n"
                                         @"}\n"
                                         @"kernel void compareReducedTextures(texture2d<half, access::read> "
                                         @"currentTex [[texture(0)]],\n"
                                         @"                                  texture2d<half, access::read> "
                                         @"previousTex [[texture(1)]],\n"
                                         @"                                  device atomic_uint *diffValue "
                                         @"[[buffer(0)]],\n"
                                         @"                                  uint2 gid "
                                         @"[[thread_position_in_grid]])\n"
                                         @"{\n"
                                         @"    uint width = currentTex.get_width();\n"
                                         @"    uint height = currentTex.get_height();\n"
                                         @"    if (gid.x >= width || gid.y >= height) {\n"
                                         @"        return;\n"
                                         @"    }\n"
                                         @"    float4 currentColor = float4(currentTex.read(gid));\n"
                                         @"    float4 previousColor = float4(previousTex.read(gid));\n"
                                         @"    float4 delta = fabs(currentColor - previousColor) * 255.0;\n"
                                         @"    uint diff = uint(delta.x + delta.y + delta.z + delta.w + 0.5);\n"
                                         @"    atomic_fetch_add_explicit(&(diffValue[0]), diff, "
                                         @"memory_order_relaxed);\n"
                                         @"}\n";
}

@interface MetalTextureRenderer () {
    CGFloat _screenScale;
    CGRect _rendererBounds;
    const void* _rendererLayerIdentity;
    dispatch_queue_t _frameDiffQueue;
    std::atomic_bool _shouldPublishFrame;
    std::atomic_bool _frameDiffInFlight;
    std::atomic_bool _isDestroyed;
    std::atomic_uint _skipCompareFrameCount;
    BOOL _hasPreviousReducedFrame;
    BOOL _resetBaseline;
    BOOL _canRenderUpdateBounds;
    NSUInteger _unchangedFrameCount;
    NSUInteger _frameDiffSampleCounter;
    NSUInteger _nextDiffBufferIndex;
    NSUInteger _nextRenderTargetIndex;
}

@property(nonatomic, strong) NSMutableArray<UIViewMetalRenderTarget*>* renderTargets;
@property(nonatomic, retain) id<MTLDevice> metalDevice;
@property(nonatomic, retain) CARenderer* renderer;
@property(nonatomic, retain) id<MTLCommandQueue> commandQueue;
@property(nonatomic, retain) id<MTLComputePipelineState> downsamplePipeline;
@property(nonatomic, retain) id<MTLComputePipelineState> comparePipeline;
@property(nonatomic, retain) id<MTLTexture> currentReducedTexture;
@property(nonatomic, retain) id<MTLTexture> previousReducedTexture;
@property(nonatomic, retain) NSArray<id<MTLBuffer>>* diffBuffers;
@property(nonatomic, assign) BOOL shouldPublish;

@end

@implementation MetalTextureRenderer

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nullptr) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.renderTargets = [NSMutableArray arrayWithCapacity:RENDER_TARGET_COUNT];
        for (NSUInteger index = 0; index < RENDER_TARGET_COUNT; ++index) {
            [self.renderTargets addObject:[[UIViewMetalRenderTarget alloc] init]];
        }
        _screenScale = UIScreen.mainScreen.scale;
        _rendererBounds = CGRectNull;
        _rendererLayerIdentity = nullptr;
        dispatch_queue_attr_t attr =
            dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
        _frameDiffQueue = dispatch_queue_create("com.arkui.platformview.frame_diff", attr);
        dispatch_queue_set_specific(
            _frameDiffQueue, &kFrameDiffQueueSpecificKeyVar, &kFrameDiffQueueSpecificKeyVar, nullptr);
        _shouldPublishFrame.store(true, std::memory_order_release);
        _frameDiffInFlight.store(false, std::memory_order_release);
        _isDestroyed.store(false, std::memory_order_release);
        _skipCompareFrameCount.store(0, std::memory_order_release);
        _hasPreviousReducedFrame = NO;
        _shouldPublish = YES;
        _unchangedFrameCount = 0;
        _frameDiffSampleCounter = 0;
        _nextDiffBufferIndex = 0;
        _resetBaseline = NO;
        _canRenderUpdateBounds = NO;
        _nextRenderTargetIndex = RENDER_TARGET_COUNT - 1;
    }
    return self;
}

- (void)ensureMetalSetup:(UIView*)view
{
    if (view == nullptr) {
        return;
    }
    if (self.metalDevice == nullptr) {
        [self setupMetal];
    }
    _canRenderUpdateBounds = ![view isKindOfClass:NSClassFromString(@"MKMapView")];
}

- (void)setupMetal
{
    self.metalDevice = MTLCreateSystemDefaultDevice();
    if (self.metalDevice == nullptr) {
        LOGE("%{public}s error: failed to create metal device", __func__);
        return;
    }
    CVMetalTextureCacheRef textureCache = nullptr;
    CVReturn ret = CVMetalTextureCacheCreate(kCFAllocatorDefault, nullptr, self.metalDevice, nullptr, &textureCache);
    if (ret != kCVReturnSuccess) {
        LOGE("%{public}s error: failed to create texture cache, ret=%{public}d", __func__, ret);
        return;
    }
    for (UIViewMetalRenderTarget* renderTarget in self.renderTargets) {
        renderTarget.textureCache = textureCache;
    }
    if (textureCache != nullptr) {
        CFRelease(textureCache);
    }
    self.commandQueue = [self.metalDevice newCommandQueue];
    if (self.commandQueue == nullptr) {
        LOGE("%{public}s error: failed to create command queue", __func__);
        return;
    }
    NSError* error = nil;
    id<MTLLibrary> library = [self.metalDevice newLibraryWithSource:kFrameDiffShaderSource options:nil error:&error];
    if (library == nullptr || error != nullptr) {
        LOGE("%{public}s error: failed to create metal library", __func__);
        return;
    }
    id<MTLFunction> downsampleFunction = [library newFunctionWithName:@"downsampleTexture"];
    id<MTLFunction> compareFunction = [library newFunctionWithName:@"compareReducedTextures"];
    if (downsampleFunction == nullptr || compareFunction == nullptr) {
        LOGE("%{public}s error: failed to create metal functions", __func__);
        return;
    }
    self.downsamplePipeline = [self.metalDevice newComputePipelineStateWithFunction:downsampleFunction error:&error];
    if (self.downsamplePipeline == nullptr || error != nullptr) {
        LOGE("%{public}s error: failed to create downsample pipeline", __func__);
        return;
    }
    error = nil;
    self.comparePipeline = [self.metalDevice newComputePipelineStateWithFunction:compareFunction error:&error];
    if (self.comparePipeline == nullptr || error != nullptr) {
        LOGE("%{public}s error: failed to create compare pipeline", __func__);
    }
}

- (void)resetFrameDiffState
{
    _shouldPublishFrame.store(true, std::memory_order_release);
    _frameDiffInFlight.store(false, std::memory_order_release);
    _skipCompareFrameCount.store(0, std::memory_order_release);
    _hasPreviousReducedFrame = NO;
    _unchangedFrameCount = 0;
    _frameDiffSampleCounter = 0;
    _nextDiffBufferIndex = 0;
    self.currentReducedTexture = nil;
    self.previousReducedTexture = nil;
    self.diffBuffers = nil;
    _nextRenderTargetIndex = RENDER_TARGET_COUNT - 1;
}

- (void)resetFrameDiffStateOnQueue
{
    if (_frameDiffQueue != nullptr) {
        if (dispatch_get_specific(&kFrameDiffQueueSpecificKeyVar) != nullptr) {
            [self resetFrameDiffState];
        } else {
            dispatch_sync(_frameDiffQueue, ^{
              [self resetFrameDiffState];
            });
        }
    } else {
        [self resetFrameDiffState];
    }
}

- (BOOL)prepareReducedTextures
{
    if (self.currentReducedTexture != nullptr && self.previousReducedTexture != nullptr &&
        self.diffBuffers.count == DIFF_BUFFER_COUNT) {
        return YES;
    }
    if (self.metalDevice == nullptr) {
        return NO;
    }
    MTLTextureDescriptor* descriptor =
                            [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                               width:REDUCED_TEXTURE_SIZE
                                                                              height:REDUCED_TEXTURE_SIZE
                                                                           mipmapped:NO];
    descriptor.storageMode = MTLStorageModePrivate;
    descriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    self.currentReducedTexture = [self.metalDevice newTextureWithDescriptor:descriptor];
    self.previousReducedTexture = [self.metalDevice newTextureWithDescriptor:descriptor];
    NSMutableArray<id<MTLBuffer>>* buffers = [NSMutableArray arrayWithCapacity:DIFF_BUFFER_COUNT];
    for (NSUInteger index = 0; index < DIFF_BUFFER_COUNT; ++index) {
        id<MTLBuffer> buffer = [self.metalDevice newBufferWithLength:sizeof(uint32_t)
                                                             options:MTLResourceStorageModeShared];
        if (buffer == nullptr) {
            LOGE("%{public}s error: failed to create diff buffer", __func__);
            return NO;
        }
        [buffers addObject:buffer];
    }
    self.diffBuffers = buffers;
    if (self.currentReducedTexture == nullptr || self.previousReducedTexture == nullptr) {
        LOGE("%{public}s error: failed to create reduced comparison resources", __func__);
        return NO;
    }
    return YES;
}

- (UIViewMetalRenderTarget*)currentRenderTarget
{
    if (_nextRenderTargetIndex >= self.renderTargets.count) {
        return nil;
    }
    return self.renderTargets[_nextRenderTargetIndex];
}

- (UIViewMetalRenderTarget*)publishedRenderTarget
{
    if (self.renderTargets.count == 0) {
        return nil;
    }
    NSUInteger publishTargetIndex = (_nextRenderTargetIndex + self.renderTargets.count - 1) % self.renderTargets.count;
    if (publishTargetIndex >= self.renderTargets.count) {
        return nil;
    }
    return self.renderTargets[publishTargetIndex];
}

- (BOOL)setupRenderDest:(UIViewMetalRenderTarget*)renderTarget
{
    id<MTLTexture> texture = [renderTarget currentMetalTexture];
    if (texture == nullptr) {
        return NO;
    }
    if (self.renderer == nullptr) {
        self.renderer = [CARenderer rendererWithMTLTexture:texture options:nil];
    } else {
        [self.renderer setDestination:texture];
    }
    return self.renderer != nil;
}

- (void)clearAllRenderTargets
{
    for (UIViewMetalRenderTarget* renderTarget in self.renderTargets) {
        [renderTarget clearFrameResources];
    }
    _nextRenderTargetIndex = RENDER_TARGET_COUNT - 1;
}

- (BOOL)configureRenderTarget:(UIViewMetalRenderTarget*)renderTarget width:(size_t)width height:(size_t)height
{
    NSDictionary* pixelBufferAttributes = @{
        (id)kCVPixelBufferIOSurfacePropertiesKey : @ {},
        (id)kCVPixelBufferMetalCompatibilityKey : @YES,
    };
    CVPixelBufferRef newPixelBuffer = nullptr;
    CVReturn pixelBufferRet = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
        (__bridge CFDictionaryRef)pixelBufferAttributes, &newPixelBuffer);
    if (pixelBufferRet != kCVReturnSuccess || newPixelBuffer == nullptr) {
        LOGE("%{public}s error: failed to create pixel buffer, ret=%{public}d", __func__, pixelBufferRet);
        return NO;
    }
    CVPixelBufferLockBaseAddress(newPixelBuffer, 0);
    void* baseAddress = CVPixelBufferGetBaseAddress(newPixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(newPixelBuffer);
    size_t pixelBufferHeight = CVPixelBufferGetHeight(newPixelBuffer);
    if (baseAddress != nullptr && bytesPerRow > 0 && pixelBufferHeight > 0) {
        std::fill(static_cast<uint8_t*>(baseAddress),
                  static_cast<uint8_t*>(baseAddress) + (bytesPerRow * pixelBufferHeight), 0);
    }
    CVPixelBufferUnlockBaseAddress(newPixelBuffer, 0);
    CVMetalTextureRef newMetalTexture = nullptr;
    CVReturn textureRet = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, renderTarget.textureCache,
        newPixelBuffer, nullptr, MTLPixelFormatBGRA8Unorm, width, height, 0, &newMetalTexture);
    if (textureRet != kCVReturnSuccess || newMetalTexture == nullptr) {
        LOGE("%{public}s error: failed to create metal texture, ret=%{public}d", __func__, textureRet);
        CVPixelBufferRelease(newPixelBuffer);
        return NO;
    }
    if (CVMetalTextureGetTexture(newMetalTexture) == nullptr) {
        CFRelease(newMetalTexture);
        CVPixelBufferRelease(newPixelBuffer);
        return NO;
    }
    renderTarget.pixelBuffer = newPixelBuffer;
    renderTarget.metalTexture = newMetalTexture;
    renderTarget.size = CGSizeMake(width, height);
    CVPixelBufferRelease(newPixelBuffer);
    CFRelease(newMetalTexture);
    return YES;
}

- (void)encodeDownsampleFromTexture:(id<MTLTexture>)sourceTexture
                          toTexture:(id<MTLTexture>)reducedTexture
                      commandBuffer:(id<MTLCommandBuffer>)commandBuffer
{
    id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
    if (encoder == nullptr) {
        return;
    }
    [encoder setComputePipelineState:self.downsamplePipeline];
    [encoder setTexture:sourceTexture atIndex:0];
    [encoder setTexture:reducedTexture atIndex:1];
    MTLSize gridSize = MTLSizeMake(REDUCED_TEXTURE_SIZE, REDUCED_TEXTURE_SIZE, 1);
    NSUInteger threadWidth = MIN(self.downsamplePipeline.threadExecutionWidth, REDUCED_TEXTURE_SIZE);
    NSUInteger threadHeight = MAX((NSUInteger)1, self.downsamplePipeline.maxTotalThreadsPerThreadgroup / threadWidth);
    threadHeight = MIN(threadHeight, (NSUInteger)MAX_THREADGROUP_HEIGHT);
    MTLSize threadgroupSize = MTLSizeMake(threadWidth, threadHeight, 1);
    [encoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
    [encoder endEncoding];
}

- (void)encodeCompareWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer diffBuffer:(id<MTLBuffer>)diffBuffer
{
    id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
    if (encoder == nullptr) {
        return;
    }
    [encoder setComputePipelineState:self.comparePipeline];
    [encoder setTexture:self.currentReducedTexture atIndex:0];
    [encoder setTexture:self.previousReducedTexture atIndex:1];
    [encoder setBuffer:diffBuffer offset:0 atIndex:0];
    MTLSize gridSize = MTLSizeMake(REDUCED_TEXTURE_SIZE, REDUCED_TEXTURE_SIZE, 1);
    NSUInteger threadWidth = MIN(self.comparePipeline.threadExecutionWidth, REDUCED_TEXTURE_SIZE);
    NSUInteger threadHeight = MAX((NSUInteger)1, self.comparePipeline.maxTotalThreadsPerThreadgroup / threadWidth);
    threadHeight = MIN(threadHeight, (NSUInteger)MAX_THREADGROUP_HEIGHT);
    MTLSize threadgroupSize = MTLSizeMake(threadWidth, threadHeight, 1);
    [encoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
    [encoder endEncoding];
}

- (void)consumeFrameDiffResult:(uint32_t)diffValue hadPreviousFrame:(BOOL)hadPreviousFrame
{
    uint32_t threshold = FRAME_DIFF_THRESHOLD;
    if (!hadPreviousFrame || diffValue > threshold) {
        _unchangedFrameCount = 0;
        _shouldPublishFrame.store(true, std::memory_order_release);
        return;
    }
    if (_unchangedFrameCount < RESET_BASELINE_COMPARE_FRAMES) {
        ++_unchangedFrameCount;
    }
    if (_unchangedFrameCount >= RESET_BASELINE_COMPARE_FRAMES) {
        _shouldPublishFrame.store(false, std::memory_order_release);
    }
}

- (id<MTLBuffer>)prepareDiffBuffer:(BOOL)resetBaseline hadPrevious:(BOOL*)outHadPrevious suppress:(BOOL*)outSuppress
{
    if (![self prepareReducedTextures]) {
        _frameDiffInFlight.store(false, std::memory_order_release);
        _unchangedFrameCount = 0;
        return nil;
    }
    id<MTLBuffer> diffBuffer = self.diffBuffers[_nextDiffBufferIndex];
    _nextDiffBufferIndex = (_nextDiffBufferIndex + 1) % DIFF_BUFFER_COUNT;
    uint32_t* diffValue = static_cast<uint32_t*>([diffBuffer contents]);
    if (diffValue == nullptr) {
        _frameDiffInFlight.store(false, std::memory_order_release);
        _unchangedFrameCount = 0;
        return nil;
    }
    *diffValue = 0;
    if (resetBaseline) {
        _skipCompareFrameCount.store(RESET_BASELINE_WARMUP_FRAMES, std::memory_order_release);
    }
    uint32_t skipCompareFrameCount = _skipCompareFrameCount.load(std::memory_order_acquire);
    BOOL suppress = skipCompareFrameCount > 0;
    if (suppress) {
        _skipCompareFrameCount.fetch_sub(1, std::memory_order_acq_rel);
    }
    BOOL hadPrevious = (!suppress && _hasPreviousReducedFrame);
    if (outHadPrevious != nullptr) {
        *outHadPrevious = hadPrevious;
    }
    if (outSuppress != nullptr) {
        *outSuppress = suppress;
    }
    return diffBuffer;
}

- (void)submitDiff:(id<MTLTexture>)sourceTexture reset:(BOOL)resetBaseline
{
    if (_isDestroyed.load(std::memory_order_acquire)) {
        return;
    }
    if (sourceTexture == nullptr || self.commandQueue == nullptr || self.downsamplePipeline == nullptr ||
        self.comparePipeline == nullptr) {
        _frameDiffInFlight.store(false, std::memory_order_release);
        _unchangedFrameCount = 0;
        return;
    }
    if (_frameDiffInFlight.load(std::memory_order_acquire)) {
        if (resetBaseline) {
            _skipCompareFrameCount.store(RESET_BASELINE_WARMUP_FRAMES, std::memory_order_release);
        }
        return;
    }
    _frameDiffInFlight.store(true, std::memory_order_release);
    BOOL hadPrevious = NO;
    BOOL suppressComparison = NO;
    id<MTLBuffer> diffBuffer = [self prepareDiffBuffer:resetBaseline
                                           hadPrevious:&hadPrevious
                                              suppress:&suppressComparison];
    if (diffBuffer == nullptr) {
        return;
    }
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    if (commandBuffer == nullptr) {
        _frameDiffInFlight.store(false, std::memory_order_release);
        _unchangedFrameCount = 0;
        return;
    }
    [self encodeDownsampleFromTexture:sourceTexture toTexture:self.currentReducedTexture commandBuffer:commandBuffer];
    [self encodeCommandBuffer:commandBuffer
                   diffBuffer:diffBuffer
                  hadPrevious:hadPrevious
                     suppress:suppressComparison];
}

- (void)encodeCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 diffBuffer:(id<MTLBuffer>)diffBuffer
                hadPrevious:(BOOL)hadPrevious
                   suppress:(BOOL)suppressComparison
{
    if (hadPrevious) {
        [self encodeCompareWithCommandBuffer:commandBuffer diffBuffer:diffBuffer];
    }
    id<MTLBlitCommandEncoder> blitEncoder = [commandBuffer blitCommandEncoder];
    if (blitEncoder != nullptr) {
        [blitEncoder copyFromTexture:self.currentReducedTexture
                         sourceSlice:0
                         sourceLevel:0
                        sourceOrigin:MTLOriginMake(0, 0, 0)
                          sourceSize:MTLSizeMake(REDUCED_TEXTURE_SIZE, REDUCED_TEXTURE_SIZE, 1)
                           toTexture:self.previousReducedTexture
                    destinationSlice:0
                    destinationLevel:0
                   destinationOrigin:MTLOriginMake(0, 0, 0)];
        [blitEncoder endEncoding];
    }
    [self commitCommandBuffer:commandBuffer
                   diffBuffer:diffBuffer
             hadPreviousFrame:hadPrevious
           suppressComparison:suppressComparison];
    _hasPreviousReducedFrame = YES;
}

- (void)commitCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
                 diffBuffer:(id<MTLBuffer>)diffBuffer
           hadPreviousFrame:(BOOL)hadPrevious
         suppressComparison:(BOOL)suppressComparison
{
    __weak MetalTextureRenderer* weakSelf = self;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> completedBuffer) {
        MetalTextureRenderer* strongSelf = weakSelf;
        if (strongSelf == nullptr) {
            return;
        }
        if (strongSelf->_isDestroyed.load(std::memory_order_acquire) || strongSelf->_frameDiffQueue == nullptr) {
            strongSelf->_frameDiffInFlight.store(false, std::memory_order_release);
            return;
        }
        dispatch_async(strongSelf->_frameDiffQueue, ^{
            if (completedBuffer.status != MTLCommandBufferStatusCompleted) {
                strongSelf->_frameDiffInFlight.store(false, std::memory_order_release);
                strongSelf->_unchangedFrameCount = 0;
                LOGE("%{public}s error: frame diff command buffer failed", __func__);
                return;
            }
            uint32_t completedDiffValue = 0;
            uint32_t* completedDiffPointer = static_cast<uint32_t*>([diffBuffer contents]);
            if (completedDiffPointer != nullptr) {
                completedDiffValue = *completedDiffPointer;
            }
            if (!suppressComparison) {
                [strongSelf consumeFrameDiffResult:completedDiffValue hadPreviousFrame:hadPrevious];
            }
            strongSelf->_frameDiffInFlight.store(false, std::memory_order_release);
        });
    }];
    [commandBuffer commit];
}

- (BOOL)shouldPublishFrame
{
    return _shouldPublishFrame.load(std::memory_order_acquire);
}

- (void)syncRendererStateForView:(UIView*)view
{
    if (self.renderer == nullptr || view == nullptr) {
        return;
    }
    CALayer* currentLayer = view.layer;
    const void* currentLayerIdentity = (__bridge const void*)(currentLayer);
    if (_rendererLayerIdentity != currentLayerIdentity) {
        self.renderer.layer = currentLayer;
        _rendererLayerIdentity = currentLayerIdentity;
    }
    CGFloat alignedWidth = view.bounds.size.width * _screenScale;
    CGFloat alignedHeight = view.bounds.size.height * _screenScale;
    CGRect rendererBounds = CGRectMake(0, 0, alignedWidth, alignedHeight);
    if (!CGRectEqualToRect(_rendererBounds, rendererBounds)) {
        self.renderer.bounds = rendererBounds;
        _rendererBounds = rendererBounds;
    }
}

- (BOOL)recreateRenderTargetWithWidth:(size_t)width height:(size_t)height view:(UIView*)view
{
    [self clearAllRenderTargets];
    for (UIViewMetalRenderTarget* renderTarget in self.renderTargets) {
        if (![self configureRenderTarget:renderTarget width:width height:height]) {
            [self clearAllRenderTargets];
            return NO;
        }
    }
    if (![self setupRenderDest:[self currentRenderTarget]]) {
        LOGE("%{public}s error: failed to create renderer", __func__);
        [self clearAllRenderTargets];
        return NO;
    }
    [self resetFrameDiffStateOnQueue];
    _rendererLayerIdentity = nullptr;
    _rendererBounds = CGRectNull;
    [self syncRendererStateForView:view];
    return YES;
}

- (bool)prepareRenderTargetForView:(UIView*)view
{
    UIViewMetalRenderTarget* currentRenderTarget = [self currentRenderTarget];
    if (self.metalDevice == nullptr || currentRenderTarget == nullptr || currentRenderTarget.textureCache == nullptr) {
        return false;
    }

    CGSize boundsSize = view.bounds.size;
    size_t width = static_cast<size_t>(ceil(boundsSize.width * _screenScale));
    size_t height = static_cast<size_t>(ceil(boundsSize.height * _screenScale));
    if (width == 0 || height == 0) {
        return false;
    }

    if (currentRenderTarget.pixelBuffer != nullptr && self.renderer != nullptr &&
        CGSizeEqualToSize(currentRenderTarget.size, CGSizeMake(width, height))) {
        if (![self setupRenderDest:currentRenderTarget]) {
            return false;
        }
        [self syncRendererStateForView:view];
        return true;
    }
    return [self recreateRenderTargetWithWidth:width height:height view:view];
}

- (bool)startRender:(UIView*)view
{
    if (_isDestroyed.load(std::memory_order_acquire) || view == nullptr) {
        return false;
    }
    UIViewMetalRenderTarget* currentRenderTarget = [self currentRenderTarget];
    if (_shouldPublish && !currentRenderTarget.isScale) {
        if (self.renderTargets.count == 0) {
            return false;
        }
        _nextRenderTargetIndex = (_nextRenderTargetIndex + 1) % self.renderTargets.count;
        currentRenderTarget = [self currentRenderTarget];
        if (currentRenderTarget == nullptr) {
            return false;
        }
    }
    if (![self prepareRenderTargetForView:view]) {
        return false;
    }
    BOOL publishCurrentFrame = _shouldPublish;
    if (_canRenderUpdateBounds && !publishCurrentFrame) {
        [self.renderer beginFrameAtTime:CACurrentMediaTime() timeStamp:nil];
        CGRect updateRect = [self.renderer updateBounds];
        if (!CGRectIsEmpty(updateRect) && !_resetBaseline ) {
            _shouldPublishFrame.store(true, std::memory_order_release);
        }
        [self.renderer endFrame];
    } else if (publishCurrentFrame || _frameDiffSampleCounter < FRAME_DIFF_SAMPLE_INTERVAL) {
        [self renderPlatformView:view publishCurrent:publishCurrentFrame currentRenderTarget:currentRenderTarget];
    }
    BOOL shouldPublishFrame = [self shouldPublishFrame];
    _resetBaseline = (publishCurrentFrame != shouldPublishFrame);
    if (_resetBaseline) {
        _shouldPublish = shouldPublishFrame;
    }
    id<MTLTexture> sourceTexture = [currentRenderTarget currentMetalTexture];
    BOOL shouldSampleDiff = _resetBaseline || (_frameDiffSampleCounter++ >= FRAME_DIFF_SAMPLE_INTERVAL);
    if (sourceTexture != nullptr && shouldSampleDiff && _frameDiffQueue != nullptr) {
        _frameDiffSampleCounter = 1;
        __weak MetalTextureRenderer* weakSelf = self;
        dispatch_async(_frameDiffQueue, ^{
            MetalTextureRenderer* strongSelf = weakSelf;
            if (strongSelf == nullptr) {
                return;
            }
            [strongSelf submitDiff:sourceTexture reset:_resetBaseline];
        });
    }
    return publishCurrentFrame;
}

- (void)renderPlatformView:(UIView*)view
            publishCurrent:(BOOL)publishCurrent
       currentRenderTarget:(UIViewMetalRenderTarget*)currentRenderTarget
{
    CATransform3D savedTransform = view.layer.transform;
    BOOL savedGeometryFlipped = view.layer.geometryFlipped;
    [CATransaction flush];
    if (publishCurrent) {
        CGFloat S = _screenScale;
        CGFloat W = CGRectGetWidth(view.bounds);
        CGFloat H = CGRectGetHeight(view.bounds);
        CGFloat aX = view.layer.anchorPoint.x;
        CGFloat aY = view.layer.anchorPoint.y;
        CGFloat pX = view.layer.position.x;
        CGFloat pY = view.layer.position.y;
        CGFloat dxPixels = S * aX * W - pX;
        CGFloat dyPixels = S * aY * H - pY;
        CGFloat dx = dxPixels / S;
        CGFloat dy = dyPixels / S;
        CATransform3D renderTransform =
            CATransform3DConcat(CATransform3DMakeTranslation(dx, dy, 0),
                                CATransform3DMakeScale(S, S, 1.0));
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        view.layer.transform = renderTransform;
        view.layer.geometryFlipped = YES;
        [CATransaction commit];
        currentRenderTarget.isScale = NO;
    } else {
        currentRenderTarget.isScale = YES;
    }
    CFTimeInterval currentTime = CACurrentMediaTime();
    [self.renderer beginFrameAtTime:currentTime timeStamp:nil];
    [self.renderer addUpdateRect:self.renderer.bounds];
    [self.renderer render];
    [self.renderer endFrame];
    if (publishCurrent) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        view.layer.transform = savedTransform;
        view.layer.geometryFlipped = savedGeometryFlipped;
        [CATransaction commit];
    }
}

- (void)destroy
{
    if (_isDestroyed.exchange(true, std::memory_order_acq_rel)) {
        return;
    }
    void (^disconnectRenderer)(void) = ^{
        if (self.superview != nullptr) {
            [self removeFromSuperview];
        }
        self->_rendererLayerIdentity = nullptr;
        self->_rendererBounds = CGRectNull;
    };
    if ([NSThread isMainThread]) {
        disconnectRenderer();
    } else {
        dispatch_sync(dispatch_get_main_queue(), disconnectRenderer);
    }
    if (_frameDiffQueue != nullptr) {
        if (dispatch_get_specific(&kFrameDiffQueueSpecificKeyVar) != nullptr) {
            [self resetFrameDiffState];
        } else {
            dispatch_sync(_frameDiffQueue, ^{
              [self resetFrameDiffState];
            });
        }
    } else {
        [self resetFrameDiffState];
    }
    UIViewMetalRenderTarget* curTarget = [self currentRenderTarget];
    if (curTarget != nullptr) {
        [curTarget clearFrameResources];
        [curTarget clearResources];
    }
    self.downsamplePipeline = nil;
    self.comparePipeline = nil;
    self.commandQueue = nil;
    self.metalDevice = nil;
    [self clearAllRenderTargets];
    self.renderTargets = nil;
}

- (void)dealloc
{
    self.renderer = nil;
    if (_frameDiffQueue != nullptr) {
#if !OS_OBJECT_USE_OBJC
        dispatch_release(_frameDiffQueue);
#endif
        _frameDiffQueue = NULL;
    }
}

- (CVPixelBufferRef)currentPixelBuffer
{
    if (_isDestroyed.load(std::memory_order_acquire)) {
        return nil;
    }
    if (!_shouldPublish) {
        return nil;
    }
    UIViewMetalRenderTarget* publishedRenderTarget = [self publishedRenderTarget];
    if (publishedRenderTarget == nullptr) {
        return nil;
    }
    return [publishedRenderTarget currentPixelBuffer];
}
@end