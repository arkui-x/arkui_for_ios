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

#import <Foundation/Foundation.h>
#import "StageViewController.h"
#import "ability_context_adapter.h"

#include <stdio.h>

#include "app_main.h"

#define dispatch_main_async_safe(block)\
if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(dispatch_get_main_queue())) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}

namespace OHOS::AbilityRuntime::Platform {
namespace {
NSString * GetOCstring(const std::string& c_string)
{
    return [NSString stringWithCString:c_string.c_str() encoding:NSUTF8StringEncoding];
}
}

std::shared_ptr<AbilityContextAdapter> AbilityContextAdapter::instance_ = nullptr;
std::mutex AbilityContextAdapter::mutex_;

std::shared_ptr<AbilityContextAdapter> AbilityContextAdapter::GetInstance()
{
    if (instance_ == nullptr) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (instance_ == nullptr) {
            instance_ = std::make_shared<AbilityContextAdapter>();
        }
    }

    return instance_;
}

UIViewController * theTopViewControler()
{
    UIViewController *rootVC = nil;
    rootVC = [[UIApplication sharedApplication].delegate window].rootViewController;
    UIViewController *parent = rootVC;
    while ((parent = rootVC.presentedViewController) != nil ) {
        rootVC = parent;
    }
    while ([rootVC isKindOfClass:[UINavigationController class]]) {
        rootVC = [(UINavigationController *)rootVC topViewController];
    }
    return rootVC;
}

bool OnNewWant(NSString *singletonName)
{
    NSLog(@"%s, singletonName is %@", __func__, singletonName);
    StageViewController *topVC = theTopViewControler();
    if ([topVC.instanceName containsString:singletonName]) {
        std::string instanceName = [topVC.instanceName UTF8String];
        AppMain::GetInstance()->DispatchOnNewWant(instanceName);
        return true;
    }

    NSMutableArray *controllerArr = [NSMutableArray arrayWithArray:topVC.navigationController.viewControllers];

    for (int i = 0; i < controllerArr.count; i++) {
        StageViewController *tempVC = controllerArr[i];
        if ([tempVC.instanceName containsString:singletonName]) {
            [controllerArr removeObjectAtIndex:i];
            [controllerArr addObject:tempVC];
            [topVC.navigationController setViewControllers:controllerArr];
            std::string instanceName = [tempVC.instanceName UTF8String];
            AppMain::GetInstance()->DispatchOnNewWant(instanceName);
            return true;
        }
    }
    return false;
}

void AbilityContextAdapter::StartAbility(const std::string& instanceName, const AAFwk::Want& want)
{
    NSString *bundleName = GetOCstring(want.GetBundleName());
    NSString *moduleName = GetOCstring(want.GetModuleName());
    NSString *abilityName = GetOCstring(want.GetAbilityName());
    NSString *urlString = [NSString stringWithFormat:@"%@://%@?%@", bundleName, moduleName, abilityName];
    NSURL *appUrl = [NSURL URLWithString:urlString];
    NSLog(@"%s, url : %@", __func__, urlString);
    bool isSingle = AppMain::GetInstance()->IsSingleton(want.GetModuleName(), want.GetAbilityName());
    dispatch_main_async_safe((^{
        if (isSingle) {
            NSString *instanceName = [NSString stringWithFormat:@"%@:%@:%@", bundleName, moduleName, abilityName];
            if (OnNewWant(instanceName)) {
                return;
            }
        }

        if ([[UIApplication sharedApplication] canOpenURL:appUrl]) {
            [[UIApplication sharedApplication] openURL:appUrl options: @{} completionHandler: ^(BOOL success) {}];
        } else {
            NSLog(@"can't open app");
        }
    }));
}

void AbilityContextAdapter::TerminateSelf(const std::string& instanceName)
{
    dispatch_main_async_safe(^{
    StageViewController *topVC = theTopViewControler();
    if (!topVC) {
        NSLog(@"%s, topVC nil", __func__);
    } else if (topVC.navigationController.viewControllers.count > 1) {
        NSLog(@"%s, pop", __func__);
        [topVC.navigationController popViewControllerAnimated:YES];
    } else {
        NSLog(@"%s, exit", __func__);
        std::string result = [topVC.instanceName UTF8String];
        OHOS::AbilityRuntime::Platform::AppMain::GetInstance()->DispatchOnDestroy(result);
        exit(0);
    }
    });
}
}
