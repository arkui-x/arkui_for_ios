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
#define BUFFERS_SIZE 2
#define CONTEXT_BUFFER_MAX 1
#define POSITIONATTRIB_SIZE 3
#define TEXCOORDATTRIB_SIZE 2
#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @STRINGIZE2(text)

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
    EAGLContext* _context;
    GLuint _texture;
    GLuint _frameBuffer;
    GLuint _renderBuffer;
    GLint _renderWidth;
    GLint _renderHeight;
    CGContextRef tContexts[BUFFERS_SIZE];
    void* imageDatas[BUFFERS_SIZE];
    dispatch_queue_t renderQueue;
    UIPanGestureRecognizer* panGesture;
    int currentBufferIndex;
}

@property (strong, nonatomic) RenderProgram* program;
@end

@implementation RenderViewXcomponent

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        _texture = -1;
    }
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
    [self setTextureBackground];
}

- (void)setTextureBackground
{
    int space = self.bounds.size.width * self.bounds.size.height * DATA_SIZE;
    if (space <= 0) {
        return;
    }
    void* bufferData = malloc(space);
    if (bufferData == NULL) {
        NSLog(@"%s error: malloc bufferData failed", __func__);
        return;
    }
    errno_t result = memset_s(bufferData, space, 0x00, space);
    if (result != 0) {
        free(bufferData);
        bufferData = NULL;
        NSLog(@"%s error: memset_s failed", __func__);
        return;
    }
    if ([EAGLContext currentContext] != _context) {
        [EAGLContext setCurrentContext:_context];
    }
    glBindTexture(GL_TEXTURE_2D, _texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, self.bounds.size.width, self.bounds.size.height, 0, GL_RGBA,
        GL_UNSIGNED_BYTE, bufferData);
    free(bufferData);
    bufferData = NULL;
}

- (void)initXComponent:(UIView*)view
{
    if (self) {
        if (!renderQueue) {
            NSString* strQueue = [NSString stringWithFormat:@"com.renderView.queue.%d", _texture];
            renderQueue = dispatch_queue_create([strQueue UTF8String], DISPATCH_QUEUE_SERIAL);
        }
        _isTouchIng = NO;
        currentBufferIndex = 0;
        CAEAGLLayer* calayer = (CAEAGLLayer*)self.layer;
        calayer.opaque = YES;
        calayer.contentsScale = [UIScreen mainScreen].scale;
        calayer.drawableProperties =
            [NSDictionary dictionaryWithObjectsAndKeys:@(NO), kEAGLDrawablePropertyRetainedBacking,
                          kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];

        [self setupBuffer];
        [self setupShaders];
        if (!panGesture) {
            panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                 action:@selector(handlePan:)];
            panGesture.cancelsTouchesInView = NO;
            panGesture.delaysTouchesBegan = NO;
            panGesture.delaysTouchesEnded = NO;
            [self.superview addGestureRecognizer:panGesture];
        }
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
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
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

- (bool)createContext:(int)index
{
    if (tContexts[index]) {
        CGContextRelease(tContexts[index]);
        tContexts[index] = nil;
    }
    int spaceRow = _renderWidth * DATA_SIZE;
    int space = spaceRow * _renderHeight;
    if (_renderWidth <= 0 || _renderHeight <= 0 || space <= 0) {
        return false;
    }
    if (imageDatas[index]) {
        free(imageDatas[index]);
        imageDatas[index] = NULL;
    }
    if (imageDatas[index] == NULL) {
        imageDatas[index] = malloc(space);
        if (imageDatas[index] == NULL) {
            NSLog(@"%s error: malloc imageDatas failed", __func__);
            return false;
        }
        errno_t result = memset_s(imageDatas[index], space, 0x00, space);
        if (result != 0) {
            NSLog(@"%s error: memset_s failed", __func__);
        }
    }
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    tContexts[index] = CGBitmapContextCreate(imageDatas[index], _renderWidth, _renderHeight, COLOR_NUMBER, spaceRow, colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    CGContextTranslateCTM(tContexts[index], 0, _renderHeight);
    CGContextScaleCTM(tContexts[index], 1, -1);
    return true;
}

- (void)exchangeBind {}

- (void)startRenderXComponent:(UIView*)view
{
    if (!view || !renderQueue) {
        NSLog(@"error: view no found");
        return;
    }
    if (!tContexts[currentBufferIndex]) {
        if (![self createContext:currentBufferIndex]) {
            NSLog(@"error: create context Failed");
            return;
        }
    }
    UIGraphicsPushContext(tContexts[currentBufferIndex]);
    BOOL isDrawFinish = [view drawViewHierarchyInRect:CGRectMake(0, 0, _renderWidth, _renderHeight)
                                   afterScreenUpdates:NO];
    UIGraphicsPopContext();
    if (!isDrawFinish) {
        NSLog(@"error: drawViewHierarchyInRect Failed");
        return;
    }
    int updateindex = currentBufferIndex;
    currentBufferIndex = CONTEXT_BUFFER_MAX - currentBufferIndex;
    __weak RenderViewXcomponent* weakSelf = self;
    dispatch_async(renderQueue, ^{
        __strong RenderViewXcomponent* selfStrong = weakSelf;
        if (!selfStrong || !selfStrong->_context) {
            return;
        }
        if ([EAGLContext currentContext] != selfStrong->_context) {
            [EAGLContext setCurrentContext:selfStrong->_context];
        }
        glBindTexture(GL_TEXTURE_2D, selfStrong->_texture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, selfStrong->_renderWidth, selfStrong->_renderHeight, 0, GL_RGBA,
            GL_UNSIGNED_BYTE, selfStrong->imageDatas[updateindex]);
    });
}

#pragma mark - dealloc
- (void)dealloc
{
    if (renderQueue) {
#if !OS_OBJECT_USE_OBJC
        dispatch_release(renderQueue);
#endif
        renderQueue = NULL;
    }
    [self destroy];
    CAEAGLLayer* layer = (CAEAGLLayer*)self.layer;
    layer.contents = nil;
    layer.delegate = nil;
}

- (void)releaseObject
{
    [self destroy];
}

- (void)destroy
{
    if (panGesture) {
        [self.superview removeGestureRecognizer:panGesture];
        panGesture = nil;
    }
    if (_context && [EAGLContext currentContext] != _context) {
        [EAGLContext setCurrentContext:_context];
    }
    [self clearBuffer];
    if (self.program && self.program != nil) {
        [self.program destroy];
        self.program = nil;
    }
    if (_context) {
        _context = nil;
    }
    for (int i = 0; i < BUFFERS_SIZE; i++) {
        if (tContexts[i]) {
            CGContextRelease(tContexts[i]);
            tContexts[i] = nil;
        }
        if (imageDatas[i] != NULL) {
            free(imageDatas[i]);
            imageDatas[i] = NULL;
        }
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

- (void)handlePan:(UIPanGestureRecognizer*)gesture
{
    if (gesture.state == UIGestureRecognizerStateChanged) {
        _isTouchIng = YES;
    } else {
        _isTouchIng = NO;
    }
}
@end
