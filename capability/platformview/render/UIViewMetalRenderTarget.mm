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

#import "UIViewMetalRenderTarget.h"

#import <CoreFoundation/CoreFoundation.h>
#import <CoreVideo/CVMetalTextureCache.h>

@implementation UIViewMetalRenderTarget

- (void)setTextureCache:(CVMetalTextureCacheRef)textureCache
{
    if (_textureCache == textureCache) {
        return;
    }
    if (_textureCache != nullptr) {
        CFRelease(_textureCache);
    }
    _textureCache = textureCache;
    if (_textureCache != nullptr) {
        CFRetain(_textureCache);
    }
}

- (void)setMetalTexture:(CVMetalTextureRef)metalTexture
{
    if (_metalTexture == metalTexture) {
        return;
    }
    if (_metalTexture != nullptr) {
        CFRelease(_metalTexture);
    }
    _metalTexture = metalTexture;
    if (_metalTexture != nullptr) {
        CFRetain(_metalTexture);
    }
}

- (void)setPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    if (_pixelBuffer == pixelBuffer) {
        return;
    }
    if (_pixelBuffer != nullptr) {
        CVPixelBufferRelease(_pixelBuffer);
    }
    _pixelBuffer = pixelBuffer;
    if (_pixelBuffer != nullptr) {
        CVPixelBufferRetain(_pixelBuffer);
    }
}

- (id<MTLTexture>)currentMetalTexture
{
    if (_metalTexture == nullptr) {
        return nullptr;
    }
    return CVMetalTextureGetTexture(_metalTexture);
}

- (CVPixelBufferRef)currentPixelBuffer
{
    if (_pixelBuffer == nullptr) {
        return nullptr;
    }
    CVPixelBufferRef pixelBuffer = _pixelBuffer;
    CVPixelBufferRetain(pixelBuffer);
    return pixelBuffer;
}

- (void)clearFrameResources
{
    self.metalTexture = NULL;
    self.pixelBuffer = NULL;
    if (_textureCache != nullptr) {
        CVMetalTextureCacheFlush(_textureCache, 0);
    }
    self.size = CGSizeZero;
}

- (void)clearResources
{
    [self clearFrameResources];
    self.textureCache = NULL;
}

- (void)dealloc
{
    [self clearResources];
}

@end
