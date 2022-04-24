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

#ifndef FOUNDATION_ACE_ADAPTER_PREVIEW_HTTPCONSTANT_H
#define FOUNDATION_ACE_ADAPTER_PREVIEW_HTTPCONSTANT_H

namespace OHOS::Ace {
class HttpConstant {
public:
    static const int ERROR = -1;
    static const int TIME_OUT = 30000;
    static const int BUFFER_SIZE = 8192;
    inline static const std::string URL_PARAM_SEPARATOR = "?";
    inline static const std::string URL_PARAM_DELIMITER = "&";
    inline static const std::string HTTP_METHOD_GET = "GET";
    inline static const std::string HTTP_METHOD_HEAD = "HEAD";
    inline static const std::string HTTP_METHOD_OPTIONS = "OPTIONS";
    inline static const std::string HTTP_METHOD_TRACE = "TRACE";
    inline static const std::string HTTP_METHOD_DELETE = "DELETE";
    inline static const std::string HTTP_METHOD_CONNECT = "CONNECT";
    inline static const std::string HTTP_METHOD_POST = "POST";
    inline static const std::string HTTP_METHOD_PUT = "PUT";
};
} // namespace OHOS::Ace

#endif // #ifndef FOUNDATION_ACE_ADAPTER_PREVIEW_HTTPCONSTANT_H
