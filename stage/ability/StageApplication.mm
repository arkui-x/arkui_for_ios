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


#include <string>
#include "app_main.h"
#include "stage_application_info_adapter.h"

using AppMain = OHOS::AbilityRuntime::Platform::AppMain;
@implementation StageApplication

#pragma mark - publice
+ (void)configModuleWithBundleDirectory:(NSString *_Nonnull)bundleDirectory {
    NSLog(@"%s bundleDirectory : %@", __func__, bundleDirectory);
    [[StageAssetManager assetManager] moduleFilesWithbundleDirectory:bundleDirectory];
}

+ (void)launchApplication {
    NSLog(@"%s", __FUNCTION__);
    [[StageAssetManager assetManager] launchAbility];
    [[StageConfigurationManager configurationManager] registConfiguration];

    [self setPidAndUid];
    [self setLocale];
}

+ (void)setPidAndUid {
    int pid = [[NSProcessInfo processInfo] processIdentifier];
    int32_t uid = 0;
    NSLog(@"%s pid : %d", __func__, pid);
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

+ (void)callCurrentAbilityOnForeground {
    StageViewController *topVC = [self getApplicationTopViewController];
    NSString *instanceName = topVC.instanceName;
    if (instanceName.length) {
        std::string cppInstanceName = [instanceName UTF8String];
        AppMain::GetInstance()->DispatchOnForeground(cppInstanceName);
    }
    NSLog(@"%s, instanceName : %@", __FUNCTION__, instanceName);
}

+ (void)callCurrentAbilityOnBackground {
    StageViewController *topVC = [self getApplicationTopViewController];
    NSString *instanceName = topVC.instanceName;
    if (instanceName.length) {
        std::string cppInstanceName = [instanceName UTF8String];
        AppMain::GetInstance()->DispatchOnBackground(cppInstanceName);
    }
    NSLog(@"%s, instanceName : %@", __FUNCTION__, instanceName);
}

+ (BOOL)handleSingleton:(NSString *)bundleName moduleName:(NSString *)moduleName abilityName:(NSString *)abilityName {
    bool isSingle = AppMain::GetInstance()->IsSingleton([moduleName UTF8String], [abilityName UTF8String]);
    if (!isSingle) {
        return NO;
    }
    NSString *singleName = [NSString stringWithFormat:@"%@:%@:%@", bundleName, moduleName, abilityName];
    NSLog(@"%s, singleName is %@", __func__, singleName);
    StageViewController *topVC = [self getApplicationTopViewController];
    if ([topVC.instanceName containsString:singleName]) {
        std::string instanceName = [topVC.instanceName UTF8String];
        AppMain::GetInstance()->DispatchOnNewWant(instanceName);
        return YES;
    }

    NSMutableArray *controllerArr = [[NSMutableArray alloc] initWithArray:topVC.navigationController.viewControllers];
    for (int i = 0; i < controllerArr.count; i++) {
        StageViewController *tempVC = controllerArr[i];
        if ([tempVC.instanceName containsString:singleName]) {
            [controllerArr removeObjectAtIndex:i];
            [controllerArr addObject:tempVC];
            [topVC.navigationController setViewControllers:controllerArr.copy];
            std::string instanceName = [tempVC.instanceName UTF8String];
            AppMain::GetInstance()->DispatchOnNewWant(instanceName);
            return YES;
        }
    }
    return NO;
}

+ (void)releaseViewControllers {
    StageViewController *topVC = [self getApplicationTopViewController];
    NSMutableArray *controllerArr = [[NSMutableArray alloc] initWithArray:topVC.navigationController.viewControllers];
    int size = controllerArr.count;
    NSString *instanceName = topVC.instanceName;
    if (instanceName.length) {
        NSLog(@"%s, instanceName : %@", __FUNCTION__, instanceName);
        for (int i = size - 1; i >= 0; i--) {
            StageViewController *tempVC = controllerArr[i];
            std::string cppInstanceName = [tempVC.instanceName UTF8String];
            AppMain::GetInstance()->DispatchOnDestroy(cppInstanceName);
        }
    }
}

+ (StageViewController *)getApplicationTopViewController {
    UIViewController* viewController = [[UIApplication sharedApplication].delegate window].rootViewController;
    return (StageViewController *)[self findTopViewController:viewController];
}

+ (UIViewController *)findTopViewController:(UIViewController*)vc {
    if ([vc isKindOfClass:[UINavigationController class]]) {
        UINavigationController *svc = (UINavigationController*)vc;
        if (svc.viewControllers.count > 0) {
            return [self findTopViewController:svc.topViewController];
        }
        return vc;
    }
    return vc;
}

@end
