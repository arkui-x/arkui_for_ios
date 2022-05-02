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

#include "adapter/preview/osal/fetch_manager.h"

#include <memory>
#include <mutex>

#include "adapter/ios/osal/http_constant.h"
#include "base/log/log.h"
#include "base/utils/singleton.h"

namespace OHOS::Ace {
namespace {

class FetchManagerImpl final : public FetchManager, public Singleton<FetchManagerImpl> {
    DECLARE_SINGLETON(FetchManagerImpl);
    ACE_DISALLOW_MOVE(FetchManagerImpl);

public:
    bool Fetch(const RequestData requestData, const int32_t callbackId, ResponseData& responseData) override
    {
        return true;
    }

private:
    std::mutex mutex_;
    bool initialized_ = false;
};

FetchManagerImpl::FetchManagerImpl() = default;

FetchManagerImpl::~FetchManagerImpl() {}

} // namespace

FetchManager& FetchManager::GetInstance()
{
    return Singleton<FetchManagerImpl>::GetInstance();
}

} // namespace OHOS::Ace
