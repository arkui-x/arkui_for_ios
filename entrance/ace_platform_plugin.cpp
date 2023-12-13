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

#include "adapter/ios/entrance/ace_platform_plugin.h"

#include "base/log/log.h"
#include "base/utils/macros.h"
#include "base/utils/utils.h"

namespace OHOS::Ace::Platform {
std::unordered_map<int, RefPtr<PlatformResRegister>> g_resRegisters;

void AcePlatformPlugin::InitResRegister(int32_t instanceId, const RefPtr<PlatformResRegister>& resRegister)
{
    if (resRegister == nullptr) {
        LOGE("resRegister is null");
        return;
    }
    g_resRegisters.emplace(static_cast<int32_t>(instanceId), resRegister);
}

RefPtr<PlatformResRegister> AcePlatformPlugin::GetResRegister(int32_t instanceId)
{
    return g_resRegisters[instanceId];
}
}