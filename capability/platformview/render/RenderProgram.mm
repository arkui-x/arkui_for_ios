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

#import "RenderProgram.h"

@implementation RenderProgram

- (instancetype)initWithVertexShaderType:(NSString*)vString fragShader:(NSString*)fString {
    if (self = [super init]) {
        GLuint vShader = 0, fShader = 0;
        if(![self compileShader:GL_VERTEX_SHADER sString:vString shader:&vShader]){
            return nil;
        }
        if(![self compileShader:GL_FRAGMENT_SHADER sString:fString shader:&fShader]){
            return nil;
        }
        filterProgram = glCreateProgram();
        glAttachShader(filterProgram, vShader);
        glAttachShader(filterProgram, fShader);
        glLinkProgram(filterProgram);       
        GLint status;
        glValidateProgram(filterProgram);
        glGetProgramiv(filterProgram, GL_LINK_STATUS, &status);
        if (status == GL_FALSE) {
            NSLog(@"link program fail %d",status);
            return nil;
        }
    }
    return self;
}

- (BOOL)compileShader:(GLenum)type sString:(NSString*)sString shader:(GLuint*)shaderRet {
    if (sString.length == 0) {
        NSLog(@"shader is nil");
        return NO;
    }

    const GLchar *sources = (GLchar*)[sString UTF8String];
    GLuint shader = glCreateShader(type);
    if (shader == 0 || shader == GL_INVALID_ENUM) {
        NSLog(@"glCreateShader fail");
        return NO;
    }

    glShaderSource(shader, 1, &sources, NULL);
    glCompileShader(shader);
    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"compile fail:%d", status);
        return NO;
    }
    *shaderRet = shader;
    return YES;
}

- (GLint)attribLocationForName:(NSString*)atrname {
    if (filterProgram == 0 || atrname.length == 0) {
        return -1;
    }
    return glGetAttribLocation(filterProgram, [atrname UTF8String]);
}

- (GLint)uniformLocationForName:(NSString*)uname {
    if (filterProgram == 0 || uname.length == 0) {
        return -1;
    }
    return glGetUniformLocation(filterProgram, [uname UTF8String]);
}

- (void)use {
    if (filterProgram == 0) {
        return;
    }
    glUseProgram(filterProgram);
}

- (void)destroy {
    if (filterProgram != 0) {
        glDeleteProgram(filterProgram);
        filterProgram = 0;
    }
}
@end
