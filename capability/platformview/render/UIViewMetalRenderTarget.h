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
#ifndef UI_VIEW_METAL_RENDER_TARGET_H
#define UI_VIEW_METAL_RENDER_TARGET_H

#import <CoreFoundation/CoreFoundation.h>
#import <CoreVideo/CVPixelBuffer.h>
#import <CoreVideo/CVMetalTextureCache.h>
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@interface UIViewMetalRenderTarget : NSObject

@property (nonatomic, assign) CVMetalTextureCacheRef textureCache;
@property (nonatomic, assign) CVMetalTextureRef metalTexture;
@property (nonatomic, assign) CVPixelBufferRef pixelBuffer;
@property (nonatomic, assign) bool isScale;
@property (nonatomic, assign) CGSize size;

- (id<MTLTexture>)currentMetalTexture;
- (CVPixelBufferRef)currentPixelBuffer;
- (void)clearFrameResources;
- (void)clearResources;

@end

#endif // UI_VIEW_METAL_RENDER_TARGET_H