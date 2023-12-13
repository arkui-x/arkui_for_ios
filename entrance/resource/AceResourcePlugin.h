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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_RESOURCE_ACERESOURCEPLUGIN_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_RESOURCE_ACERESOURCEPLUGIN_H

#import <Foundation/Foundation.h>

#import "AceResourceRegisterDelegate.h"
#import "IAceOnResourceEvent.h"
#import "IAceOnCallResourceMethod.h"

NS_ASSUME_NONNULL_BEGIN

@interface AceResourcePlugin : NSObject

@property (nonatomic, weak) id<AceResourceRegisterDelegate> resRegister;

@property (nonatomic, assign) int64_t version;

@property (nonatomic, copy) NSString* tag;

@property (nonatomic, copy) IAceOnResourceEvent callback;

- (instancetype)init:(NSString *)tag version:(int64_t)version;

- (int64_t)getAtomicId;

- (int64_t)getcId;

- (void)addResource:(int64_t)incId obj:(id)obj;

- (IAceOnResourceEvent)getEventCallback;

- (void)setEventCallback:(IAceOnResourceEvent)callback;

- (id)getObject:(int64_t)incId;

- (int64_t)create:(NSDictionary <NSString *, NSString *> *)param;

- (BOOL)release:(NSString *)incId;

- (void)releaseObject;

- (void)registerSyncCallMethod:(NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *)methodMap;

- (void)unregisterSyncCallMethod:(NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *)methodMap;

- (void)notifyLifecycleChanged:(BOOL)isBackground;

@end

NS_ASSUME_NONNULL_END

#endif // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_RESOURCE_ACERESOURCEPLUGIN_H