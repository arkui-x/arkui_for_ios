/*
 * Copyright (c) 2023-2025 Huawei Device Co., Ltd.
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
#include "AceXcomponentTextureView.h"
#import "AceTextureHolder.h"
#import "AceTexture.h"
#import "AceTextureDelegate.h"
#import "AcePlatformViewDelegate.h"
#import "IAceSurface.h"

@class UIViewController;

static const NSInteger TEXTURETYPE_PLATFORMVIEW = 0;
static const NSInteger TEXTURETYPE_XCOMPONENT = 1;

@interface AceTextureResourcePlugin()
@property (nonatomic, strong) NSMutableDictionary<NSString*, AceTexture*> *objectMap;
@property (nonatomic, strong) NSMutableDictionary<NSString*, AceXcomponentTextureView*> *textureViewMap;
@property (nonatomic, assign) int32_t instanceId;
@property (nonatomic, weak) UIViewController *target;
@end

@implementation AceTextureResourcePlugin

+ (AceTextureResourcePlugin *)createTexturePluginWithTarget:(UIViewController *)target instanceId:(int32_t)instanceId
{
    return [[AceTextureResourcePlugin alloc] initTextureWithTarget:target instanceId:instanceId];
}

- (instancetype)initTextureWithTarget:(UIViewController *)target instanceId:(int32_t)instanceId
{
    self = [super init:@"texture" version:1];
    if (self) {
        self.objectMap = [NSMutableDictionary dictionary];
        self.textureViewMap = [NSMutableDictionary dictionary];
        self.instanceId = instanceId;
        if (target) {
            self.target = target;
        }
    }
    return self;
}

- (void)addResource:(int64_t)textureId texture:(AceTexture *)texture type:(NSInteger)type
{
    [self.objectMap setObject:texture forKey:[NSString stringWithFormat:@"%lld", textureId]];
    NSDictionary *callMethod = [texture getCallMethod];
    [self registerSyncCallMethod:callMethod];
    // This section is only effective for platform views; it does not apply to other cases.
    if (type == TEXTURETYPE_PLATFORMVIEW) {
        [self.delegate registerSurfaceWithInstanceId:self.instanceId textureId:textureId 
        textureObject:(__bridge void*)texture.videoOutput];
    }
    [AceTextureHolder addTexture:texture withId:textureId inceId:self.instanceId];
}

- (int64_t)create:(NSDictionary<NSString *, NSString *> *)param
{
    NSLog(@"AceTextureCreate %@", param);
    int64_t textureId = [self getAtomicId];
    IAceOnResourceEvent callback = [self getEventCallback];
    if (!callback) {
        return -1L;
    }
    NSInteger type = TEXTURETYPE_PLATFORMVIEW;
    if (param && param[@"type"]) {
        type = [param[@"type"] integerValue];
    }
    AceTexture *texture = [[AceTexture alloc] initWithEvents:callback textureId:textureId
    abilityInstanceId:self.instanceId];
    [self addResource:textureId texture:texture type:type];
    if (type == TEXTURETYPE_XCOMPONENT) {
        AceXcomponentTextureView *textureView = [[AceXcomponentTextureView alloc] initWithId:textureId instanceId:self.instanceId
        callback:callback param:param superTarget:self.target viewdelegate:self.platformViewDelegate 
        surfaceDelegate:self.surfaceDelegate];
        [self.textureViewMap setObject:textureView forKey:[NSString stringWithFormat:@"%lld", textureId]];
        NSDictionary * callMethod = [textureView getCallMethod];
        [self registerSyncCallMethod:callMethod];
    }
    return textureId;
}

- (id)getObject:(NSString *)incId
{
    return [self.objectMap objectForKey:incId];
}

- (BOOL)release:(NSString *)incId
{
    NSLog(@"AceTextResourcePlugin %s release inceId: %@", __func__,incId);
    AceTexture *texture = [self.objectMap objectForKey:incId];
    AceXcomponentTextureView *textureView = [self.textureViewMap objectForKey:incId];
    if (textureView) {
        [self unregisterSyncCallMethod:[textureView getCallMethod]];
        [textureView releaseObject];
        [self.textureViewMap removeObjectForKey:incId];
        textureView = nil;
    }
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
            } else {
                NSLog(@"AceSurfacePlugin releaseObject fail aceSurface is null");
            }
        }];
        [self.objectMap removeAllObjects];
        self.objectMap = nil;
    }
    if (self.textureViewMap) {
        [self.textureViewMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key,
            AceXcomponentTextureView *_Nonnull textureView, BOOL * _Nonnull stop) {
            if (textureView) {
                [textureView releaseObject];
                textureView = nil;
            } else {
                NSLog(@"AceSurfacePlugin releaseObject fail aceSurfaceView is null");
            }
        }];
        [self.textureViewMap removeAllObjects];
        self.textureViewMap = nil;
    }
}

- (void)dealloc
{
    NSLog(@"AceTextureResourcePlugin->%@ dealloc", self);
}
@end
