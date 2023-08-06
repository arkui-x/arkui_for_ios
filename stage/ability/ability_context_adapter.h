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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_ABILITY_CONTEXT_ADAPTER_H
#define FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_ABILITY_CONTEXT_ADAPTER_H

#include <list>
#include <map>
#include <mutex>
#include <string>

#include "base/utils/macros.h"
#include "want.h"

namespace OHOS::AbilityRuntime::Platform {
class AbilityContextAdapter {
public:
    AbilityContextAdapter() = default;
    ~AbilityContextAdapter() = default;

    static std::shared_ptr<AbilityContextAdapter> GetInstance();
    int32_t StartAbility(const std::string& instanceName, const AAFwk::Want& want);
    int32_t DoAbilityForeground(const std::string &fullname);
    int32_t DoAbilityBackground(const std::string &fullname);
    size_t StringSplit(const std::string &str, const std::string &sep, std::vector<std::string> &vecList);
    std::string GetTopAbility();
    void DoAbilityPrint(const std::string& msg);
    void DoAbilityPrintSync(const std::string& msg);
    void TerminateSelf(const std::string& instanceName);
    void print(const std::string& message);
    int32_t FinishUserTest();
    size_t StringToken(std::string &str, const std::string &sep, std::string &token);
    int32_t StartAbilityForResult(
        const std::string& instanceName, const AAFwk::Want& want, int32_t requestCode);
    int32_t TerminateAbilityWithResult(
        const std::string& instanceName, const AAFwk::Want& resultWant, int32_t resultCode);
    std::string GetPlatformBundleName();
private:
    std::mutex contextLock_;
    static std::shared_ptr<AbilityContextAdapter> instance_;
    static std::mutex mutex_;
};
} // namespace OHOS::AbilityRuntime::Platform
#endif // FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_ABILITY_CONTEXT_ADAPTER_H
