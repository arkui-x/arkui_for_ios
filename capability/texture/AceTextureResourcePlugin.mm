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

#import "AceTextureResourcePlugin.h"
#import "AceTextureHolder.h"
#import "AceTexture.h"

@interface AceTextureResourcePlugin()
@property (nonatomic, strong) NSMutableDictionary<NSString*, AceTexture*> *objectMap;
@property (nonatomic, assign) int32_t instanceId;

@end

@implementation AceTextureResourcePlugin

 + (AceTextureResourcePlugin *)createTexturePluginWithInstanceId:(int32_t)instanceId
 {
    return [[AceTextureResourcePlugin alloc] initTextureWithInstanceId:instanceId];
}

- (instancetype)initTextureWithInstanceId:(int32_t)instanceId
{
    self = [super init:@"texture" version:1];
    if (self) {
        self.objectMap = [NSMutableDictionary dictionary];
        self.instanceId = instanceId;
    }
    return self;
}

- (void)addResource:(int64_t)textureId texture:(AceTexture *)texture
{
    [self.objectMap setObject:texture forKey:[NSString stringWithFormat:@"%lld", textureId]];
    NSDictionary * callMethod = [texture getCallMethod];
    [self registerSyncCallMethod:callMethod];
    [self.delegate registerSurfaceWithInstanceId:self.instanceId textureId:textureId
        textureObject:(__bridge void*)texture.videoOutput];
    [AceTextureHolder addTexture:texture withId:textureId inceId:self.instanceId];
}

- (int64_t)create:(NSDictionary<NSString *, NSString *> *)param
{
    NSLog(@"AceTextureCreate");
    int64_t textureId = [self getAtomicId];
    IAceOnResourceEvent callback = [self getEventCallback];
    if (!callback) {
        return -1L;
    }
    AceTexture *texture = [[AceTexture alloc] initWithEvents:callback textureId:textureId
    abilityInstanceId:self.instanceId];
    [self addResource:textureId texture:texture];

    return textureId;
}

- (id)getObject:(NSString *)incId
{
    return [self.objectMap objectForKey:incId];
}

- (BOOL)release:(NSString *)incId
{
    NSLog(@"AceTextResourcePlugin %s release inceId: %@",__func__,incId);
    AceTexture *texture = [self.objectMap objectForKey:incId];
    if (texture) {
        [self unregisterSyncCallMethod:[texture getCallMethod]];
        [texture releaseObject];
        [self.objectMap removeObjectForKey:incId];
        [AceTextureHolder removeTextureWithId:[incId intValue] inceId:self.instanceId];
        [self.delegate unregisterSurfaceWithInstanceId:self.instanceId textureId:[incId intValue]];
        texture = nil;
        return YES;
    }
    return NO;
}

- (void)releaseObject
{
    NSLog(@"AceTextResourcePlugin releaseObjectStart"); 
    if (self.objectMap) {
        [self.objectMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key,
            AceTexture *_Nonnull texture, BOOL * _Nonnull stop) {
            if (texture) {
                [texture releaseObject];
                texture = nil;
            }else {
                NSLog(@"AceSurfacePlugin releaseObject fail aceSurface is null");
            }
        }];
        [self.objectMap removeAllObjects];
        self.objectMap = nil;
    }
}

- (void)dealloc
{
    NSLog(@"AceTextureResourcePlugin->%@ dealloc", self);
}
@end
