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

#import "RenderView.h"
#import "RenderProgram.h"

#include <mutex>

#define COLOR_NUMBER 8
#define DATA_SIZE 4
#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

NSString *const vertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 varying vec2 v_texcoord;
 
 void main() {
    gl_Position = position;
    v_texcoord = texcoord.xy;
 }
);

NSString *const rgbFragmentShaderString = SHADER_STRING
(
 varying highp vec2 v_texcoord;
 uniform sampler2D inputImageTexture1;
 uniform sampler2D inputImageTexture2;
 
 void main() {
    gl_FragColor = texture2D(inputImageTexture1, v_texcoord);
 }
);

static GLfloat verArray[] = {
        -1.0f, -1.0f, 0.0f,
        1.0f, -1.0f, 0.0f,
        -1.0f, 1.0f, 0.0f,
        1.0f, 1.0f, 0.0f,
};

static GLfloat texArray[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
};

@interface RenderView() {
    EAGLContext *_context;
    GLuint _texture;
    GLuint _frameBuffer;
    GLuint _renderBuffer;
    
    GLint _renderWidth;
    GLint _renderHeight;
    CGContextRef tContext;
    void *imageData;
}

@property (strong, nonatomic) RenderProgram *program;

@end

@implementation RenderView
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    self.backgroundColor = [UIColor whiteColor];
    _texture = -1;    
    return self;
}

- (void)setEAGLContext:(EAGLContext*)context {
    _context = context;
}

- (void)setTextureName:(int32_t)textureName {
    _texture = textureName;
}

- (void)init {
    if (self) {
        [self setupEAGLContext];
        [self setupBuffer];
        [self setupShaders];
    }
}

#pragma mark - Private methods
- (void)setupEAGLContext {
    CAEAGLLayer *calayer = (CAEAGLLayer *)self.layer;
    calayer.opaque = NO;
    calayer.contentsScale = [UIScreen mainScreen].scale;
    calayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @(NO), kEAGLDrawablePropertyRetainedBacking,
                                  kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                  nil];
    _context.multiThreaded = YES;    
    [EAGLContext setCurrentContext:_context];
}

- (void)setupBuffer {
    [self clearBuffer];
    
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);

    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_renderWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_renderHeight);
}

- (void)setupShaders {
    if (!self.program) {
        self.program = [[RenderProgram alloc] initWithVertexShaderType:vertexShaderString
                                                        fragShader:rgbFragmentShaderString];
    }

    if (self.program && self.program != nil) {
        [self.program use];
    } else {
        NSLog(@"%s error: program wrong!", __func__);
        return;
    }

    GLuint positionAttrib = [self.program attribLocationForName:@"position"];
    GLuint texCoordAttrib = [self.program attribLocationForName:@"texcoord"];
    
    glVertexAttribPointer(positionAttrib, 3, GL_FLOAT, GL_FALSE, 0, verArray);
    glEnableVertexAttribArray(positionAttrib);
    
    glVertexAttribPointer(texCoordAttrib, 2, GL_FLOAT, GL_FALSE, 0, texArray);
    glEnableVertexAttribArray(texCoordAttrib);

    // setup some properties for texture
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); 
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
}

- (UIImage *)createImageByView:(UIView *)view {
    UIImage *image;
    CGFloat scale_ = [UIScreen mainScreen].scale;

    UIGraphicsBeginImageContextWithOptions(view.bounds.size, YES, scale_);
    BOOL isFinish = [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:NO];
    if (isFinish) {
        image = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();
    return image;
}

- (bool)createContext {
    int spaceRow = _renderWidth * DATA_SIZE;
    int space = spaceRow * _renderHeight;
    if (_renderWidth <= 0 || _renderHeight <= 0 || space <= 0) {
        return false;
    }
    if (imageData == NULL) {
        imageData = malloc(space);
        memset(imageData, 0xFF, space); 
    }
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    tContext = CGBitmapContextCreate(imageData, _renderWidth, _renderHeight, COLOR_NUMBER, spaceRow, colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    UIGraphicsPushContext(tContext);
    return true;
}

- (bool)setupImageData:(UIImage *)image {
    CGImageRef cgImage = image.CGImage;

    if (!cgImage) {
        return false;
    }
    if (!tContext) {
        bool isRes = [self createContext];
        if (!isRes) {
            return false;
        }
    }

    GLsizei width = _renderWidth;
    GLsizei height = _renderHeight;

    CGRect cgRect = CGRectMake(0, 0, width, height);
    CGContextDrawImage(tContext, cgRect, cgImage);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _renderWidth, _renderHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    return true;
}

#pragma mark - Public method
- (UIImage *)readDataWithImageData:(void *)imageData {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmapContext = CGBitmapContextCreate(imageData, 
                                                        _renderWidth, 
                                                        _renderHeight, 
                                                        8, 
                                                        _renderWidth * 4, 
                                                        colorSpace, 
                                                        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
    UIImage *uiImage = [[UIImage alloc] initWithCGImage:cgImage];

    CGImageRelease(cgImage);
    CGContextRelease(bitmapContext);
    CGColorSpaceRelease(colorSpace);

    return uiImage;
}

- (void)exchangeBind {}

- (bool)startRender:(UIView *)view {
    if (!view) {
        NSLog(@"error: view no found");
        return false;
    }

    UIImage *image = [self createImageByView:view];
    if (image == nil) {
        return false;
    }
    return [self setupImageData:image];
}

#pragma mark - dealloc
- (void)dealloc {
    [self destroy];
}

- (void)destroy {
    [self clearBuffer];

    if (self.program && self.program != nil) {
        [self.program destroy];
        self.program = nil;
    }

    if (_context) {
        _context = nil;
    }
    if (tContext) {
        CGContextRelease(tContext);
        tContext = nil;
    }
    if (imageData != NULL) {
        free(imageData);
    }
}

- (void)clearBuffer {
    if (_frameBuffer) {
        glDeleteFramebuffers(1, &_frameBuffer);
        _frameBuffer = 0;
    }

    if (_renderBuffer) {
        glDeleteRenderbuffers(1, &_renderBuffer);
        _renderBuffer = 0;
    }
}
@end
