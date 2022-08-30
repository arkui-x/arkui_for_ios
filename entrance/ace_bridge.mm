/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
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

#include <string>
#import <Foundation/Foundation.h>
#import "adapter/ios/entrance/resource/AceResourceRegisterOC.h"
#import "adapter/ios/entrance/ace_bridge.h" 

int64_t CallOC_CreateResource(void *obj, const std::string& resourceType, const std::string& param) {
    NSString *oc_resourceType = [NSString stringWithCString:resourceType.c_str() encoding:NSUTF8StringEncoding];
    NSString *oc_param = [NSString stringWithCString:param.c_str() encoding:NSUTF8StringEncoding];

    return (int64_t)[(__bridge AceResourceRegisterOC*)obj createResource:oc_resourceType param:oc_param];
}

bool CallOC_OnMethodCall(void *obj, const std::string& method, const std::string& param, std::string& result){
    NSString *oc_method = [NSString stringWithCString:method.c_str() encoding:NSUTF8StringEncoding];
    NSString *oc_param = [NSString stringWithCString:param.c_str() encoding:NSUTF8StringEncoding];

    NSString *oc_result = [(__bridge AceResourceRegisterOC*)obj onCallMethod:oc_method param:oc_param];
    result = [oc_result UTF8String];

    return true;
}

bool CallOC_ReleaseResource(void *obj, const std::string& resourceHash){
    NSString *oc_resourceHash = [NSString stringWithCString:resourceHash.c_str() encoding:NSUTF8StringEncoding];
    return [(__bridge AceResourceRegisterOC*)obj releaseObject:oc_resourceHash];
}
