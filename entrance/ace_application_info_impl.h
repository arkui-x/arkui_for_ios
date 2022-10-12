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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACE_APPLICATION_INFO_IMPL_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACE_APPLICATION_INFO_IMPL_H

#include <map>
#include <memory>
#include <string>
#include <vector>

#include "base/utils/noncopyable.h"
#include "core/common/ace_application_info.h"
#include "resource_manager.h"

namespace OHOS::Ace::Platform {

class ACE_FORCE_EXPORT AceApplicationInfoImpl : public AceApplicationInfo {
public:
    AceApplicationInfoImpl();
    ~AceApplicationInfoImpl() override;

    static AceApplicationInfoImpl& GetInstance();

    void SetLocale(const std::string& language, const std::string& countryOrRegion, const std::string& script,
                   const std::string& keywordsAndValues) override;
    void ChangeLocale(const std::string& language, const std::string& countryOrRegion) override;

    bool GetBundleInfo(const std::string& packageName, AceBundleInfo& bundleInfo) override;

    double GetLifeTime() const override
    {
        return 0.0;
    }
    std::string GetJsEngineParam(const std::string& key) const override;

    void SetJsEngineParam(const std::string& key, const std::string& value);

    void SetDebug(bool isDebugVersion, bool needDebugBreakpoint) override
    {
        AceApplicationInfoImpl::GetInstance().isDebugVersion_ = isDebugVersion;
        AceApplicationInfoImpl::GetInstance().needDebugBreakpoint_ = needDebugBreakpoint;
    }

    std::shared_ptr<Global::Resource::ResourceManager> GetResourceManager()
    {
        return resMgr_;
    }

    void SetResourceManager(std::shared_ptr<Global::Resource::ResourceManager> resMgr)
    {
        resMgr_ = resMgr;
    }

private:
    std::map<std::string, std::string> jsEngineParams_;
    std::shared_ptr<Global::Resource::ResourceManager> resMgr_;
};
} // namespace OHOS::Ace::Platform

#endif // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACE_APPLICATION_INFO_IMPL_H
