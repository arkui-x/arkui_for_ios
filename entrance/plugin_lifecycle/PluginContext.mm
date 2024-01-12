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
#import "StageAssetManager.h"

@interface PluginContext () {
    BridgePluginManager *_bridgePluginManager;
    NSString *_moduleName;
}
@end

@implementation PluginContext

- (instancetype)initPluginContext:(BridgePluginManager *)bridgePluginManager moduleName:(NSString *)moduleName {
    if (self = [super init]) {
        _bridgePluginManager = bridgePluginManager;
        _moduleName = moduleName;
    }
    return self;
}

- (BridgePluginManager *)getBridgePluginManager {
    return _bridgePluginManager;
}

- (NSString *)getRawFilePath:(NSString *)name filePath:(NSString *)filePath {
    NSString *path = nil;
    path = [NSString stringWithFormat:@"%@/Documents/files/arkui-x/%@/resources/rawfile/%@", NSHomeDirectory(), name, filePath];
    NSFileManager *manager = [NSFileManager defaultManager];
    bool flag = [manager fileExistsAtPath:path];
    if (!flag) {
        return nil;
    }
    return path;
}

- (NSString *)getRawFilePath:(NSString *)filePath {
    NSString *bundlePath = [[StageAssetManager assetManager] getBundlePath];
    NSString *path = nil;
    path = [NSString stringWithFormat:@"%@/%@/resources/rawfile/%@", bundlePath, _moduleName, filePath];
    NSFileManager *manager = [NSFileManager defaultManager];
    bool flag = [manager fileExistsAtPath:path];
    if (!flag) {
        return nil;
    }
    return path;
}

@end