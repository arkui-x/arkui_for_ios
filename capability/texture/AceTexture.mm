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

#import "AceTexture.h"
#import "FlutterTexture.h"

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
#define SECOND_TO_MSEC  (1000)

@interface AceTexture()<FlutterTexture>

@property(nonatomic, copy) IAceOnResourceEvent onEvent;

@property (nonatomic) CVPixelBufferRef textureRef;

@property (nonatomic, strong) NSObject<FlutterTextureRegistry> *textures_;

@end

@implementation AceTexture
- (instancetype)initWithRegister:(NSObject<FlutterTextureRegistry> *)textures onEvent:(IAceOnResourceEvent)callback{
    if (self = [super init]) {
        self.textures_ = textures; 
        self.onEvent = callback;
    }
    return self;
}

- (CVPixelBufferRef _Nullable)copyPixelBuffer{
    if (self.delegate && [self.delegate respondsToSelector:@selector(getPixelBuffer)]) {
        return [self.delegate getPixelBuffer];
    }
    return self.textureRef;
}

- (void)releaseObject{
    if (self.textures_) {
        [self.textures_ unregisterTexture:self.incId];
    }
    
    self.textureRef = nil;
}

- (void)markTextureFrameAvailable{
    
    if (self.onEvent) {
        NSString *param = @"";
        NSString *prepared_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", TEXTURE_FLAG, self.incId, EVENT, PARAM_EQUALS, @"markTextureFrameAvailable", PARAM_BEGIN];
        self.onEvent(prepared_method_hash, param);
    }
    
    [self.textures_ textureFrameAvailable:self.incId];
}

@end
