/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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
#ifndef FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_GCDTASKQUEUE_H
#define FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_GCDTASKQUEUE_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BridgeGCDTaskQueue : NSObject

+ (instancetype)sharedInstance;
- (void)gcdDispatchAsync:(dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
#endif // FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_GCDTASKQUEUE_H