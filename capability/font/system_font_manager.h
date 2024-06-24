/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_CAPABILITY_FONT_SYSTEM_FONT_MANAGER_H
#define FOUNDATION_ACE_ADAPTER_IOS_CAPABILITY_FONT_SYSTEM_FONT_MANAGER_H

#include <string>
#include <vector>
#include <map>

#include "core/common/font_manager.h"

namespace OHOS::Ace::Platform {

using FontNameFamilyMap = std::map<std::string, std::string>;

class SystemFontManager {
public:
    SystemFontManager() = default;
    virtual ~SystemFontManager() = default;

    void GetSystemFontList(std::vector<std::string>& fontList);
    bool GetSystemFont(const std::string& fontName, FontInfo& fontInfo);
private:
    void GetSystemFontNameFamilyMap();
    bool GetSystemFontDetailByName(const std::string& fontName, FontInfo& fontInfo);

    static std::unique_ptr<FontNameFamilyMap> fontNameFamilyMap_;
};
} // namespace OHOS::Ace::Platform
#endif // FOUNDATION_ACE_ADAPTER_IOS_CAPABILITY_FONT_SYSTEM_FONT_MANAGER_H