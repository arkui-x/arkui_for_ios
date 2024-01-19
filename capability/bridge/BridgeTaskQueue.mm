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
    NSLog(@"[Bridge Queue] dealloc");
}

- (void)dispatch:(dispatch_block_t)block {
    NSBlockOperation* operation = [NSBlockOperation blockOperationWithBlock:block];
    // __weak BridgeTaskQueue* weakSelf = self;
    // [operation setCompletionBlock:^{
    //     [weakSelf printQueueLog];
    // }];
    [self.queue addOperation:operation];
}

- (void)printQueueLog {
    if (!_queue) {
        NSLog(@"queue is null");
        return;
    }
    NSLog(@"----------[Bridge Queue] dump:----------");
    NSLog(@"[Bridge Queue] name: %@",  _queue.name);
    // NSLog(@"[Bridge Queue] Max Concurrent Operations: %ld", _queue.maxConcurrentOperationCount);
    // NSLog(@"[Bridge Queue] Operation Count: %ld", _queue.operationCount);
    // NSLog(@"[Bridge Queue] Suspended: %@", _queue.isSuspended ? @"YES" : @"NO");
    NSLog(@"[Bridge Queue] TreadInfo: %@", [NSThread currentThread]);

    // NSArray<NSOperation*>* operations = [_queue operations];
    // for (NSOperation* operation in operations) {
    //     NSLog(@"[Bridge Queue] Operation Queue Priority: %ld", operation.queuePriority);
    // }
}

@end


