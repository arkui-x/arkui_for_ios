/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

#import "AceTexture.h"

#define TEXTURE_FLAG    @"texture@"
#define PARAM_AND       @"#HWJS-&-#"
#define PARAM_EQUALS    @"#HWJS-=-#"
#define PARAM_BEGIN     @"#HWJS-?-#"
#define METHOD          @"method"
#define EVENT           @"event"

#define SUCCESS         @"success"
#define FAIL            @"fail"
#define KEY_SOURCE      @"src"
#define KEY_VALUE       @"value"
#define FILE_SCHEME     @"file://"
#define HAP_SCHEME      @"/"

@interface AceTexture()
@property(nonatomic, assign) int64_t textureId;
@property(nonatomic, assign) int32_t instanceId;
@property(nonatomic, copy) IAceOnResourceEvent onEvent;
@property (nonatomic, strong) NSMutableDictionary<NSString*, IAceOnCallSyncResourceMethod>* callMethodMap;
@end

@implementation AceTexture
- (instancetype)initWithEvents:(IAceOnResourceEvent)callback
    textureId:(int64_t)textureId abilityInstanceId:(int32_t)abilityInstanceId
{
    if (self = [super init]) {
        self.onEvent = callback;
        self.textureId = textureId;
        self.instanceId = abilityInstanceId;

        __weak AceTexture* weakSelf = self;
        IAceOnCallSyncResourceMethod callSetTextureSize = ^NSString*(NSDictionary* param) {
            if (weakSelf) {
                return [weakSelf setSurfaceBounds:param];
            }else {
                 NSLog(@"AceSurfaceView: setSurfaceBounds fail");
                 return FAIL;
            }
        };
        [self.callMethodMap setObject:[callSetTextureSize copy] forKey:[self method_hashFormat:@"setTextureBounds"]];
    }
    return self;
}

- (NSDictionary<NSString*, IAceOnCallSyncResourceMethod>*)getCallMethod
{
    return [self.callMethodMap copy];
}

- (void)refreshPixelBuffer
{
    [self markTextureAvailable];
}

- (void)releaseObject
{
    NSLog(@"AceTextureReleaseObject");
    if (self.videoOutput) {
        self.videoOutput = nil;
    }
    if (self.callMethodMap) {
        for (id key in self.callMethodMap) {
            IAceOnCallSyncResourceMethod block = [self.callMethodMap objectForKey:key];
            block = nil;
        }
        [self.callMethodMap removeAllObjects];
        self.callMethodMap = nil;
    }
    self.onEvent = nil;
}

- (void)dealloc
{
    NSLog(@"AceTexture->%@ dealloc", self);
}

- (void)markTextureAvailable
{
    if (self.onEvent) {
        NSString *param = [NSString stringWithFormat:@"instanceId=%lld&textureId=%lld",
            self.instanceId, self.textureId];
        NSString *prepared_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@",
                TEXTURE_FLAG, self.textureId, EVENT, PARAM_EQUALS, @"markTextureAvailable", PARAM_BEGIN];
        self.onEvent(prepared_method_hash, param);
    }
}

- (NSString*)setSurfaceBounds:(NSDictionary*)params
{
    return SUCCESS;
}

- (NSString *)method_hashFormat:(NSString *)method
{
    return [NSString stringWithFormat:@"%@%lld%@%@%@%@",
            TEXTURE_FLAG, self.textureId, METHOD, PARAM_EQUALS, method, PARAM_BEGIN];
}

- (AVPlayerItemVideoOutput *)videoOutput
{
    if(!_videoOutput){
        NSDictionary* pixBuffAttributes = @{
                    (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                    (id)kCVPixelBufferIOSurfacePropertiesKey : @{}
                };
        _videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
    }
    return _videoOutput;
}

- (CVPixelBufferRef)getPixelBuffer
{
    CMTime outputItemTime = [self.videoOutput itemTimeForHostTime:CACurrentMediaTime()];
    if ([self.videoOutput hasNewPixelBufferForItemTime:outputItemTime]) {
        return [self.videoOutput copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
    } else {
        return NULL;
    }
}

@end
