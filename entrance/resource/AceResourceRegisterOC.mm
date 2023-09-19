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

#import "AceResourceRegisterOC.h"

#define PARAM_AND @"#HWJS-&-#"
#define PARMA_EQUALS @"#HWJS-=-#"
#define PARAM_AT @"@"

@interface AceResourceRegisterOC () <AceResourceRegisterDelegate>

@property (nonatomic, strong) NSMapTable<NSString*, AceResourcePlugin *> *pluginMap;
@property (nonatomic, strong) NSMutableDictionary<NSString*, IAceOnCallSyncResourceMethod> *callSyncMethodMap;

@end

@implementation AceResourceRegisterOC
- (instancetype)initWithParent:(id<IAceOnCallEvent>)parent
{
    if (self = [super init]) {
        self.parent = parent;
        self.pluginMap = [NSMapTable mapTableWithKeyOptions:NSMapTableCopyIn valueOptions:NSMapTableStrongMemory];
       	self.callSyncMethodMap = [NSMutableDictionary dictionary];
 
        __weak __typeof(&*self) weakSelf = self;
        self.callbackHandler = ^(NSString* eventId, NSString* param){
            if (weakSelf.parent) {
                [weakSelf.parent onEvent:eventId param:param];
            }
        };
    }
    
    return self;
}

- (void)registerSyncCallMethod:(NSString *)methodId
                callMethod:(IAceOnCallSyncResourceMethod)callMethod
{
    if (callMethod != nil) {
        NSLog(@"registerSyncCallMethod:%@ key:%@",callMethod,methodId);
        [self.callSyncMethodMap setObject:callMethod forKey:methodId];
    }else {
        NSLog(@"registerSyncCallMethod fail methodId:%@",methodId);
    }
}

- (void)unregisterSyncCallMethod:(NSString *)methodId
{
     [self.callSyncMethodMap removeObjectForKey:methodId];
}

- (void)registerPlugin:(AceResourcePlugin *)plugin{
    if (plugin == NULL) {
        return;
    }

    AceResourcePlugin *oldPlugin = [self.pluginMap objectForKey:plugin.tag];
    if (oldPlugin) {
        if (plugin.version <= oldPlugin.version) {
            return;
        }
        oldPlugin = nil;
    }
    [plugin setEventCallback:self.callbackHandler];
    [self.pluginMap setObject:plugin forKey:plugin.tag];
}

- (int64_t)createResource:(NSString *)resourceType param:(NSString *)param
{
    AceResourcePlugin *plugin = [self.pluginMap objectForKey:resourceType];
    if (plugin) {
        __weak __typeof(&*self) weakSelf = self;
        plugin.resRegister = weakSelf;
        return [plugin create:[self buildParamMap:param]];
    }
    return -1;
}

- (NSDictionary *)buildParamMap:(NSString *)param
{
    NSMutableDictionary *paramMap = [NSMutableDictionary dictionary];
    
    NSArray<NSString *> *paramSplit = [param componentsSeparatedByString:PARAM_AND];
    [paramSplit enumerateObjectsUsingBlock:^(NSString * _Nonnull pa, NSUInteger idx, BOOL * _Nonnull stop) {
        NSArray<NSString *> *valueSplit = [pa componentsSeparatedByString:PARMA_EQUALS];
        if (valueSplit.count == 2) {
            [paramMap setObject:valueSplit[1] forKey:valueSplit[0]];
        }
    }];
    
    return paramMap;
}

- (id)getObject:(NSString *)resourceHash
{
    NSArray<NSString *> *split = [resourceHash componentsSeparatedByString:PARAM_AT];
    if (split.count == 2) {
        return [self getObject:split[0] incId:[split[1] longLongValue]];
    }
    return nil;
}

- (id)getObject:(NSString *)resourceType incId:(int64_t)incId
{
    AceResourcePlugin *plugin = [self.pluginMap objectForKey:resourceType];
    if (plugin) {
        return [plugin getObject:incId];
    }
    return nil;
}

- (NSString *)onCallMethod:(NSString *)methodId param:(NSString *)param
{
    NSLog(@"AceResourcePlugin methodId  %@ --- %@",methodId,param);
    IAceOnCallSyncResourceMethod resourceMethod = [self.callSyncMethodMap objectForKey:methodId];
    if (resourceMethod) {
        return resourceMethod([self buildParamMap:param]);
    }

    return @"no method found";
}

- (void)notifyLifecycleChanged:(BOOL)isBackground
{
    if (self.pluginMap) {
        NSEnumerator *plugins = [self.pluginMap objectEnumerator];
        id obj;
        while ((obj = [plugins nextObject])) {
            if ([obj isKindOfClass:[AceResourcePlugin class]]) {
                AceResourcePlugin *plugin = (AceResourcePlugin *)obj;
                if (plugin) {
                    [plugin notifyLifecycleChanged:isBackground];
                }
            }
        }
    }
}

- (BOOL)releaseObject:(NSString *)resourceHash
{
    NSArray <NSString *> *split = [resourceHash componentsSeparatedByString:PARAM_AT];
    if (split.count == 2 && self.pluginMap) {
        AceResourcePlugin *plugin = [self.pluginMap objectForKey:split[0]];
        if (plugin) {
            BOOL releaseResult = [plugin release:[NSString stringWithFormat:@"%lld", [split[1] longLongValue]]];
            return releaseResult;
        }
     }

    return NO;
}

- (BOOL)releaseObject
{
    if (self.pluginMap) {
        NSEnumerator *plugins = [self.pluginMap objectEnumerator];
        AceResourcePlugin *plugin;
        while ((plugin = [plugins nextObject])) {
            if (plugin) {
                 @try { 
                    [plugin releaseObject];
                    plugin = nil;
                 } @catch (NSException *exception) { 

                 }
            }
        }
    }
    self.pluginMap = nil;
    if (self.callSyncMethodMap) {
        [self.callSyncMethodMap removeAllObjects];
    }
    self.callSyncMethodMap = nil;

    return YES;
}

- (void)dealloc
{
    NSLog(@"AceResourceRegisterOC dealloc");
}
@end
