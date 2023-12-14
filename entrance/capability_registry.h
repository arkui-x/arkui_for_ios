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

#ifndef FOUNDATION_ACE_ACE_ENGINE_ADAPTER_IOS_ENTRANCE_CAPABILITY_REGISTRY_H
#define FOUNDATION_ACE_ACE_ENGINE_ADAPTER_IOS_ENTRANCE_CAPABILITY_REGISTRY_H

#include <string>

#include "base/log/log.h"

namespace OHOS::Ace::Platform {

class CapabilityRegistry {
public:
    CapabilityRegistry() = delete;
    ~CapabilityRegistry() = delete;

    static void Register();
};

} // namespace OHOS::Ace::Platform

#endif // FOUNDATION_ACE_ACE_ENGINE_ADAPTER_IOS_ENTRANCE_CAPABILITY_REGISTRY_H
