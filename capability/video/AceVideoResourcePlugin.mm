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
@property (nonatomic, weak) NSString* bundleDirectory;

@end

@implementation AceVideoResourcePlugin

- (instancetype)initWithBundleDirectory:(NSString *)bundleDirectory{
    self = [super init:@"video" version:1];

    if (self) {
        self.bundleDirectory = bundleDirectory;
        self.objectMap = [NSMutableDictionary dictionary];
    }

    return self;
}

- (void)addResource:(int64_t)incId video:(AceVideo *)video{
    [self.objectMap setObject:video forKey:[NSString stringWithFormat:@"%lld", incId]];
    [self registerSyncCallMethod:[video getSyncCallMethod]];
}

- (int64_t)create:(NSDictionary<NSString *,NSString *> *)param{
    
    if (![param valueForKey:KEY_TEXTURE]) {
        return -1;
    }
    NSString *textureId = [param valueForKey:KEY_TEXTURE];
    id obj = [self.resRegister getObject:KEY_TEXTURE incId:[textureId longLongValue]];
    if (obj == nil || ![obj isKindOfClass:[AceTexture class]]) {
        return -1;
    }
 
    int64_t incId = [self getAtomicId];
    AceTexture *texture = (AceTexture*)obj;
    AceVideo *aceVide = [[AceVideo alloc] init:incId bundleDirectory:self.bundleDirectory onEvent:[self getEventCallback] texture:texture]; 
    [self addResource:incId video:aceVide];
    
    return incId;
}

- (id)getObject:(NSString *)incId{
    return [self.objectMap objectForKey:incId];
}

- (BOOL)release:(NSString *)incId {
    AceVideo *video = [self.objectMap objectForKey:incId];
    if (video) {
        [self unregisterSyncCallMethod:[video getSyncCallMethod]];
        [video releaseObject];
        [self.objectMap removeObjectForKey:incId];
        return YES;
    }
    return NO;
}

- (void)releaseObject{
    [self.objectMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, AceVideo * _Nonnull video, BOOL * _Nonnull stop) {
        [video releaseObject];
    }];
    [self.objectMap removeAllObjects];
}

@end