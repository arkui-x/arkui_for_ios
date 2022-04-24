/*
 * Copyright (c) 2021-2022 Huawei Device Co., Ltd.
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

#include <memory>
#include <string>

#include "frameworks/base/network/download_manager.h"
#include "frameworks/base/json/json_util.h"

namespace OHOS::Ace {

class ACE_EXPORT HttpAssetProvider : public FlutterAssetProvider {
    DECLARE_ACE_TYPE(HttpAssetProvider, FlutterAssetProvider);

public:
    HttpAssetProvider(const std::string& basePath): basePath_(basePath) {}
    ~HttpAssetProvider() override = default;

    std::unique_ptr<fml::Mapping> GetAsMapping(const std::string& assetName) const override
    {
        if (basePath_.find("http") == std::string::npos || assetName.empty()) {
            return nullptr;
        }

        std::vector<uint8_t> dataOut;
        std::string url = basePath_ + "/" + assetName;
        if (OHOS::Ace::DownloadManager::GetInstance().Download(url, dataOut)) {
            std::string dataStr;
            dataStr.assign(dataOut.begin(), dataOut.end());
            if (dataStr.find("not found on this server") != std::string::npos) {
                return nullptr;
            }
            auto mapping = std::make_unique<fml::DataMapping>(dataOut);
            return mapping;
        } else {
            return nullptr;
        }
    }

    bool IsValid() const override
    {
        if (basePath_.find("http") == std::string::npos) {
            return false;
        }
        return true;
    }

    std::string GetAssetPath(const std::string& assetName) override
    {
        std::string filePath;
        if (assetName.find("/",0, 1) == std::string::npos) {
            filePath = basePath_ + assetName;
        } else {
            filePath = basePath_ + "/" + assetName;
        }
        return filePath;
    }

    /// 远端获取文件夹下的子文件路径
    void GetAssetList(const std::string& path, std::vector<std::string>& assetList) override
    {
        std::string remoteDirPath = basePath_ + "/directory.json";
        std::vector<uint8_t> dataOut;
        std::string jsonStr;
        if (OHOS::Ace::DownloadManager::GetInstance().Download(remoteDirPath, dataOut)) {
            jsonStr.assign(dataOut.begin(), dataOut.end());
        };

        std::unique_ptr<JsonValue> json = OHOS::Ace::JsonUtil::ParseJsonString(jsonStr);
        
        if (path.find("/", path.length()-1) != std::string::npos) {
            std::string sub_file_path = path.substr(0, path.length()-1);
            bool contain = json->Contains(sub_file_path);
            if (contain) {
                auto subs = json->GetValue(sub_file_path);
                for (int32_t i=0; i<subs->GetArraySize(); i++) {
                    auto sub = subs->GetArrayItem(i);
                    assetList.push_back(sub->GetString());
                }
            }
        } else {
            bool contain = json->Contains(path);
            if (contain) {
                auto subs = json->GetValue(path);
                for (int32_t i=0; i<subs->GetArraySize(); i++) {
                    auto sub = subs->GetArrayItem(i);
                    assetList.push_back(sub->GetString());
                }
            }
        }
    }

private:
    std::string basePath_;

};
} //namespace OHOS::Ace