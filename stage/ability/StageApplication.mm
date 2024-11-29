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
    [self setPidAndUid];
    [self setLocale];
    [[StageAssetManager assetManager] launchAbility];
    [[StageConfigurationManager configurationManager] registConfiguration];
    [self startAbilityDelegator];
}

+ (void)startAbilityDelegator { 
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSArray *arguments = processInfo.arguments;
    @try {
        if (arguments) {
            if ([arguments containsObject:@"test"]) {
                NSString *bundleName = [NSString new];
                NSString *moduleName = [NSString new];
                NSString *unittest = [NSString new];
                NSString *timeout = [NSString new];
                for (int i = 1; i < arguments.count; i++) {
                    if ([arguments[i] isEqualToString:@"bundleName"]) {
                        if (arguments.count >= i+1) {
                            bundleName = arguments[i+1];
                        }
                    } else if ([arguments[i] isEqualToString:@"moduleName"]) {
                        if (arguments.count >= i+1) {
                            moduleName = arguments[i+1];
                        }
                    } else if ([arguments[i] isEqualToString:@"unittest"]) {
                        if (arguments.count >= i+1) {
                            unittest = arguments[i+1];
                        }
                    } else if ([arguments[i] isEqualToString:@"timeout"]) {
                        if (arguments.count >= i+1) {
                            timeout = arguments[i+1];
                        }
                    }
                }
                std::string bundleNameString = [bundleName UTF8String];
                std::string moduleNameString = [moduleName UTF8String];
                std::string unittestString = [unittest UTF8String];
                std::string timeoutString = [timeout UTF8String];
                AppMain::GetInstance()->PrepareAbilityDelegator(bundleNameString, moduleNameString, unittestString, timeoutString);
            } else {
                NSLog(@"%s, No need to start creating abilityDelegate", __FUNCTION__);
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"NSException %@",exception);
    } @finally {
        NSLog(@"%s, failed . arguments is %@", __FUNCTION__, arguments);
    }
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

+ (void)setLocaleWithLanguage:(NSString *)language country:(NSString *)country script:(NSString *)script {
    std::string languageString = "";
    std::string countryString = "";
    std::string scriptString = "";
    if (language.length) {
        languageString = [language UTF8String];
    }
    if (country.length) {
        countryString = [country UTF8String];
    }
    if (script.length) {
        scriptString = [script UTF8String];
    }
    OHOS::AbilityRuntime::Platform::StageApplicationInfoAdapter::GetInstance()->SetLocale(languageString,
        countryString, scriptString);
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
    StageViewController *topVC = [StageApplication getApplicationTopViewController];
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
    return (StageViewController *)[StageApplication findTopViewController:viewController];
}

+ (UIViewController *)findTopViewController:(UIViewController*)topViewController {
    while (true) {
        if (topViewController.presentedViewController) {
            topViewController = topViewController.presentedViewController;
        } else if ([topViewController isKindOfClass:[UINavigationController class]]
                    && [(UINavigationController*)topViewController topViewController]) {
            topViewController = [(UINavigationController *)topViewController topViewController];
        } else if ([topViewController isKindOfClass:[UITabBarController class]]) {
            UITabBarController *tab = (UITabBarController *)topViewController;
            topViewController = tab.selectedViewController;
        } else {
            break;
        }
    }
    return topViewController;
}

- (NSString *)getTopAbility {
    StageViewController *topViewController = [StageApplication getApplicationTopViewController];
    NSMutableArray *viewControllers = [NSMutableArray arrayWithArray:topViewController.navigationController.viewControllers];
    NSMutableArray *controllerArray = [[NSMutableArray alloc]init];
    for (UIViewController *vc in viewControllers) {
        if ([vc isKindOfClass:[StageViewController class]]){
            StageViewController *tvc = (StageViewController *)vc;
            [controllerArray addObject:tvc];
        }
    }
    if (controllerArray.count == 0) {
        return @"current views is null";
    }
    StageViewController *tvc = controllerArray.lastObject;
    return tvc.instanceName;
}

- (void)doAbilityForeground:(NSString *)fullname {
    int index = 0;
    StageViewController *topViewController = [StageApplication getApplicationTopViewController];
    NSMutableArray *viewControllers = [NSMutableArray arrayWithArray:topViewController.navigationController.viewControllers];
    if (viewControllers.count <= 1) {
        return;
    }
    for (int i = 0; i < viewControllers.count; i++) {
        UIViewController *view = viewControllers[i];
        if ([view isKindOfClass:[StageViewController class]]) {
            StageViewController *currentVC = (StageViewController *)view;
            if ([currentVC.instanceName isEqualToString:fullname]) {
                index = i;
                break;
            }
        }
    }
    [viewControllers exchangeObjectAtIndex:index withObjectAtIndex:viewControllers.count - 1];
    [topViewController.navigationController setViewControllers:viewControllers.copy];
}


- (void)doAbilityBackground:(NSString *)fullname {
    StageViewController *topViewController = [StageApplication getApplicationTopViewController];
    NSMutableArray *viewControllers = [NSMutableArray arrayWithArray:topViewController.navigationController.viewControllers];
    if (viewControllers.count <= 1) {
        return;
    }
    [viewControllers exchangeObjectAtIndex:viewControllers.count - 1 withObjectAtIndex:viewControllers.count - 2];
    [topViewController.navigationController setViewControllers:viewControllers.copy];
}

- (void)print:(NSString *)msg {
    if (msg.length >= 1000) {
        NSLog(@"print: The total length of the message exceed 1000 characters.");
    } else {
        NSLog(@"print: %@",msg);
    }
}

- (void)printSync:(NSString *)msg {
    if (msg.length >= 1000) {
        NSLog(@"printSync: The total length of the message exceed 1000 characters.");
    } else {
        NSLog(@"printSync: %@",msg);
    }
}

- (int)finishTest {
    NSLog(@"TestFinished-ResultMsg: your test finished!!!");
    int error = 0;
    @try {
       exit(0);
    } @catch (NSException *exception) {
        NSLog(@"TestFinished-ResultMsg: %@",exception);
        error = 1;
    } @finally {
        return error;
    }
}

@end
