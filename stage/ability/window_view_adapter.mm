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

#include "window_view_adapter.h"
#include "base/log/log.h"

namespace OHOS {
namespace AbilityRuntime {
namespace Platform {
WindowViewAdapter::WindowViewAdapter() {}

WindowViewAdapter::~WindowViewAdapter() {}

std::shared_ptr<WindowViewAdapter> WindowViewAdapter::GetInstance()
{
    static std::shared_ptr<WindowViewAdapter> instance = std::make_shared<WindowViewAdapter>();
    return instance;
}

void WindowViewAdapter::AddWindowView(const std::string& instanceName, void* windowView)
{   
    std::lock_guard<std::mutex> lock(mutex_);
    windowViewObjects_.emplace(instanceName, windowView);
}

void* WindowViewAdapter::GetWindowView(const std::string& instanceName)
{
    LOGI("Get window view, instancename: %{public}s", instanceName.c_str());
    std::lock_guard<std::mutex> lock(mutex_);
    auto finder = windowViewObjects_.find(instanceName);
    if (finder != windowViewObjects_.end()) {
        return finder->second;
    }
    return nullptr;
}

void WindowViewAdapter::RemoveWindowView(const std::string& instanceName)
{   
    LOGI("Remove window view, instancename: %{public}s", instanceName.c_str());
    std::lock_guard<std::mutex> lock(mutex_);
    auto finder = windowViewObjects_.find(instanceName);
    if (finder != windowViewObjects_.end()) {
        windowViewObjects_.erase(finder);
    }
}

std::string WindowViewAdapter::GetWindowName(void* windowView)
{
    if (windowView != nullptr) {
        for (auto wv : windowViewObjects_) {
            if (wv.second == windowView) {
                return wv.first;
            }
        }
    }
    return std::string("");
}
} // namespace Platform
} // namespace AbilityRuntime
} // namespace OHOS
