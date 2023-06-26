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

#import "AceResourcePlugin.h"

@interface AceResourcePlugin()

@property (atomic, assign) int64_t nextVideoId;

@end

@implementation AceResourcePlugin

- (instancetype)init:(NSString *)tag version:(int64_t)version {
    if (self = [super init]) {
        self.tag = tag;
        self.version = version;
        self.nextVideoId = 0;
        self.resRegister = nil;
    }
    return self;
}

- (int64_t)getAtomicId{
    return ++self.nextVideoId;
}

- (int64_t)getcId {
    return self.nextVideoId;  
}


- (void)setEventCallback:(IAceOnResourceEvent)callback {
    self.callback = callback;
}

- (IAceOnResourceEvent)getEventCallback{
    return self.callback;
}

- (void)registerSyncCallMethod:(NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *)methodMap{
    @synchronized (self) {
        if (!self.resRegister || !methodMap) {
            return;
        }
        for (NSString *key in [methodMap allKeys]) {
            IAceOnCallSyncResourceMethod callback = methodMap[key];
            [self.resRegister registerSyncCallMethod:key callMethod:callback];
        }
    }
}

- (void)unregisterSyncCallMethod:(NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *)methodMap{
    @synchronized (self) {
        if (self.resRegister == nil || methodMap == nil) {
            return;
        }

        [methodMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, IAceOnCallSyncResourceMethod  _Nonnull callback, BOOL * _Nonnull stop) {
            [self.resRegister unregisterSyncCallMethod:key];
        }];
    }

}

- (void)notifyLifecycleChanged:(BOOL)isBackground
{
}

@end
