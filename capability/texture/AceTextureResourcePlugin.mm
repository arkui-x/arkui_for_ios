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

#import "AceTextureResourcePlugin.h"
#import "AceTexture.h"

#define KEY_TEXTURE @"texture"

@interface AceTextureResourcePlugin()

@property (nonatomic, retain) NSMutableDictionary<NSString*, AceTexture*> *objectMap;

@property (nonatomic, assign) NSObject<FlutterTextureRegistry> *_textures;
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
    if (self._textures) {
        int64_t textureId = [self._textures registerTexture:(NSObject<FlutterTexture> *)texture];
        texture.incId = textureId;
        [self.objectMap setObject:texture forKey:[NSString stringWithFormat:@"%lld", textureId]];
        return textureId;
    }
    
    return -1;
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
    [self.objectMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, AceTexture *_Nonnull texture, BOOL * _Nonnull stop) {
        [texture releaseObject];
    }];
    [self.objectMap removeAllObjects];
}


@end
