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

#include "adapter/ios/entrance/ace_resource_register.h"

#include <vector>

#include "adapter/ios/entrance/ace_bridge.h"
#include "frameworks/bridge/common/utils/utils.h"

namespace OHOS::Ace {
const char PARAM_AND[] = "#HWJS-&-#";
const char PARMA_EQUALS[] = "#HWJS-=-#";
const char PARAM_AT[] = "@";
const int SPLIT_COUNT = 2;
} // namespace OHOS::Ace

namespace OHOS::Ace::Platform {

AceResourceRegister::AceResourceRegister(void* object) : client_(object)
{
}

AceResourceRegister::~AceResourceRegister()
{
   delete static_cast<void*>(client_);
}

bool AceResourceRegister::OnMethodCall(const std::string& method, const std::string& param, std::string& result)
{
    return CallOC_OnMethodCall(client_, method, param, result);
}

int64_t AceResourceRegister::CreateResource(const std::string& resourceType, const std::string& param)
{
    if (client_ == nullptr) {
        return -1;
    }

    return CallOC_CreateResource(client_, resourceType, param);
}

bool AceResourceRegister::ReleaseResource(const std::string& resourceHash)
{
    return CallOC_ReleaseResource(client_, resourceHash);
}

} // namespace OHOS::Ace::Platform
