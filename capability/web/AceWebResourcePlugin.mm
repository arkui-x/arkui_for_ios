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

#import "AceWebResourcePlugin.h"
#import "AceWeb.h"

#define URL_SRC @"src"
#define PAGE_URL @"pageUrl"

@interface AceWebResourcePlugin()
@property (nonatomic, weak) UIViewController *target;
@property (nonatomic, assign) int32_t instanceId;
@end

@implementation AceWebResourcePlugin
static NSMutableDictionary<NSString*, AceWeb*> *objectMap;
+ (AceWebResourcePlugin *)createRegister:(UIViewController *)target abilityInstanceId:(int32_t)abilityInstanceId
{
    return [[AceWebResourcePlugin alloc] initWithTarget:target abilityInstanceId:abilityInstanceId];
}

- (instancetype)initWithTarget:(UIViewController *)target abilityInstanceId:(int32_t)abilityInstanceId{
    self = [super init:@"web" version:1];
    if (self) {
        objectMap = [[NSMutableDictionary alloc] init];
        self.target = target;
        self.instanceId = abilityInstanceId;
    }
    return self;
}

- (void)addResource:(int64_t)incId web:(AceWeb *)web{
    [objectMap setObject:web forKey:[NSString stringWithFormat:@"%lld", incId]];
    NSDictionary *safeMethodMap = [[web getSyncCallMethod] copy];
    if (!safeMethodMap) {
        return;
    }
    [self registerSyncCallMethod:safeMethodMap];
}

- (int64_t)create:(NSDictionary <NSString *, NSString *> *)param{
    int64_t incId = [self getAtomicId];
    IAceOnResourceEvent callback = [self getEventCallback];
    AceWeb *aceWeb = [[AceWeb alloc] init:incId target:(UIViewController*)self.target onEvent:callback abilityInstanceId:self.instanceId];
    [aceWeb loadUrl:[param valueForKey:URL_SRC] header:[NSMutableDictionary dictionary]];
    [self.target.view insertSubview:aceWeb.getWeb atIndex:0];
    [self addResource:incId web:aceWeb];
    return incId;
}

+ (NSDictionary<NSString*, AceWeb*>*) getObjectMap{
    return objectMap ;
}

- (id)getObject:(NSString *)incId{
    return [objectMap objectForKey:incId];
}

- (BOOL)release:(NSString *)incId{
    NSLog(@"AceWebResourcePlugin %s release inceId: %@",__func__,incId);
    AceWeb *web = [objectMap objectForKey:incId];
    if (web) {
        [self unregisterSyncCallMethod:[web getSyncCallMethod]];
        [web releaseObject];
        [objectMap removeObjectForKey:incId];
        web = nil;
        return YES;
    }
    return NO;
}

- (void)releaseObject{
    NSLog(@"AceWebResourcePlugin %s",__func__);
    if (objectMap) {
        [objectMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, AceWeb * _Nonnull web, BOOL * _Nonnull stop) {
            if (web) {
                @try {
                    [web releaseObject];
                    web = nil;
                } @catch (NSException *exception) {
                    NSLog(@"AceWebResourcePlugin releaseObject releaseObject fail");
                }
            }else {
                NSLog(@"AceWebResourcePlugin releaseObject fail web is null");
            }
        }];
        [objectMap removeAllObjects];
        objectMap = nil;
    }
    self.target = nil;
}

- (void)dealloc
{
    NSLog(@"AceWebResourcePlugin->%@ dealloc", self);
}
@end
