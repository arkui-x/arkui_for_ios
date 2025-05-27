/*
 * Copyright (c) 2023-2025 Huawei Device Co., Ltd.
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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_STAGE_ASSET_PROVIDER_H
#define FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_STAGE_ASSET_PROVIDER_H

#include <list>
#include <map>
#include <mutex>
#include <string>
#include <unordered_map>

#include "base/utils/macros.h"

namespace OHOS {
namespace AbilityRuntime {
namespace Platform {
class StageAssetProvider {
public:
    StageAssetProvider() = default;
    ~StageAssetProvider() = default;

    static std::shared_ptr<StageAssetProvider> GetInstance();
    std::vector<uint8_t> GetPkgJsonBuffer(const std::string& moduleName);
    std::list<std::vector<uint8_t>> GetModuleJsonBufferList();
    std::vector<uint8_t> GetFontConfigJsonBuffer(const std::string& moduleName);
    std::vector<uint8_t> GetModuleBuffer(const std::string& moduleName, std::string& modulePath, bool esmodule);
    std::vector<uint8_t> GetModuleAbilityBuffer(
        const std::string& moduleName, const std::string& abilityName, std::string& modulePath, bool esmodule);
    void GetResIndexPath(const std::string& moduleName, std::string& appResIndexPath, std::string& sysResIndexPath);

    std::string GetBundleCodeDir();
    std::string GetCacheDir();
    std::string GetResourceFilePrefixPath();
    std::string GetTempDir();
    std::string GetFilesDir();
    std::string GetDatabaseDir();
    std::string GetPreferencesDir();
    std::string GetAppLibDir()
    {
        return "";
    }

    std::string GetAppDataModuleDir() const;
    bool GetAppDataModuleAssetList(const std::string& path, std::vector<std::string>& fileFullPaths, bool onlyChild);
    std::vector<std::string> GetAllFilePath();
    std::vector<uint8_t> GetBufferByAppDataPath(const std::string& fileFullPath);
    std::vector<uint8_t> GetAotBuffer(const std::string &fileName);
    void InitModuleVersionCode();
    void UpdateVersionCode(const std::string& moduleName, bool needUpdate);
    bool IsDynamicUpdateModule(const std::string& moduleName);
private:
    std::string fontConfigName_;
    std::mutex providerLock_;
    static std::shared_ptr<StageAssetProvider> instance_;
    static std::mutex mutex_;
    std::unordered_map<std::string, int32_t> versionCodes_;
    std::unordered_map<std::string, bool> moduleIsUpdates_;
    static std::map<std::string, std::pair<std::string, std::string>> staticResCache;
};
} // namespace Platform
} // namespace AbilityRuntime
} // namespace OHOS

#endif // FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_STAGE_ASSET_PROVIDER_H