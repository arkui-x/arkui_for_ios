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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_OSAL_RESPONSEDATA_H
#define FOUNDATION_ACE_ADAPTER_IOS_OSAL_RESPONSEDATA_H

#include <unordered_map>
#include <string>

#include "base/json/json_util.h"

namespace OHOS::Ace {

namespace {
// error code
constexpr int32_t ACTION_SUCCESS = 0;
constexpr int32_t COMMON_ERROR_CODE = 200;
// httpcode
constexpr int32_t HTTP_OK = 200;
} // namespace

class ResponseData {
public:
    int32_t GetCode() const
    {
        return code_;
    }

    void SetCode(const int32_t code)
    {
        code_ = code;
    }

    std::string GetData() const
    {
        return data_;
    }

    void SetData(const std::string data)
    {
        data_ = data;
    }

    std::unordered_map<std::string, std::string> GetHeaders() const
    {
        return headers_;
    }

    void SetHeaders(std::string headersStr);
    std::unique_ptr<JsonValue> GetResultString() const;
private:
    int32_t code_ = COMMON_ERROR_CODE;
    std::string data_;
    std::unordered_map<std::string, std::string> headers_;

    std::unique_ptr<JsonValue> GetStringValue() const;
};
} // namespace OHOS::Ace

#endif // FOUNDATION_ACE_ADAPTER_IOS_OSAL_RESPONSEDATA_H
