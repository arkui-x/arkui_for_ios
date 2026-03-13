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
#import "BridgeTaskQueue.h"
#include "base/log/log.h"

@interface BridgeTaskQueue()
@property (nonatomic, strong) NSOperationQueue* queue;
@end

@implementation BridgeTaskQueue

- (instancetype)initWithQueueName:(NSString*)queueName {
    return [[BridgeTaskQueue alloc] initWithQueueName:queueName isSerial:false];
}

- (instancetype)initWithQueueName:(NSString*)queueName isSerial:(BOOL)isSerial {
    self = [super init];
    if (self) {
        _queue = [[NSOperationQueue alloc] init];
        _queue.name = queueName;
        if (isSerial) {
            _queue.maxConcurrentOperationCount = 1;
        }
    }
    return self;
}

- (void)dealloc {
    LOGI("[Bridge Queue] dealloc");
}

- (void)dispatch:(dispatch_block_t)block {
    NSBlockOperation* operation = [NSBlockOperation blockOperationWithBlock:block];
    [self.queue addOperation:operation];
}

- (void)printQueueLog {
    if (!_queue) {
        LOGE("queue is null");
        return;
    }
    LOGI("----------[Bridge Queue] dump:----------");
    LOGI("[Bridge Queue] name: %{public}s", _queue.name.UTF8String);
    LOGI("[Bridge Queue] TreadInfo: %{public}s", [[NSThread currentThread] description].UTF8String);
}

@end


