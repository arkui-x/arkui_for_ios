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

#import "StageApplication.h"
#import "StageAssetManager.h"
#import "StageConfigurationManager.h"

#include "app_main.h"
#include "stage_application_info_adapter.h"

@implementation StageApplication

#pragma mark - publice
+ (void)configModuleWithBundleDirectory:(NSString *_Nonnull)bundleDirectory {
    NSLog(@"%s bundleDirectory : %@", __func__, bundleDirectory);
    [[StageAssetManager assetManager] moduleFilesWithbundleDirectory:bundleDirectory];
}

+ (void)launchApplication {
    [self setPidAndUid];
    [self setLocale];
    [[StageAssetManager assetManager] launchAbility];
    [[StageConfigurationManager configurationManager] initConfiguration];
}

+ (void)setPidAndUid {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    int32_t pid = processInfo.processIdentifier;
    int32_t uid = 0;
    OHOS::AbilityRuntime::Platform::AppMain::GetInstance()->SetPidAndUid(pid, uid);
}

+ (void)setLocale {
    NSString *localeLanguageCode = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"][0];
    NSArray *array = [localeLanguageCode componentsSeparatedByString:@"-"];
    std::string language = "";
    std::string country = "";
    std::string script = "";
    if (array.count == 2) {
        language = [array[0] UTF8String];
        country = [array[1] UTF8String];
    } else if (array.count == 3) {
        language = [array[0] UTF8String];
        country = [array[2] UTF8String];
        script = [array[1] UTF8String];
    }
    OHOS::AbilityRuntime::Platform::StageApplicationInfoAdapter::GetInstance()->SetLocale(language, country, script);
}
@end
