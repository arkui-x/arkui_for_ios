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

#ifndef FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_BRIDGETASKINFO_H
#define FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_BRIDGETASKINFO_H

#import <Foundation/Foundation.h>

#import "BridgeTaskQueue.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^BridgeTaskHandler)(void);

typedef enum : int {
    INPUT,//js call native
    OUTPUT,//native call js
} QueueInOutType;

@interface BridgeTaskInfo : NSObject
@property (nonatomic, copy) NSString* bridgeName;
@property (nonatomic, copy) BridgeTaskHandler handler;
@property (nonatomic, assign) QueueInOutType inOutType;

+ (BridgeTaskInfo*)bridgeTaskInfoFactory:(NSString*)bridgeName
        queueInOutType:(QueueInOutType)inOutType
        handler:(BridgeTaskHandler)handler;
@end

NS_ASSUME_NONNULL_END

#endif // FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_BRIDGETASKINFO_H
