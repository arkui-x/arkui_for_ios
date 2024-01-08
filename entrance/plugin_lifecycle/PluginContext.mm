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

#import "PluginContext.h"

@interface PluginContext () {
    BridgePluginManager *_bridgePluginManager;
}
@end

@implementation PluginContext

- (instancetype)initPluginContext:(BridgePluginManager *)bridgePluginManager {
    if (self = [super init]) {
        _bridgePluginManager = bridgePluginManager;
    }
    return self;
}

- (BridgePluginManager *)getBridgePluginManager {
    return _bridgePluginManager;
}
@end

