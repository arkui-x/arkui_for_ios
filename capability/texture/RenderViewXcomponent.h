/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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
#ifndef RENDER_VIEW_XCOMPONENT_H
#define RENDER_VIEW_XCOMPONENT_H

#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <UIKit/UIKit.h>

@interface RenderViewXcomponent : UIView <UIGestureRecognizerDelegate>

@property (nonatomic, assign) bool isTouchIng;

- (void)initXComponent:(UIView *)view;
- (void)setEAGLContext:(EAGLContext *)context;
- (void)setTextureName:(int32_t)textureName;
- (void)startRenderXComponent:(UIView *)view;
- (void)exchangeBind;
- (void)releaseObject;
@end

#endif // RENDER_VIEW_XCOMPONENT_H