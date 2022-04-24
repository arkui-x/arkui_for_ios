/*
 * Copyright (c) 2021 Huawei Device Co., Ltd.
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

#ifndef FOUNDATION_ACE_ADAPTER_PREVIEW_REQUESTDATA_H
#define FOUNDATION_ACE_ADAPTER_PREVIEW_REQUESTDATA_H

#include <map>
#include <string>

namespace OHOS::Ace {
class RequestData {
public:
    const std::string GetUrl() const
    {
        return url_;
    }

    void SetUrl(const std::string url)
    {
        url_ = url;
    }

    const std::string GetData() const
    {
        return data_;
    }

    void SetData(const std::string data)
    {
        data_ = data;
    }

    const std::map<std::string, std::string> GetHeader() const
    {
        return header_;
    }

    void SetHeader(const std::map<std::string, std::string> header)
    {
        header_ = header;
    }

    const std::string GetMethod() const
    {
        return method_;
    }

    void SetMethod(const std::string method)
    {
        method_ = method;
    }

    const std::string GetResponseType() const
    {
        return responseType_;
    }

    void SetResponseType(const std::string responseType)
    {
        responseType_ = responseType;
    }

private:
    std::string url_;
    std::string data_;
    std::map<std::string, std::string> header_;
    std::string method_;
    std::string responseType_;
};
} // namespace OHOS::Ace

#endif // #ifndef FOUNDATION_ACE_ADAPTER_PREVIEW_REQUESTDATA_H
