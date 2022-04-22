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

#ifndef FOUNDATION_ACE_ADAPTER_PREVIEW_FETCH_MANAGER_H
#define FOUNDATION_ACE_ADAPTER_PREVIEW_FETCH_MANAGER_H

#include <cstdint>
#include <string>

#include "adapter/preview/osal/request_data.h"
#include "adapter/preview/osal/response_data.h"

namespace OHOS::Ace {

class FetchManager {
public:
    static FetchManager& GetInstance();

    virtual ~FetchManager() = default;
    virtual bool Fetch(const RequestData requestData, const int32_t callbackId, ResponseData& responseData) = 0;
};

} // namespace OHOS::Ace

#endif // #ifndef FOUNDATION_ACE_ADAPTER_PREVIEW_FETCH_MANAGER_H
