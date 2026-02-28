/*
 * Copyright (c) 2023-2025 Huawei Device Co., Ltd.
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
#include <objc/objc.h>
#import "StageAssetManager.h"
#import "StageConfigurationManager.h"

#import "Logger.h"
#include <string>
#include "app_main.h"
#include "stage_application_info_adapter.h"

using AppMain = OHOS::AbilityRuntime::Platform::AppMain;
static NSString* const kEtsPathRegexPattern = @"^\\./ets/([^/]+/)*[^/]+$";

@implementation StageApplication

#pragma mark - publice
+ (void)configModuleWithBundleDirectory:(NSString *_Nonnull)bundleDirectory {
    LOGI("%{public}s bundleDirectory : %{public}s", __func__, [bundleDirectory UTF8String]);
    [[StageAssetManager assetManager] moduleFilesWithbundleDirectory:bundleDirectory];
    OHOS::AbilityRuntime::Platform::AppMain::GetInstance()->SetResourceFilePrefixPath();
}

+ (void)launchApplication {
    LOGI("%{public}s", __FUNCTION__);
    [self initApplication:YES];
}

+ (void)launchApplicationWithoutUI {
    LOGI("%{public}s", __FUNCTION__);
    [self initApplication:NO];
}

+ (void)initApplication:(BOOL)isLoadArkUI {
    [self setPidAndUid];
    [self setLocale];
    [self setupNotificationCenterObservers];
    [[StageAssetManager assetManager] launchAbility:isLoadArkUI];
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
                LOGI("%{public}s, No need to start creating abilityDelegate", __FUNCTION__);
            }
        }
    } @catch (NSException *exception) {
        //to do
        LOGE("NSException");
    } @finally {
        //to do
        LOGE("%{public}s, failed .", __FUNCTION__);
    }
}

+ (void)setupNotificationCenterObservers {
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];

    [center addObserver:self
               selector:@selector(DispatchApplicationOnBackground:)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];

    [center addObserver:self
               selector:@selector(DispatchApplicationOnForeground:)
                   name:UIApplicationWillEnterForegroundNotification
                 object:nil];
}

+ (void)DispatchApplicationOnForeground:(NSNotification *)notification {
    AppMain::GetInstance()->NotifyApplicationForeground();
}

+ (void)DispatchApplicationOnBackground:(NSNotification *)notification {
    AppMain::GetInstance()->NotifyApplicationBackground();
}

+ (void)setPidAndUid {
    int pid = [[NSProcessInfo processInfo] processIdentifier];
    int32_t uid = 0;
    LOGI("%{public}s pid : %{public}d", __func__, pid);
    OHOS::AbilityRuntime::Platform::AppMain::GetInstance()->SetPidAndUid(pid, uid);
}

+ (void)setLocale {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *customLanguages = [defaults objectForKey:@"ArkuiXApplePreferredLanguages"];
    NSString *currentLanguage;
    if (customLanguages && customLanguages.length != 0) {
        currentLanguage = customLanguages;
    } else {
        currentLanguage = [[NSLocale preferredLanguages] objectAtIndex:0];
    }

    NSArray *array = [currentLanguage componentsSeparatedByString:@"-"];
    std::string language = "";
    std::string country = "";
    std::string script = "";

    if ([currentLanguage hasPrefix:@"zh-Hans"]) {
        language = "zh";
        country = "CN";
        script = "Hans";
    } else if ([currentLanguage hasPrefix:@"zh-HK"] || [currentLanguage hasPrefix:@"zh-Hant-HK"]) {
        language = "zh";
        country = "HK";
        script = "Hant";
    } else if ([currentLanguage hasPrefix:@"zh-TW"] || [currentLanguage hasPrefix:@"zh-Hant"]) {
        language = "zh";
        country = "TW";
        script = "Hant";
    } else if (array.count == 1) {
        language = [array[0] UTF8String];
    } else if (array.count == 2) {
        language = [array[0] UTF8String];
        country = [array[1] UTF8String];
    } else if (array.count == 3) {
        language = [array[0] UTF8String];
        country = [array[2] UTF8String];
        script = [array[1] UTF8String];
    }
    LOGI("%{public}s, language : %{public}s, country : %{public}s script : %{public}s",
        __FUNCTION__, language.c_str(), country.c_str(), script.c_str());
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
    if (![topVC isKindOfClass:[StageViewController class]]) {
        LOGI("callCurrentAbilityOnForeground is Not StageVC");
        return;
    }
    NSString *instanceName = topVC.instanceName;
    if (instanceName.length) {
        std::string cppInstanceName = [instanceName UTF8String];
        AppMain::GetInstance()->DispatchOnForeground(cppInstanceName);
    }
    LOGI("%{public}s, instanceName : %{public}s", __FUNCTION__, [instanceName UTF8String]);
}

+ (void)callCurrentAbilityOnBackground {
    StageViewController *topVC = [self getApplicationTopViewController];
    if (![topVC isKindOfClass:[StageViewController class]]) {
        LOGI("callCurrentAbilityOnBackground is Not StageVC");
        return;
    }
    NSString *instanceName = topVC.instanceName;
    if (instanceName.length) {
        std::string cppInstanceName = [instanceName UTF8String];
        AppMain::GetInstance()->DispatchOnBackground(cppInstanceName);
    }
    LOGI("%{public}s, instanceName : %{public}s", __FUNCTION__, [instanceName UTF8String]);
}

+ (BOOL)handleSingleton:(NSString *)bundleName moduleName:(NSString *)moduleName abilityName:(NSString *)abilityName {
    bool isSingle = AppMain::GetInstance()->IsSingleton([moduleName UTF8String], [abilityName UTF8String]);
    if (!isSingle) {
        return NO;
    }
    NSString *singleName = [NSString stringWithFormat:@"%@:%@:%@", bundleName, moduleName, abilityName];
    LOGI("%{public}s, singleName is %{public}s", __func__, [singleName UTF8String]);
    StageViewController *topVC = [self getApplicationTopViewController];
    if (![topVC isKindOfClass:[StageViewController class]]) {
        LOGI("handleSingleton is Not StageVC");
        return NO;
    }
    if ([topVC.instanceName containsString:singleName]) {
        std::string instanceName = [topVC.instanceName UTF8String];
        AppMain::GetInstance()->DispatchOnNewWant(instanceName);
        return YES;
    }

    NSMutableArray *controllerArr = [[NSMutableArray alloc] initWithArray:topVC.navigationController.viewControllers];
    for (int i = 0; i < controllerArr.count; i++) {
        UIViewController *viewController = controllerArr[i];
        if ([viewController isKindOfClass:[StageViewController class]]) {
            StageViewController *tempVC = (StageViewController *)viewController;
            if ([tempVC.instanceName containsString:singleName]) {
                [controllerArr removeObjectAtIndex:i];
                [controllerArr addObject:tempVC];
                [topVC.navigationController setViewControllers:controllerArr.copy];
                std::string instanceName = [tempVC.instanceName UTF8String];
                AppMain::GetInstance()->DispatchOnNewWant(instanceName);
                return YES;
            }
        }
    }
    return NO;
}

+ (void)releaseViewControllers {
    StageViewController *topVC = [StageApplication getApplicationTopViewController];
    if (![topVC isKindOfClass:[StageViewController class]]) {
        LOGI("releaseViewControllers is Not StageVC");
        return;
    }
    NSMutableArray *controllerArr = [[NSMutableArray alloc] initWithArray:topVC.navigationController.viewControllers];
    int size = controllerArr.count;
    NSString *instanceName = topVC.instanceName;
    if (instanceName.length) {
        LOGI("%{public}s, instanceName : %{public}s", __FUNCTION__, [instanceName UTF8String]);
        for (int i = size - 1; i >= 0; i--) {
            UIViewController *viewController = controllerArr[i];
            if ([viewController isKindOfClass:[StageViewController class]]) {
                StageViewController *tempVC = (StageViewController *)viewController;
                std::string cppInstanceName = [tempVC.instanceName UTF8String];
                AppMain::GetInstance()->DispatchOnDestroy(cppInstanceName);
            }
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
        } else if (topViewController.childViewControllers.count > 0) {
            LOGI("topViewController has childViewControllers");
            UIViewController *foundChild = nil;
            for (UIViewController *childVC in topViewController.childViewControllers.reverseObjectEnumerator) {
                if (childVC.isViewLoaded && childVC.view.window) {
                    foundChild = childVC;
                    break;
                }
            }
            if (foundChild) {
                //to do
                LOGI("topViewController is a child view controller");
                topViewController = foundChild;
            } else {
                //to do
                LOGI("topViewController is a container view controller");
                break;
            }
        } else {
            break;
        }
    }
    return topViewController;
}

+ (void)setLogInterface:(id)log
{
    [[Logger sharedInstance] NativeSetLogger:log];
}

+ (void)setLogLevel:(int)logLevel
{
    [[Logger sharedInstance] NativeSetLogLevel:logLevel];
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
        LOGI("print: The total length of the message exceed 1000 characters.");
    } else {
        LOGI("print: %{public}s", [msg UTF8String]);
    }
}

- (void)printSync:(NSString *)msg {
    if (msg.length >= 1000) {
        LOGI("printSync: The total length of the message exceed 1000 characters.");
    } else {
        LOGI("printSync: %{public}s", [msg UTF8String]);
    }
}

- (int)finishTest {
    LOGI("TestFinished-ResultMsg: your test finished!!!");
    int error = 0;
    @try {
       exit(0);
    } @catch (NSException *exception) {
        //to do
        LOGE("TestFinished-ResultMsg");
        error = 1;
    } @finally {
        return error;
    }
}

+ (void)preloadEtsModule:(NSString *)moduleName country:(NSString *)abilityName
{
    if (moduleName == nil || moduleName.length == 0) {
        LOGE("moduleName is null");
        return;
    }
    if (abilityName == nil || abilityName.length == 0) {
        LOGE("abilityName is null");
        return;
    }
    AppMain::GetInstance()->PreloadModule([moduleName UTF8String], [abilityName UTF8String]);
}

+ (void)loadModule:(NSString *)moduleName entryFile:(NSString *)entryFile {
    if (moduleName == nil || moduleName.length == 0) {
        LOGE("load module error: moduleName is null.");
        return;
    }
    if (entryFile == nil || entryFile.length == 0) {
        LOGE("load module error: path is null.");
        return;
    }
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression
                                    regularExpressionWithPattern:kEtsPathRegexPattern options:0 error:&error];
    if (error) {
        LOGE("load module error: %{public}s", [error.localizedDescription UTF8String]);
        return;
    }
    NSUInteger matches = [regex numberOfMatchesInString:entryFile options:0 range:NSMakeRange(0, entryFile.length)];
    if (matches == 0) {
        LOGE("load module error: path is invalid.");
        return;
    }
    AppMain::GetInstance()->LoadModule([moduleName UTF8String], [entryFile UTF8String]);
}

@end
