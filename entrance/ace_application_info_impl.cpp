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

#include "adapter/ios/entrance/ace_application_info_impl.h"

#include <cstring>
#include <dirent.h>
#include <iostream>
#include <sys/stat.h>

#include "contrib/minizip/unzip.h"
#include "unicode/locid.h"

#include "base/i18n/localization.h"
#include "base/log/ace_trace.h"
#include "base/log/event_report.h"
#include "base/log/log.h"
#include "base/resource/ace_res_config.h"
#include "base/resource/ace_res_data_struct.h"
#include "core/common/ace_engine.h"

using namespace icu;

namespace OHOS::Ace::Platform {

AceApplicationInfoImpl::AceApplicationInfoImpl() {}

AceApplicationInfoImpl::~AceApplicationInfoImpl() = default;

void AceApplicationInfoImpl::SetJsEngineParam(const std::string& key, const std::string& value)
{
    jsEngineParams_[key] = value;
}

std::string AceApplicationInfoImpl::GetJsEngineParam(const std::string& key) const
{
    std::string value;
    auto iter = jsEngineParams_.find(key);
    if (iter != jsEngineParams_.end()) {
        value = iter->second;
    }
    return value;
}

void AceApplicationInfoImpl::ChangeLocale(const std::string& language, const std::string& countryOrRegion) {}

void AceApplicationInfoImpl::SetLocale(const std::string& language, const std::string& countryOrRegion,
    const std::string& script, const std::string& keywordsAndValues)
{
    language_ = language;
    countryOrRegion_ = countryOrRegion;
    script_ = script;
    keywordsAndValues_ = keywordsAndValues;

    localeTag_ = language;
    if (!script_.empty()) {
        localeTag_.append("-" + script_);
    }

    if (!countryOrRegion_.empty()) {
        localeTag_.append("-" + countryOrRegion_);
    }

    Locale locale(language_.c_str(), countryOrRegion_.c_str());
    UErrorCode status = U_ZERO_ERROR;
    Locale::setDefault(locale, status);
    
    isRightToLeft_ = locale.isRightToLeft();
    auto languageList = Localization::GetLanguageList(language_);
    if (languageList.size() == 1) {
        Localization::SetLocale(language_, countryOrRegion_, script_, languageList.front(), keywordsAndValues_);
    } else {
        auto selectLanguage = AceResConfig::GetLocaleFallback(localeTag_, languageList);
        Localization::SetLocale(language_, countryOrRegion_, script_, selectLanguage.front(), keywordsAndValues_);
    }
}

bool AceApplicationInfoImpl::GetBundleInfo(const std::string& packageName, AceBundleInfo& bundleInfo)
{
    return false;
}

AceApplicationInfoImpl& AceApplicationInfoImpl::GetInstance()
{
    static AceApplicationInfoImpl instance;
    return instance;
}

} // namespace OHOS::Ace::Platform

namespace OHOS::Ace {

AceApplicationInfo& AceApplicationInfo::GetInstance()
{
    return Platform::AceApplicationInfoImpl::GetInstance();
}

} // namespace OHOS::Ace
