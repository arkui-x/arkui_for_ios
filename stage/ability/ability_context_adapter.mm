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
#import "ability_context_adapter.h"
#import "StageApplication.h"
#import "StageViewController.h"

#include <stdio.h>

#include "ability_manager_errors.h"
#include "app_main.h"

#define dispatch_main_async_safe(block)\
if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(dispatch_get_main_queue())) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}

#define URL_QUERY_ABILITY_KEY @"abilityName"
#define URL_QUERY_PARAMS_KEY @"params"

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

int32_t AbilityContextAdapter::StartAbility(const std::string& instanceName, const AAFwk::Want& want)
{
    NSString *bundleName = GetOCstring(want.GetBundleName());
    NSString *moduleName = GetOCstring(want.GetModuleName());
    NSString *abilityName = GetOCstring(want.GetAbilityName());
    NSString *jsonString = GetOCstring(want.ToJson());

    if (!bundleName.length || !moduleName.length || !abilityName.length) {
        NSLog(@"startAbility failed, bundleName : %@, moduleName : %@, abilityName : %@",
            bundleName, moduleName, abilityName);
        return AAFwk::INVALID_PARAMETERS_ERR;
    }

    NSString *urlString = [NSString stringWithFormat:@"%@://%@", bundleName, moduleName];

    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    NSMutableArray<NSURLQueryItem *> *queryItems = [[NSMutableArray alloc] init];
    NSURLQueryItem *abilityNameItem = [NSURLQueryItem queryItemWithName:URL_QUERY_ABILITY_KEY value:abilityName];
    [queryItems addObject:abilityNameItem];
    if (jsonString.length) {
        NSURLQueryItem *paramsItem = [NSURLQueryItem queryItemWithName:URL_QUERY_PARAMS_KEY value:jsonString];
        [queryItems addObject:paramsItem];
    }
    components.queryItems = queryItems;
    NSURL *appUrl = components.URL;

    NSLog(@"%s, url : %@", __func__, appUrl);
    if ([[UIApplication sharedApplication] canOpenURL:appUrl]) {
        dispatch_main_async_safe(^{
            [[UIApplication sharedApplication] openURL:appUrl options: @{} completionHandler: ^(BOOL success) {}];
        });
    } else {
        NSLog(@"startAbility failed, can't open app");
        return AAFwk::INVALID_PARAMETERS_ERR;
    }
    return ERR_OK;
}

void AbilityContextAdapter::TerminateSelf(const std::string& instanceName)
{
    dispatch_main_async_safe(^{
        StageViewController *topVC = [StageApplication getApplicationTopViewController];
        NSString *targetName = [NSString stringWithCString:instanceName.c_str() encoding:NSUTF8StringEncoding];

        if (topVC.presentingViewController) {
            [topVC dismissViewControllerAnimated:YES completion:nil];
            OHOS::AbilityRuntime::Platform::AppMain::GetInstance()->DispatchOnDestroy(instanceName);
            return;
        }

        int size = topVC.navigationController.viewControllers.count;
        if (size == 0) {
            NSLog(@"%s, viewControllers count zero", __func__);
            exit(0);
        }
        if (size == 1) {
            NSLog(@"%s, exit", __func__);
            OHOS::AbilityRuntime::Platform::AppMain::GetInstance()->DispatchOnDestroy(instanceName);
            exit(0);
        }
        if ([topVC.instanceName isEqualToString:targetName]) {
            NSLog(@"%s, pop", __func__);
            [topVC.navigationController popViewControllerAnimated:YES];
            return;
        }
        NSMutableArray *controllerArr =
            [[NSMutableArray alloc] initWithArray:topVC.navigationController.viewControllers];
        for (int i = 0; i < controllerArr.count; i++) {
            StageViewController *tempVC = controllerArr[i];
            if ([tempVC.instanceName containsString:targetName]) {
                [controllerArr removeObjectAtIndex:i];
                [topVC.navigationController setViewControllers:controllerArr.copy];
                return;
            }
        }
        NSLog(@"%s, failed", __func__);
    });
}
}
