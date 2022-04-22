//
//  AceTextureResourcePlugin.m
//  libAceDemo
//
//  Created by wuhuanlong 吴焕隆 on 2022/3/17.
//

#import "AceTextureResourcePlugin.h"
#import "AceTexture.h"

#define KEY_TEXTURE @"texture"

@interface AceTextureResourcePlugin()

@property (nonatomic, strong) NSMutableDictionary<AceTexture *, NSString*> *objectMap;

@property (nonatomic, strong) NSObject<FlutterTextureRegistry> *_textures;
@end

@implementation AceTextureResourcePlugin

- (instancetype)initWithTextures:(NSObject<FlutterTextureRegistry> *)textures
{
    self = [super init:@"texture" version:1];
    if (self) {
        self._textures = textures;
        self.objectMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (int64_t)create:(NSDictionary<NSString *, NSString *> *)param{
    AceTexture *texture = [[AceTexture alloc] initWithRegister:self._textures onEvent:[self getEventCallback]];
    int64_t textureId = [self._textures registerTexture:(NSObject<FlutterTexture> *)texture];
    texture.incId = textureId;
    [self.objectMap setObject:texture forKey:[NSString stringWithFormat:@"%lld", textureId]];
    return textureId;
}

- (id)getObject:(NSString *)incId{
    return [self.objectMap objectForKey:incId];
}

- (BOOL)release:(NSString *)incId {
    AceTexture *texture = [self.objectMap objectForKey:incId];
    if (texture) {
        [texture releaseObject];
        [self.objectMap removeObjectForKey:incId];
        return YES;
    }
    return NO;
}

- (void)releaseObject{
    [self.objectMap enumerateKeysAndObjectsUsingBlock:^(AceTexture * _Nonnull texture, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [texture releaseObject];
    }];
    [self.objectMap removeAllObjects];
}


@end
