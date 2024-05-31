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

#import "AceSurfacePlugin.h"
#import "AceSurfaceView.h"

@interface AceSurfacePlugin()
@property (nonatomic, strong) NSMutableDictionary<NSString*, AceSurfaceView*> *objectMap;
@property (nonatomic, assign) UIViewController *target;
@property (nonatomic, assign) int32_t instanceId;
@end
@implementation AceSurfacePlugin

+ (AceSurfacePlugin *)createRegister:(UIViewController *)target abilityInstanceId:(int32_t)abilityInstanceId
{
    return [[AceSurfacePlugin alloc] initWithTarget:target abilityInstanceId:abilityInstanceId];
}

- (instancetype)initWithTarget:(UIViewController *)target abilityInstanceId:(int32_t)abilityInstanceId
{
    self = [super init:@"surface" version:1];
    if (self) {
        self.objectMap = [[NSMutableDictionary alloc] init];
        self.target = target;
        self.instanceId = abilityInstanceId;
    }
    return self;
}

- (void)addResource:(int64_t)incId surface:(AceSurfaceView *)surfaceView
{
    [self.objectMap setObject:surfaceView forKey:[NSString stringWithFormat:@"%lld", incId]];
    NSDictionary * callMethod = [surfaceView getCallMethod];
    [self registerSyncCallMethod:callMethod];
}

- (int64_t)create:(NSDictionary<NSString *, NSString *> *)param
{
    int64_t incId = [self getAtomicId];
    NSLog(@"AceSurfacePlugin create incId %lld",incId);
    IAceOnResourceEvent callback = [self getEventCallback];
    if (!callback) {
         return -1L;
    }
    AceSurfaceView * aceSurface = [[AceSurfaceView alloc] 
        initWithId:incId callback:callback param:param superTarget:self.target abilityInstanceId:self.instanceId];
    [self addResource:incId surface:aceSurface];
    return incId;
}

- (id)getObject:(int64_t)incId
{
    return [self.objectMap objectForKey:[NSString stringWithFormat:@"%lld", incId]];
}

- (BOOL)release:(NSString *)incId
{
    if([self.objectMap.allKeys containsObject:incId]) {
        AceSurfaceView *aceSurface = [self.objectMap objectForKey:incId];
        if (aceSurface) {
            [aceSurface releaseObject];
            [aceSurface removeFromSuperview];
            aceSurface = nil;
            [self.objectMap removeObjectForKey:incId];
            return YES;
        }
    }
    return NO;
}

- (void)releaseObject
{
    NSLog(@"AceSurfacePlugin %s",__func__);
    if (self.objectMap) { 
        [self.objectMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, 
        AceSurfaceView *_Nonnull aceSurface, BOOL * _Nonnull stop) {
            if (aceSurface) {
                [aceSurface releaseObject];
                [aceSurface removeFromSuperview];
                aceSurface = nil;
            }else {
                NSLog(@"AceSurfacePlugin releaseObject fail aceSurface is null"); 
            }
        }];
        [self.objectMap removeAllObjects];
        self.objectMap = nil;
    }
    self.target = nil;
}

- (void)dealloc
{
    NSLog(@"AceSurfacePlugin->%@ dealloc", self);
}

@end
