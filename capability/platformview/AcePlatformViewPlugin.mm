/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

#import "AcePlatformViewPlugin.h"
#import "AcePlatformView.h"

#define KEY_VIEWTAG @"viewTag"

@interface AcePlatformViewPlugin()
@property (nonatomic, assign) NSObject<PlatformViewFactory> *platformViewFactory;

@property (nonatomic, copy) NSString* moudleName;
@property (nonatomic, assign) int32_t instanceId;

@end

@implementation AcePlatformViewPlugin
static NSMutableDictionary<NSString*, AcePlatformView*> *objectMap;

+ (AcePlatformViewPlugin *)createRegister:(NSString *)moudleName abilityInstanceId:(int32_t)abilityInstanceId
{
    return [[AcePlatformViewPlugin alloc] initWithMoudleName:moudleName abilityInstanceId:abilityInstanceId];
}

- (instancetype)initWithMoudleName:(NSString *)moudleName abilityInstanceId:(int32_t)abilityInstanceId
{
    self = [super init:@"platformview" version:1];

    if (self) {
        self.moudleName = moudleName;
        objectMap = [[NSMutableDictionary alloc] init];
        self.instanceId = abilityInstanceId;
        self.platformViewFactory = nil;
    }
    return self;
}

- (void)addResource:(int64_t)incId platformView:(AcePlatformView *)platformView
{
    [objectMap setObject:platformView forKey:[NSString stringWithFormat:@"%lld", incId]];
    NSDictionary *safeMethodMap = [[platformView getSyncCallMethod] copy];
    if (!safeMethodMap) {
        return;
    }
    [self registerSyncCallMethod:safeMethodMap];
    if (!platformView) {
        NSLog(@"AcePlatformViewPlugin: platformView is null.");
        return;
    }
}

- (int64_t)create:(NSDictionary <NSString *, NSString *> *)param
{
    NSString* viewtag = [param valueForKey:KEY_VIEWTAG];
    if (!viewtag) {
        NSLog(@"AcePlatformViewPlugin: -1.");
        return -1;
    }
    int64_t incId = [self getAtomicId];
    IAceOnResourceEvent callback = [self getEventCallback];
    if (!callback) {
         return -1L;
    }

    AcePlatformView *aceViews = [[AcePlatformView alloc] initWithEvents:callback id:incId
            abilityInstanceId:self.instanceId viewdelegate:self.delegate];
    if (self.platformViewFactory) {
        NSObject<IPlatformView>* platformView = [self.platformViewFactory getPlatformView:viewtag];
        [aceViews setPlatformView:platformView];
        [self addResource:incId platformView:aceViews];
    }
    return incId;
}

- (id)getObject:(NSString *)incId
{
    return [objectMap objectForKey:incId];
}

+ (NSDictionary<NSString*, AcePlatformView*>*) getObjectMap
{
    return objectMap;
}

- (void)notifyLifecycleChanged:(BOOL)isBackground
{
    [objectMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key,
            AcePlatformView * _Nonnull view, BOOL * _Nonnull stop) {
        if (view) {
            if (isBackground) {
                [view onActivityPause];
            } else {
                [view onActivityResume];
            }
        }
    }];
}

- (BOOL)release:(NSString *)incId
{
    AcePlatformView *view = [objectMap objectForKey:incId];
    if (view) {
        [self unregisterSyncCallMethod:[view getSyncCallMethod]];
        [view releaseObject];
        [objectMap removeObjectForKey:incId];
        view = nil;
        return YES;
    }
    return NO;
}

- (void)releaseObject
{
    if (objectMap) {
        [objectMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key,
            AcePlatformView * _Nonnull view, BOOL * _Nonnull stop) {
            if (view) {
                @try {
                    [view releaseObject];
                    view = nil;
                } @catch (NSException *exception) {
                    NSLog(@"AcePlatformViewPlugin releaseObject releaseObject fail");
                }
            } else {
                NSLog(@"AcePlatformViewPlugin releaseObject fail platformView is null");
            }
        }];
        [objectMap removeAllObjects];
        objectMap = nil;
    }
}

- (void)dealloc
{
    NSLog(@"AcePlatformViewPlugin->%@ dealloc", self);
}

- (void)registerPlatformViewFactory:(NSObject<PlatformViewFactory> *)platformViewFactory{
    self.platformViewFactory = platformViewFactory;
}

@end
