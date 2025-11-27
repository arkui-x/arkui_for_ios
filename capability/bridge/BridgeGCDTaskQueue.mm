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
#import "BridgeGCDTaskQueue.h"

static const char* BRIDGE_TASK_QUEUE_NAME = "com.example.bridgeGCDTaskQueue";

@interface BridgeGCDTaskQueue ()

@end

@implementation BridgeGCDTaskQueue

+ (instancetype)sharedInstance
{
    static BridgeGCDTaskQueue *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BridgeGCDTaskQueue alloc] init];
    });
    return instance;
}

- (dispatch_queue_t)gcdQueue
{
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create(BRIDGE_TASK_QUEUE_NAME, DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

- (void)gcdDispatchAsync:(dispatch_block_t)block
{
    if (!block) {
        NSLog(@"[BridgeGCDTaskQueue] skip enqueue nil block");
        return;
    }
    dispatch_queue_t queue = [self gcdQueue];
    dispatch_async(queue, block);
}
@end