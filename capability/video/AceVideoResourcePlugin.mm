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

#import "AceVideoResourcePlugin.h"
#import "AceVideo.h"
#import "AceTexture.h"

#define KEY_TEXTURE @"texture"

@interface AceVideoResourcePlugin()

@property (nonatomic, strong) NSMutableDictionary<NSString*, AceVideo*> *objectMap;
@property (nonatomic, copy) NSString* moudleName;
@property (nonatomic, assign) int32_t instanceId;

@end

@implementation AceVideoResourcePlugin

+ (AceVideoResourcePlugin *)createRegister:(NSString *)moudleName abilityInstanceId:(int32_t)abilityInstanceId
{
    return [[AceVideoResourcePlugin alloc] initWithMoudleName:moudleName abilityInstanceId:abilityInstanceId];
}

- (instancetype)initWithMoudleName:(NSString *)moudleName abilityInstanceId:(int32_t)abilityInstanceId
{
    self = [super init:@"video" version:1];

    if (self) {
        self.moudleName = moudleName;
        self.objectMap = [[NSMutableDictionary alloc] init];
        self.instanceId = abilityInstanceId;
    }

    return self;
}

- (void)addResource:(int64_t)incId video:(AceVideo *)video
{
    [self.objectMap setObject:video forKey:[NSString stringWithFormat:@"%lld", incId]];
    NSDictionary *safeMethodMap = [[video getSyncCallMethod] copy];
    if (!safeMethodMap) {
        return;
    }
    [self registerSyncCallMethod:safeMethodMap];
}

- (int64_t)create:(NSDictionary <NSString *, NSString *> *)param
{
    if (![param valueForKey:KEY_TEXTURE]) {
        return -1;
    }
    int64_t incId = [self getAtomicId];
    IAceOnResourceEvent callback = [self getEventCallback];
    if (!callback) {
         return -1L;
    }
    AceVideo *aceVideo = [[AceVideo alloc] init:incId moudleName:self.moudleName
            onEvent:callback texture:nil abilityInstanceId:self.instanceId];
    [self addResource:incId video:aceVideo];
    return incId;
}

- (id)getObject:(NSString *)incId
{
    return [self.objectMap objectForKey:incId];
}

- (void)notifyLifecycleChanged:(BOOL)isBackground
{
    [self.objectMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key,
            AceVideo * _Nonnull video, BOOL * _Nonnull stop) {
        if (video) {
            if (isBackground) {
                [video onActivityPause];
            }else {
                [video onActivityResume];
            }
        }
    }];
}

- (BOOL)release:(NSString *)incId
{
    NSLog(@"AceVideoResourcePlugin %s release inceId: %@",__func__,incId);
    AceVideo *video = [self.objectMap objectForKey:incId];
    if (video) {
        [self unregisterSyncCallMethod:[video getSyncCallMethod]];
        [video releaseObject];
        [self.objectMap removeObjectForKey:incId];
        video = nil;
        return YES;
    }
    return NO;
}

- (void)releaseObject
{
    NSLog(@"AceVideoResourcePluginReleaseObject %s",__func__);
    if (self.objectMap) {
        [self.objectMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key,
            AceVideo * _Nonnull video, BOOL * _Nonnull stop) {
            if (video) {
                @try {
                    [video releaseObject];
                    video = nil;
                } @catch (NSException *exception) {
                    NSLog(@"AceVideoResourcePlugin releaseObject releaseObject fail");
                }
            }else {
                NSLog(@"AceVideoResourcePlugin releaseObject fail video is null");
            }
        }];
        [self.objectMap removeAllObjects];
        self.objectMap = nil;
    }
}

- (void)dealloc
{
    NSLog(@"AceVideoResourcePlugin->%@ dealloc", self);
}
@end
