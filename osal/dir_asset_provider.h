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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_OSAL_DIR_ASSET_PROVIDER_H
#define FOUNDATION_ACE_ADAPTER_IOS_OSAL_DIR_ASSET_PROVIDER_H

#include <memory>
#include <string>

#ifdef WINDOWS_PLATFORM
#include <windows.h>
#else
#include <dirent.h>
#include <sys/types.h>
#endif

#include "flutter/assets/directory_asset_bundle.h"

#include "adapter/ios/osal/file_asset_provider.h"
#include "base/resource/asset_manager.h"
#include "base/utils/macros.h"

namespace OHOS::Ace {

class ACE_EXPORT DirAssetProvider : public FlutterAssetProvider {
    DECLARE_ACE_TYPE(DirAssetProvider, FlutterAssetProvider);

public:
    DirAssetProvider(const std::string& basePath, std::unique_ptr<flutter::DirectoryAssetBundle> provider)
        : basePath_(basePath), assetProvider_(std::move(provider))
    {}
    ~DirAssetProvider() override = default;

    std::unique_ptr<fml::Mapping> GetAsMapping(const std::string& assetName) const override
    {
        if (!assetProvider_) {
            return nullptr;
        }
        return assetProvider_->GetAsMapping(assetName);
    }

    bool IsValid() const override
    {
        if (!assetProvider_) {
            return false;
        }
        return assetProvider_->IsValid();
    }

    std::string GetAssetPath(const std::string& assetName, bool isAddHapPath) override
    {
        std::string fileName = basePath_ + assetName;
        std::FILE* fp = std::fopen(fileName.c_str(), "r");
        if (fp == nullptr) {
            return "";
        }
        std::fclose(fp);
        return basePath_;
    }

    void GetAssetList(const std::string& path, std::vector<std::string>& assetList) override
    {
#if defined(WINDOWS_PLATFORM)
        std::string dirPath = basePath_ + "\\" + path;
        WIN32_FIND_DATA fileInfo;
        HANDLE hFind;
        if ((hFind = FindFirstFile(dirPath.append("\\*").c_str(), &fileInfo)) != INVALID_HANDLE_VALUE) {
            do {
                if (strcmp(fileInfo.cFileName, ".") != 0 && strcmp(fileInfo.cFileName, "..") != 0) {
                    assetList.push_back(fileInfo.cFileName);
                }
            } while (FindNextFile(hFind, &fileInfo) != 0);
            FindClose(hFind);
        }
#elif defined(MAC_PLATFORM) || defined(IOS_PLATFORM)
        std::string dirPath = basePath_ + "/" + path;
        DIR* dp = nullptr;
        if (nullptr == (dp = opendir(dirPath.c_str()))) {
            return;
        }
        struct dirent* dptr = nullptr;
        while ((dptr = readdir(dp)) != nullptr) {
            if (strcmp(dptr->d_name, ".") != 0 && strcmp(dptr->d_name, "..") != 0) {
                assetList.push_back(dptr->d_name);
            }
        }
        closedir(dp);
#endif
    }

private:
    std::string basePath_;
    std::unique_ptr<flutter::AssetResolver> assetProvider_;
};

} // namespace OHOS::Ace

#endif // FOUNDATION_ACE_ADAPTER_IOS_OSAL_DIR_ASSET_PROVIDER_H
