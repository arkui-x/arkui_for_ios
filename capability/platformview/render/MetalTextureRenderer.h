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
#ifndef METAL_TEXTURE_RENDERER_H
#define METAL_TEXTURE_RENDERER_H

#import <UIKit/UIKit.h>

#import "UIViewMetalRenderTarget.h"

@interface MetalTextureRenderer : UIView

- (void)ensureMetalSetup:(UIView *)view;
- (bool)startRender:(UIView *)view;
- (void)destroy;
/*
 * Caller should be careful to release the buffer.
 */
- (CVPixelBufferRef)currentPixelBuffer;
@end

#endif // METAL_TEXTURE_RENDERER_H