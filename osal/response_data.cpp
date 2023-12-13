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

#include "adapter/preview/osal/response_data.h"

namespace OHOS::Ace {

std::unique_ptr<JsonValue> ResponseData::GetResultString() const
{
    auto resultJson = JsonUtil::Create(true);
    if (code_ == HTTP_OK) {
        resultJson->Put(std::string("code").c_str(), ACTION_SUCCESS);
        resultJson->Put(std::string("data").c_str(), GetStringValue());
    } else {
        resultJson->Put(std::string("code").c_str(), COMMON_ERROR_CODE);
        resultJson->Put(std::string("data").c_str(), "invalid response data");
    }

    return resultJson;
}

std::unique_ptr<JsonValue> ResponseData::GetStringValue() const
{
    auto responseJson = JsonUtil::Create(true);
    responseJson->Put(std::string("code").c_str(), code_);
    responseJson->Put(std::string("data").c_str(), data_.c_str());

    if (code_ == HTTP_OK) {
        std::string headersStr = "{";
        for (auto&& [key, value] : headers_) {
            headersStr += key + ":" + value + ",";
        }
        headersStr[headersStr.size() - 1] = '}';
        responseJson->Put(std::string("headers").c_str(), headersStr.c_str());
    }
    return responseJson;
}

void ResponseData::SetHeaders(std::string headersStr)
{
    const char separator = '\n';
    size_t posSeparator = headersStr.find(separator);
    while (std::string::npos != posSeparator) {
        std::string header = headersStr.substr(0, posSeparator - 1);
        if (header == "") {
            break;
        }
        size_t posColon = header.find(':');
        if (std::string::npos == posColon) {
            headers_["null"] = "[\"" + header + "\"]";
        } else {
            headers_["\"" + header.substr(0, posColon) + "\""] = "[\"" + header.substr(posColon + 2) + "\"]";
        }
        headersStr = headersStr.substr(posSeparator + 1);
        posSeparator = headersStr.find(separator);
    }
}
} // namespace OHOS::Ace
