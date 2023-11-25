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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACE_PLATFORM_PLUGIN_N_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACE_PLATFORM_PLUGIN_N_H

#include <memory>
#include <map>

#include "adapter/ios/entrance/ace_resource_register.h"
#include "base/utils/noncopyable.h"

namespace OHOS::Ace::Platform {
class AcePlatformPlugin {
public:
    AcePlatformPlugin() = delete;
    ~AcePlatformPlugin() = delete;

    static void InitResRegister(int32_t instanceId, const RefPtr<PlatformResRegister>& resRegister);

    static RefPtr<PlatformResRegister> GetResRegister(int32_t instanceId);
    static void RegisterSurface(int32_t instanceId, int64_t texture_id, void* surface);
    static void UnregisterSurface(int32_t instanceId, int64_t texture_id);
    static void* GetNativeWindow(int32_t instanceId, int64_t textureId);

};
} // namespace OHOS::Ace::Platform
#endif // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACE_PLATFORM_PLUGIN_N_H
