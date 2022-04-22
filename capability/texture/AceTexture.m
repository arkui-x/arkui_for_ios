//
//  AceTexture.m
//  sources
//
//  Created by wuhuanlong 吴焕隆 on 2022/3/24.
//

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
    [self.textures_ unregisterTexture:self.incId];
    self.textureRef = nil;
}

- (void)markTextureFrameAvailable{
    NSString *param = @"";
    NSString *prepared_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", TEXTURE_FLAG, self.incId, EVENT, PARAM_EQUALS, @"markTextureFrameAvailable", PARAM_BEGIN];
    self.onEvent(prepared_method_hash, param);
    [self.textures_ textureFrameAvailable:self.incId];
}

@end
