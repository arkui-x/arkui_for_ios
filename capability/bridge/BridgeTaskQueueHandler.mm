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

#import "BridgeTaskQueueHandler.h"

#import "BridgeTaskQueue.h"

static const NSString* BRIDGE_TASK_QUEUE_NAME = @"BridgeTaskQueue";

@implementation BridgeTaskQueueHandler

- (void)dispatchTaskInfo:(BridgeTaskInfo*)taskInfo {
    if (!taskInfo) {
        NSLog(@"BridgeTaskQueueHandler taskInfo is null");
        return;
    }
    BridgeTaskHandler handler = taskInfo.handler;
    if (!handler){
        return;
    }
    
    BridgeTaskQueue* taskQueue;
    if (taskInfo.inOutType == INPUT) {
        if (!self.inputTaskQueue) {
            self.inputTaskQueue = 
                [self createQueueWithName:[NSString stringWithFormat:@"Input%@", taskInfo.bridgeName]];
        }
        taskQueue = self.inputTaskQueue;
    } else {
        if (!self.outputTaskQueue) {
            self.outputTaskQueue = 
                [self createQueueWithName:[NSString stringWithFormat:@"Output%@", taskInfo.bridgeName]];
        }
        taskQueue = self.outputTaskQueue;
    }
 
    if (!taskQueue) {
        return;
    }
    [taskQueue dispatch:handler];
}

- (BridgeTaskQueue*)createQueueWithName:(NSString*)name {
    NSString* queueName = [NSString stringWithFormat:@"%@%@", BRIDGE_TASK_QUEUE_NAME, name];
    return [[BridgeTaskQueue alloc] initWithQueueName:queueName isSerial:self.isSerial];
}

@end
