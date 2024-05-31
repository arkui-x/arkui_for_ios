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

#import "BridgeBinaryCodec.h"
#import "BridgeSerializer.h"

@implementation BridgeBinaryCodec {
    BridgeSerializer* _serializer;
}

+ (instancetype)sharedInstance {
    static id _sharedInstance = nil;
    if (!_sharedInstance) {
        BridgeSerializer* serializer = [[BridgeSerializer alloc] init];
        _sharedInstance = [BridgeBinaryCodec codecWithSerializer:serializer];
    }
    return _sharedInstance;
}

+ (instancetype)codecWithSerializer:(BridgeSerializer*)serializer {
    return [[BridgeBinaryCodec alloc] initWithSerializer:serializer];
}

- (instancetype)initWithSerializer:(BridgeSerializer*)serializer {
    self = [super init];
    if (self) {
        _serializer = serializer;
    }
    return self;
}

- (id _Nullable)decode:(NSData* _Nullable)message {
    if ([message length] == 0) {
        NSLog(@"BridgeBinaryCodec:: %s meesage nil", __func__);
        return nil;
    }
    BridgeStreamReader* reader = [_serializer readerWithData:message];
    id value = [reader readValue];
    if (![reader isNoMoreData]) {
        NSLog(@"no have more message");
    }
    return value;
}

- (NSData* _Nullable)encode:(id _Nullable)message {
    if (message == nil) {
        NSLog(@"BridgeBinaryCodec:: %s meesage nil", __func__);
        return nil;
    }
    NSMutableData* data = [NSMutableData dataWithCapacity:32];

    BridgeStreamWriter* writer = [_serializer writerWithData:data];
    BOOL success = [writer writeValue:message];
    if (!success){
        return nil;
    }
    return data;
}

- (NSInteger)getBinaryType:(NSData* _Nullable)message {
    BridgeStreamReader* reader = [_serializer readerWithData:message];
    return [reader readUnitByte];
}

@end