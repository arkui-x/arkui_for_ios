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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_RESOURCE_ACERESOURCEREGISTEROC_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_RESOURCE_ACERESOURCEREGISTEROC_H

#import <Foundation/Foundation.h>

#import "AceResourcePlugin.h"
#import "IAceOnCallResourceMethod.h"
#import "IAceOnResourceEvent.h"

NS_ASSUME_NONNULL_BEGIN

@protocol IAceOnCallEvent <NSObject>
@required
- (void)onEvent:(NSString *)eventId param:(NSString *)param; 

@end

@interface AceResourceRegisterOC : NSObject

@property (nonatomic, weak) id<IAceOnCallEvent> parent;
@property (nonatomic, copy) IAceOnResourceEvent callbackHandler;

- (instancetype)initWithParent:(id<IAceOnCallEvent>)parent;

- (void)registerSyncCallMethod:(NSString *)methodId
                callMethod:(IAceOnCallSyncResourceMethod)callMethod;

- (void)unregisterSyncCallMethod:(NSString *)methodId;


- (void)registerPlugin:(AceResourcePlugin *)plugin;

- (int64_t)createResource:(NSString *)resourceType
                    param:(NSString *)param;

- (id)getObject:(NSString *)resourceHash;

- (id)getObject:(NSString *)resourceType incId:(int64_t)incId;

- (NSString *)onCallMethod:(NSString *)methodId param:(NSString *)param;

- (void)notifyLifecycleChanged:(BOOL)isBackground;

- (BOOL)releaseObject:(NSString *)resourceHash;

- (BOOL)releaseObject;

@end

NS_ASSUME_NONNULL_END

#endif // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_RESOURCE_ACERESOURCEREGISTEROC_H