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

#ifndef RENDER_PROGRAM_H
#define RENDER_PROGRAM_H

#import <Foundation/Foundation.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/EAGL.h>

@interface RenderProgram : NSObject
{
    GLuint  filterProgram;
}

- (instancetype)initWithVertexShaderType:(NSString*)vString fragShader:(NSString*)fString;
- (GLint)attribLocationForName:(NSString*)atrname;
- (GLint)uniformLocationForName:(NSString*)uname;
- (void)use;
- (void)destroy;
@end

#endif // RENDER_PROGRAM_H