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

#import "RenderViewXcomponent.h"

#include <Foundation/Foundation.h>
#include <mutex>

#import "RenderProgram.h"
#include "securec.h"

#define COLOR_NUMBER 8
#define DATA_SIZE 4
#define RENDER_SCALE 2
#define POSITIONATTRIB_SIZE 3
#define TEXCOORDATTRIB_SIZE 2
#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @STRINGIZE2(text)

static const void *kRenderQueueSpecificKey = &kRenderQueueSpecificKey;

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

@interface RenderViewXcomponent() {
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

@implementation RenderViewXcomponent

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    self.backgroundColor = [UIColor whiteColor];
    NSString *strQueue = [NSString stringWithFormat:@"com.renderView.queue.%p", self];
    self.renderQueue = dispatch_queue_create([strQueue UTF8String], DISPATCH_QUEUE_SERIAL);
    dispatch_queue_set_specific(self.renderQueue, kRenderQueueSpecificKey, (void*)kRenderQueueSpecificKey, NULL);
    _texture = -1;
    return self;
}

- (void)setEAGLContext:(EAGLContext*)context
{
    _context = context;
    _context.multiThreaded = YES;
}

- (void)setTextureName:(int32_t)textureName
{
    _texture = textureName;
}

- (void)initXComponent:(UIView*)view
{
    if (self) {
        _isTouchIng = NO;
        CAEAGLLayer* calayer = (CAEAGLLayer*)self.layer;
        calayer.opaque = YES;
        calayer.contentsScale = [UIScreen mainScreen].scale;
        calayer.drawableProperties =
            [NSDictionary dictionaryWithObjectsAndKeys:@(NO), kEAGLDrawablePropertyRetainedBacking,
                          kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        __weak RenderViewXcomponent *weakSelf = self;
        dispatch_async(self.renderQueue, ^{
            [EAGLContext setCurrentContext:_context];
            [weakSelf setupBuffer];
            [weakSelf setupShaders];
            [weakSelf createContext];
        });
        UIPanGestureRecognizer* panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                     action:@selector(handlePan:)];
        panGesture.cancelsTouchesInView = NO;
        panGesture.delaysTouchesBegan = NO;
        panGesture.delaysTouchesEnded = NO;
        [view.superview addGestureRecognizer:panGesture];
    }
}

#pragma mark - Private methods

- (void)setupBuffer
{
    [self clearBuffer];
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
    __weak RenderViewXcomponent *weakSelf = self;
    dispatch_main_sync_safe(^{
        [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)weakSelf.layer];
    });
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_renderWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_renderHeight);
    int screenScale = [UIScreen mainScreen].scale;
    _renderWidth = _renderWidth / screenScale * RENDER_SCALE;
    _renderHeight = _renderHeight / screenScale * RENDER_SCALE;
}

- (void)setupShaders
{
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
    glVertexAttribPointer(positionAttrib, POSITIONATTRIB_SIZE, GL_FLOAT, GL_FALSE, 0, verArray);
    glEnableVertexAttribArray(positionAttrib);
    glVertexAttribPointer(texCoordAttrib, TEXCOORDATTRIB_SIZE, GL_FLOAT, GL_FALSE, 0, texArray);
    glEnableVertexAttribArray(texCoordAttrib);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
}

- (bool)createContext
{
    if (tContext) {
        CGContextRelease(tContext);
        tContext = nil;
    }
    int spaceRow = _renderWidth * DATA_SIZE;
    int space = spaceRow * _renderHeight;
    if (_renderWidth <= 0 || _renderHeight <= 0 || space <= 0) {
        return false;
    }
    if (imageData) {
        free(imageData);
        imageData = NULL;
    }
    if (imageData == NULL) {
        imageData = malloc(space);
        errno_t result = memset_s(imageData, space, 0x00, space);
        if (result != 0) {
            NSLog(@"%s error: memset_s failed", __func__);
        }
    }
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    tContext = CGBitmapContextCreate(imageData, _renderWidth, _renderHeight, COLOR_NUMBER, spaceRow, colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    CGContextTranslateCTM(tContext, 0, _renderHeight);
    CGContextScaleCTM(tContext, 1, -1);
    return true;
}

- (void)exchangeBind {}

- (void)startRenderXComponent:(UIView*)view
{
    if (!view) {
        NSLog(@"error: view no found");
        return;
    }
    __weak RenderViewXcomponent *weakSelf = self;
    dispatch_async(self.renderQueue, ^{
        __strong RenderViewXcomponent *selfStrong = weakSelf;
        if (!selfStrong) {
            return;
        }
        if (!selfStrong->tContext) {
            BOOL isRes = [selfStrong createContext];
            if (!isRes) {
                NSLog(@"error: create context Failed");
                return;
            }
        }
        __block BOOL isDrawFinish = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            UIGraphicsPushContext(selfStrong->tContext);
            isDrawFinish = [view drawViewHierarchyInRect:
            CGRectMake(0, 0, selfStrong->_renderWidth, selfStrong->_renderHeight)
                                         afterScreenUpdates:NO];
            UIGraphicsPopContext();
        });
        if (!isDrawFinish) {
            NSLog(@"%s error: drawViewHierarchyInRect Failed", __func__);
            return;
        }
        if (selfStrong->_context && [EAGLContext currentContext] != selfStrong->_context) {
            [EAGLContext setCurrentContext:selfStrong->_context];
        }
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,
         selfStrong->_renderWidth, selfStrong->_renderHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, selfStrong->imageData);
    });
}

#pragma mark - dealloc
- (void)dealloc
{
    [self releaseObject];
    NSLog(@"RenderViewXcomponent dealloc");
}

- (void)releaseObject
{
    if (!self.renderQueue) {
        [self destroy];
        return;
    }
    if (dispatch_get_specific(kRenderQueueSpecificKey) == kRenderQueueSpecificKey) {
        [self destroy];
    } else {
        dispatch_sync(self.renderQueue, ^{
            [self destroy];
        });
    }
}

- (void)destroy
{
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
        imageData = NULL;
    }
    [EAGLContext setCurrentContext:nil];
}

- (void)clearBuffer
{
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    if (_frameBuffer) {
        glDeleteFramebuffers(1, &_frameBuffer);
        _frameBuffer = 0;
    }
    if (_renderBuffer) {
        glDeleteRenderbuffers(1, &_renderBuffer);
        _renderBuffer = 0;
    }
}

#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer*)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer*)otherGestureRecognizer
{
    return YES;
}

- (void)handlePan:(UITapGestureRecognizer*)gesture
{
    if (gesture.state == UIGestureRecognizerStateChanged) {
        _isTouchIng = YES;
    } else {
        _isTouchIng = NO;
    }
}
@end
