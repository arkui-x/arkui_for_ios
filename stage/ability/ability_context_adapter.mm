/*
 * Copyright (c) 2023-2024 Huawei Device Co., Ltd.
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
#include "base/utils/string_utils.h"

#define dispatch_main_async_safe(block)\
if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(dispatch_get_main_queue())) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}

#define URL_QUERY_ABILITY_KEY @"abilityName"
#define URL_QUERY_PARAMS_KEY @"params"
#define ABILITY_NAME @"Ability"
#define BUNDLENAME_FILEPICKER @"com.ohos.filepicker"
#define BUNDLENAME_PHOTOPICKER @"com.ohos.photos"
#define PICKER_REQUESTCODE_ERROR_OK @0

namespace OHOS::AbilityRuntime::Platform {
namespace {
NSString * GetOCstring(const std::string& c_string)
{
    if (c_string.empty()) {
        return @"";
    }
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

void AbilityContextAdapter::print(const std::string& message) {
    NSString * msg = [NSString stringWithCString:message.c_str() encoding:[NSString defaultCStringEncoding]];
    NSLog(@"AbilityContextAdapter print, msg : %@", msg);
    StageApplication *application = [StageApplication new];
    [application print:msg];
}

size_t AbilityContextAdapter::StringToken(std::string &str, const std::string &sep, std::string &token)
{
    token = "";
    if (str.empty()) {
        return str.npos;
    }
    size_t pos = str.npos;
    size_t tmp = 0;
    for (auto &item : sep) {
        tmp = str.find(item);
        if (str.npos != tmp) {
            pos = (std::min)(pos, tmp);
        }
    }
    if (str.npos != pos) {
        token = str.substr(0, pos);
        if (str.npos != pos + 1) {
            str = str.substr(pos + 1, str.npos);
        }
        if (pos == 0) {
            return StringToken(str, sep, token);
        }
    } else {
        token = str;
        str = "";
    }
    return token.size();
}

size_t AbilityContextAdapter::StringSplit(const std::string &str, const std::string &sep, std::vector<std::string> &vecList)
{
    size_t size;
    auto strs = str;
    std::string token;
    while (str.npos != (size = StringToken(strs, sep, token))) {
            vecList.push_back(token);
    }
    return vecList.size();
}

int32_t AbilityContextAdapter::StartAbility(const std::string& instanceName, const AAFwk::Want& want)
{
    NSString* bundleName = GetOCstring(want.GetBundleName());
    NSString* moduleName = GetOCstring(want.GetModuleName());
    NSString* abilityName = GetOCstring(want.GetAbilityName());
    NSString* jsonString = GetOCstring(want.ToJson());
    NSString* type = GetOCstring(want.GetType());
    NSString* instanceNameStr = [NSString stringWithCString:instanceName.c_str() encoding:NSUTF8StringEncoding];

    NSDictionary* dicParams = [NSDictionary dictionaryWithDictionary:
                @{@"bundleName" : bundleName,
                @"instanceName" : instanceNameStr,
                @"requestCode" : PICKER_REQUESTCODE_ERROR_OK,
                @"type" : type,
                @"wantJsonStr" : jsonString}];
    if ([bundleName isEqualToString:BUNDLENAME_FILEPICKER] || [bundleName isEqualToString:BUNDLENAME_PHOTOPICKER]) {
        dispatch_main_async_safe(^{
                StageViewController *stage = [StageApplication getApplicationTopViewController];
                if (stage != nil) {
                    [stage startAbilityForResult:dicParams isReturnValue:NO];
                }
        });
    } else {
        if (bundleName.length == 0 || moduleName.length == 0 || abilityName.length == 0) {
            NSLog(@"startAbility failed, bundleName : %@, moduleName : %@, abilityName : %@",
                bundleName, moduleName, abilityName);
            return AAFwk::RESOLVE_ABILITY_ERR;
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
        if ([[UIApplication sharedApplication] canOpenURL:appUrl]) {	
            dispatch_main_async_safe(^{
                [[UIApplication sharedApplication] openURL:appUrl options: @{} completionHandler: ^(BOOL success) {}];	
            });	
        } else {	
            NSLog(@"startAbility failed, can't open app");	
            return AAFwk::RESOLVE_ABILITY_ERR;	
        }
    }
    return ERR_OK;
}

std::string AbilityContextAdapter::GetTopAbility()
{
    StageApplication *application = [StageApplication new];
    NSString *string = application.getTopAbility;
    if (string.length == 0) {
        string = @"GetTopAbility error";
    }
    std::string resultString=[string UTF8String];
    return resultString;
}

int32_t AbilityContextAdapter::DoAbilityForeground(const std::string &fullname)
{
    NSString *str = GetOCstring(fullname);
    StageApplication *application = [[StageApplication alloc] init];
    [application doAbilityForeground:str];
    return ERR_OK;
}

int32_t AbilityContextAdapter::DoAbilityBackground(const std::string &fullname)
{
    std::string instanceName = GetTopAbility();
    auto pos = instanceName.find(fullname);
    if (pos == std::string::npos) {
        LOGI("Do ability background, already background %{public}s", fullname.c_str());
        return ERR_OK;
    }

    NSString *str = GetOCstring(fullname);
    StageApplication *application = [StageApplication new];
    [application doAbilityBackground:str];
    return ERR_OK;
}

void AbilityContextAdapter::DoAbilityPrint(const std::string& msg)
{
    StageApplication *application = [StageApplication new];
    [application print:GetOCstring(msg)];
}
void AbilityContextAdapter::DoAbilityPrintSync(const std::string& msg)
{
    StageApplication *application = [StageApplication new];
    [application printSync:GetOCstring(msg)];
}

int32_t AbilityContextAdapter::FinishUserTest()
{
    StageApplication *application = [StageApplication new];
    int error = [application finishTest];
    int32_t erint = error;
    return error;
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
        }
        if (size == 1) {
            NSLog(@"%s, exit", __func__);
            OHOS::AbilityRuntime::Platform::AppMain::GetInstance()->DispatchOnDestroy(instanceName);
        }
        if ([topVC respondsToSelector:@selector(instanceName)]&&[topVC.instanceName isEqualToString:targetName]) {
            NSLog(@"%s, pop", __func__);
            [topVC.navigationController popViewControllerAnimated:YES];
            return;
        }
        NSMutableArray *controllerArr =
            [[NSMutableArray alloc] initWithArray:topVC.navigationController.viewControllers];
        for (int i = 0; i < controllerArr.count; i++) {
            StageViewController *tempVC = controllerArr[i];
            if ([tempVC respondsToSelector:@selector(instanceName)]&&[tempVC.instanceName containsString:targetName]) {
                [controllerArr removeObjectAtIndex:i];
                [topVC.navigationController setViewControllers:controllerArr.copy];
                return;
            }
        }
        NSLog(@"%s, failed", __func__);
    });
}

int32_t AbilityContextAdapter::StartAbilityForResult(
    const std::string& instanceName, const AAFwk::Want& want, int32_t requestCode)
{
    NSString* bundleName = GetOCstring(want.GetBundleName());
    NSString* jsonString = GetOCstring(want.ToJson());
    NSString* type = GetOCstring(want.GetType());

    NSString* instanceNameStr = [NSString stringWithCString:instanceName.c_str() encoding:NSUTF8StringEncoding];
    NSString* requestCodeStr = [NSString stringWithFormat:@"%ld", (long)requestCode];
    NSDictionary* dicParams = [NSDictionary dictionaryWithDictionary:
        @{@"bundleName" : bundleName,
        @"instanceName" : instanceNameStr,
        @"requestCode" : requestCodeStr,
        @"type": type,
        @"wantJsonStr" : jsonString}];

    StageViewController *stage = [StageApplication getApplicationTopViewController];
    if (stage == nil) {
        return ERR_NO_INIT;
    }
    [stage startAbilityForResult:dicParams isReturnValue:YES];
    return ERR_OK;
}

int32_t AbilityContextAdapter::TerminateAbilityWithResult(
    const std::string& instanceName, const AAFwk::Want& resultWant, int32_t resultCode)
{
    return ERR_OK;
}

int32_t AbilityContextAdapter::ReportDrawnCompleted(const std::string& instanceName)
{
    return ERR_OK;
}

std::string AbilityContextAdapter::GetPlatformBundleName()
{
    return "";
}
}
