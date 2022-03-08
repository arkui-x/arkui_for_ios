/*
 * Copyright (c) 2021 Huawei Device Co., Ltd.
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

#ifndef FOUNDATION_ACE_ADAPTER_PREVIEW_ACE_RESOURCE_REGISTER_H
#define FOUNDATION_ACE_ADAPTER_PREVIEW_ACE_RESOURCE_REGISTER_H

#include <string>

#include "core/common/platform_res_register.h"

namespace OHOS::Ace::Platform {

class AceResourceRegister final : public PlatformResRegister {
public:
    int64_t CreateResource(const std::string& resourceType, const std::string& param) override;
    bool ReleaseResource(const std::string& resourceHash) override;
    bool OnMethodCall(const std::string& method, const std::string& param, std::string& result) override;
};

} // namespace OHOS::Ace::Platform

#endif // FOUNDATION_ACE_ADAPTER_PREVIEW_ACE_RESOURCE_REGISTER_H
