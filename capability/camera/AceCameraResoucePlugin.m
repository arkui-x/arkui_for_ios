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

#import "AceCameraResoucePlugin.h"
#import "AceTexture.h"
#import "AceCamera.h"
#define KEY_CAMERA_TEXTURE @"texture"


@interface AceCameraResoucePlugin()
@property (nonatomic, strong) NSMutableDictionary<AceCamera *, NSString*> *objectMap;
@end

@implementation AceCameraResoucePlugin

- (instancetype)init{
    self = [super init:@"camera" version:1];
    if (self) {
        self.objectMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)addResource:(int64_t)incId video:(AceCamera *)camera{
    [self.objectMap setObject:camera forKey:[NSString stringWithFormat:@"%lld", incId]];
    [self registerCallMethod:[camera getCallMethod]];
}

- (int64_t)create:(NSDictionary<NSString *,NSString *> *)param{
    
    if (![param valueForKey:KEY_CAMERA_TEXTURE]) {
        return -1;
    }
    NSString *textureId = [param valueForKey:KEY_CAMERA_TEXTURE];
    id obj = [self.resRegister getObject:KEY_CAMERA_TEXTURE incId:textureId];
    if (obj == nil || ![obj isKindOfClass:[AceTexture class]]) {
        return -1;
    }
 
    int64_t incId = [self getAtomicId];
    AceTexture *texture = (AceTexture*)obj;
    AceCamera *aceCamera = [[AceCamera alloc] init:incId onEvent:[self getEventCallback] texture:texture];
    [self addResource:incId video:aceCamera];
    return incId;
}

- (id)getObject:(NSString *)incId{
    return [self.objectMap objectForKey:incId];
}

- (BOOL)release:(NSString *)incId {
    AceCamera *camera = [self.objectMap objectForKey:incId];
    if (camera) {
        [self unregisterCallMethod:[camera getCallMethod]];
        [camera releaseObject];
        [self.objectMap removeObjectForKey:incId];
        return YES;
    }
    return NO;
}

- (void)releaseObject{
    [self.objectMap enumerateKeysAndObjectsUsingBlock:^(AceCamera * _Nonnull camera, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [camera releaseObject];
    }];
    [self.objectMap removeAllObjects];
}

@end
