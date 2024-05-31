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
#import "application_context_adapter.h"

namespace OHOS {
namespace AbilityRuntime {
namespace Platform {
std::shared_ptr<ApplicationContextAdapter> ApplicationContextAdapter::instance_ = nullptr;
std::mutex ApplicationContextAdapter::mutex_;

std::shared_ptr<ApplicationContextAdapter> ApplicationContextAdapter::GetInstance()
{
    if (instance_ == nullptr) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (instance_ == nullptr) {
            instance_ = std::make_shared<ApplicationContextAdapter>();
        }
    }

    return instance_;
}

std::vector<RunningProcessInfo> ApplicationContextAdapter::GetRunningProcessInformation()
{
    RunningProcessInfo info;
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    info.pid = processInfo.processIdentifier;
    info.processName = std::string([processInfo.processName UTF8String]);
    NSDictionary *dict = [[NSBundle mainBundle] infoDictionary];
    NSString *bundleName = dict[@"CFBundleName"];
    info.bundleNames.emplace_back([bundleName UTF8String]);
    std::vector<RunningProcessInfo> infos {info};
    return infos;
}
} // namespace Platform
} // namespace AbilityRuntime
} // namespace OHOS
