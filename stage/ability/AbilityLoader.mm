/*
 * Copyright (c) 2025-2025 Huawei Device Co., Ltd.
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

 #import "AbilityLoader.h"
 #include "app_main.h"

 using AppMain = OHOS::AbilityRuntime::Platform::AppMain;
 static NSString* const ABILITY_LOADER_INSTANCE_ID = @"100000";

 @implementation AbilityLoader

+ (void)loadAbility:(NSString *)bundleName moduleName:(NSString *)moduleName
            abilityName:(NSString *)abilityName params:(NSString *)params {
    if (bundleName == NULL || bundleName.length == 0) {
        NSLog(@"load ability error: bundleName is invalid.");
        return;
    }
    if (moduleName == NULL || moduleName.length == 0) {
        NSLog(@"load ability error: moduleName is invalid.");
        return;
    }
    if (abilityName == NULL || abilityName.length == 0) {
        NSLog(@"load ability error: abilityName is invalid.");
        return;
    }
    NSString* instanceName = [NSString stringWithFormat:@"%@:%@:%@:%@", bundleName, moduleName, abilityName, ABILITY_LOADER_INSTANCE_ID];
    if (params == NULL) {
        params = @"";
    }
    [self nativeDispatchOnCreate:instanceName params:params];
}

+ (void)unloadAbility:(NSString *)bundleName moduleName:(NSString *)moduleName
            abilityName:(NSString *)abilityName {
    if (bundleName == NULL || bundleName.length == 0) {
        NSLog(@"unload ability error: bundleName is invalid.");
        return;
    }
    if (moduleName == NULL || moduleName.length == 0) {
        NSLog(@"unload ability error: moduleName is invalid.");
        return;
    }
    if (abilityName == NULL || abilityName.length == 0) {
        NSLog(@"unload ability error: abilityName is invalid.");
        return;
    }
    NSString* instanceName = [NSString stringWithFormat:@"%@:%@:%@:%@", bundleName, moduleName, abilityName, ABILITY_LOADER_INSTANCE_ID];
    [self nativeDispatchOnDestroy:instanceName];
}

+ (void)nativeDispatchOnCreate:(NSString *)instanceName params:(NSString *)params {
    AppMain::GetInstance()->DispatchOnCreate(instanceName.UTF8String, params.UTF8String);
}

+ (void)nativeDispatchOnDestroy:(NSString *)instanceName {
    AppMain::GetInstance()->DispatchOnDestroy(instanceName.UTF8String);
}

@end