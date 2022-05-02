/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
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

#import "AceCamera.h"

#import <AVFoundation/AVFoundation.h>
#import <libkern/OSAtomic.h>

#define CAMERA_FLAG   @"camera@"
#define PARAM_AND       @"#HWJS-&-#"
#define PARAM_EQUALS    @"#HWJS-=-#"
#define PARAM_BEGIN     @"#HWJS-?-#"
#define METHOD          @"method"
#define EVENT           @"event"

#define SUCCESS         @"success"
#define FAIL            @"fail"

@interface AceCamera()<AceTextureDelegate>

@property(nonatomic, assign) int64_t incId;
@property (nonatomic, strong) AceTexture *renderTexture;
@property(nonatomic, strong) NSDictionary<NSString *, IAceOnCallResourceMethod> *callMethodMap;
@property(nonatomic, copy) IAceOnResourceEvent onEvent;

#pragma mark - AvCaptureSession
@property(readonly, nonatomic) AVCaptureSession *captureSession;
@property(readonly, nonatomic) AVCaptureDevice *captureDevice;
@property(readonly, nonatomic) AVCaptureInput *captureVideoInput;
@property(readonly) CVPixelBufferRef volatile latestPixelBuffer;
@property(readonly, nonatomic) AVCaptureVideoDataOutput *captureVideoOutput;
@property(readonly, nonatomic) CGSize previewSize;

@end

@implementation AceCamera

FourCharCode const videoFormat = kCVPixelFormatType_32BGRA;

- (instancetype)init:(int64_t)incId onEvent:(IAceOnResourceEvent)callback texture:(AceTexture *)texture{
    if (self = [super init]) {
        self.incId = incId;
        self.onEvent = callback;
        self.renderTexture = texture;
        self.callMethodMap = [NSMutableDictionary dictionary];
        self.renderTexture.delegate = self;
        
        // init callback
        NSMutableDictionary *callMethodMap = [NSMutableDictionary dictionary];
        NSString *init_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", CAMERA_FLAG, self.incId, METHOD, PARAM_EQUALS, @"openCamera", PARAM_BEGIN];
        IAceOnCallResourceMethod init_callback = ^NSString *(NSDictionary * param){
            NSLog(@"vailcamera->AceCamera init->openCamera %@", param);
            [self setupCapture];
            return SUCCESS;
        };
        [callMethodMap setObject:init_callback forKey:init_method_hash];
        
        // setPreViewSize callback
        NSString *previewsize_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", CAMERA_FLAG, self.incId, METHOD, PARAM_EQUALS, @"setPreViewSize", PARAM_BEGIN];
        IAceOnCallResourceMethod previewsize_callback = ^NSString *(NSDictionary * param){
            NSString *restr = [NSString stringWithFormat:@"preViewSizeWidth=%fpreViewSizeHeight=%f",_previewSize.width,_previewSize.height];
            NSLog(@"vailcamera->AceCamera setPreViewSize->restr %@",restr);
            return restr;
        };
        [callMethodMap setObject:previewsize_callback forKey:previewsize_method_hash];
        self.callMethodMap = [callMethodMap copy];
    }
    return self;
}

- (NSDictionary<NSString *, IAceOnCallResourceMethod> *)getCallMethod{
    return self.callMethodMap;
}

- (void)releaseObject{
    
}

#pragma mark - AvCaptureSession
-(void)setupCapture{
    NSString *cameraName = @"";
    if (@available(iOS 10.0, *)) {
        AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession
                                                             discoverySessionWithDeviceTypes:@[ AVCaptureDeviceTypeBuiltInWideAngleCamera ]
                                                             mediaType:AVMediaTypeVideo
                                                             position:AVCaptureDevicePositionUnspecified];
        NSArray<AVCaptureDevice *> *devices = discoverySession.devices;
        NSMutableArray<NSDictionary<NSString *, NSObject *> *> *reply =
        [[NSMutableArray alloc] initWithCapacity:devices.count];
        for (AVCaptureDevice *device in devices) {
            if([device position] == AVCaptureDevicePositionBack){
                cameraName = [device uniqueID];
                break;
            }
        }
    }
    
    if(cameraName.length<=0){
        return;
    }
    
    _captureSession = [[AVCaptureSession alloc] init];
    _captureDevice = [AVCaptureDevice deviceWithUniqueID:cameraName];
    NSError *localError = nil;
    _captureVideoInput = [AVCaptureDeviceInput deviceInputWithDevice:_captureDevice error:&localError];
    if (localError) {
        return;
    }
    
    _captureVideoOutput = [AVCaptureVideoDataOutput new];
    _captureVideoOutput.videoSettings =
        @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @(videoFormat)};
    [_captureVideoOutput setAlwaysDiscardsLateVideoFrames:YES];
    [_captureVideoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    AVCaptureConnection *connection =
        [AVCaptureConnection connectionWithInputPorts:_captureVideoInput.ports
                                               output:_captureVideoOutput];
    if ([_captureDevice position] == AVCaptureDevicePositionFront) {
      connection.videoMirrored = YES;
    }
    connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    [_captureSession addInputWithNoConnections:_captureVideoInput];
    [_captureSession addOutputWithNoConnections:_captureVideoOutput];
    [_captureSession addConnection:connection];

    _captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    _previewSize = CGSizeMake(640, 480);
    NSLog(@"vailcamera->AceCamera setPreViewSize width %f,height %f",_previewSize.width,_previewSize.height);
    [self startRunCapture];
    
    NSString *param = @"";
    NSString *prepared_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", CAMERA_FLAG, self.incId, EVENT, PARAM_EQUALS, @"onPrepare", PARAM_BEGIN];
    self.onEvent(prepared_method_hash, param);
    
}

-(void)startRunCapture{
    [_captureSession startRunning];
}

- (void)captureOutput:(AVCaptureOutput *)output
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
           fromConnection:(AVCaptureConnection *)connection {
  if (output == _captureVideoOutput) {
      
    CVPixelBufferRef newBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFRetain(newBuffer);
    CVPixelBufferRef old = _latestPixelBuffer;
    
    while (!OSAtomicCompareAndSwapPtrBarrier(old, newBuffer, (void **)&_latestPixelBuffer)) {
      old = _latestPixelBuffer;
    }
      
    if (old != nil) {
      CFRelease(old);
    }
  
    [self.renderTexture markTextureFrameAvailable];
  }
}


- (CVPixelBufferRef _Nullable)getPixelBuffer {
  CVPixelBufferRef pixelBuffer = _latestPixelBuffer;
  while (!OSAtomicCompareAndSwapPtrBarrier(pixelBuffer, nil, (void **)&_latestPixelBuffer)) {
    pixelBuffer = _latestPixelBuffer;
  }
  return pixelBuffer;
}



@end
