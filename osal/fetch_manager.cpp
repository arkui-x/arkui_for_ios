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

#include "adapter/preview/osal/fetch_manager.h"

#include <memory>
#include <mutex>

//#include "curl/curl.h"

#include "adapter/ios/osal/http_constant.h"
#include "base/log/log.h"
#include "base/utils/singleton.h"

#define ACE_CURL_EASY_SET_OPTION(handle, opt, data)                                                 \
    do {                                                                                            \
//        CURLcode result = curl_easy_setopt(handle, opt, data);                                      \
//        if (result != CURLE_OK) {                                                                   \
//            LOGE("Failed to set option: %{public}s, %{public}s", #opt, curl_easy_strerror(result)); \
//            return false;                                                                           \
//        }                                                                                           \
    } while (0)

namespace OHOS::Ace {
namespace {

class FetchManagerImpl final : public FetchManager, public Singleton<FetchManagerImpl> {
    DECLARE_SINGLETON(FetchManagerImpl);
    ACE_DISALLOW_MOVE(FetchManagerImpl);

public:
    bool Fetch(const RequestData requestData, const int32_t callbackId, ResponseData& responseData) override
    {
//        if (!Initialize()) {
//            return false;
//        }

//        std::unique_ptr<CURL, decltype(&curl_easy_cleanup)> handle(curl_easy_init(), &curl_easy_cleanup);
//        if (!handle) {
//            LOGE("Failed to create fetch task");
//            return false;
//        }
//
//        struct curl_slist* header = nullptr;
//        if (!requestData.GetHeader().empty()) {
//            for (auto&& [key, value] : requestData.GetHeader()) {
//                header = curl_slist_append(header, (key + ":" + value).c_str());
//            }
//            ACE_CURL_EASY_SET_OPTION(handle.get(), CURLOPT_HTTPHEADER, header);
//        }
//
//        std::string responseBody;
//        ACE_CURL_EASY_SET_OPTION(handle.get(), CURLOPT_WRITEFUNCTION, OnWritingMemoryBody);
//        ACE_CURL_EASY_SET_OPTION(handle.get(), CURLOPT_WRITEDATA, &responseBody);
//
//        std::string responseHeader;
//        ACE_CURL_EASY_SET_OPTION(handle.get(), CURLOPT_HEADERFUNCTION, OnWritingMemoryHeader);
//        ACE_CURL_EASY_SET_OPTION(handle.get(), CURLOPT_HEADERDATA, &responseHeader);
//
//        // Some servers don't like requests that are made without a user-agent field, so we provide one
//        ACE_CURL_EASY_SET_OPTION(handle.get(), CURLOPT_USERAGENT, "libcurl-agent/1.0");
//#ifdef WINDOWS_PLATFORM
//        ACE_CURL_EASY_SET_OPTION(handle.get(), CURLOPT_SSL_VERIFYPEER, 0L);
//        ACE_CURL_EASY_SET_OPTION(handle.get(), CURLOPT_SSL_VERIFYHOST, 0L);
//#endif
//
//        std::string method = requestData.GetMethod();
//        if (method.empty()) {
//            method = "GET";
//        }
//        if (method == HttpConstant::HTTP_METHOD_HEAD || method == HttpConstant::HTTP_METHOD_OPTIONS ||
//            method == HttpConstant::HTTP_METHOD_DELETE || method == HttpConstant::HTTP_METHOD_TRACE ||
//            method == HttpConstant::HTTP_METHOD_GET) {
//            SetOptionForGet(requestData, handle.get());
//        } else if (method == HttpConstant::HTTP_METHOD_POST || method == HttpConstant::HTTP_METHOD_PUT) {
//            SetOptionForPost(requestData, handle.get());
//        } else {
//            LOGE("no method match!");
//            responseData.SetCode(HttpConstant::ERROR);
//            return false;
//        }
//
//        CURLcode result = curl_easy_perform(handle.get());
//        if (result != CURLE_OK) {
//            LOGE("Failed to fetch, url: %{private}s, %{public}s", requestData.GetUrl().c_str(),
//                curl_easy_strerror(result));
//            return false;
//        }
//
//        char* ct = nullptr;
//        CURLcode res = curl_easy_getinfo(handle.get(), CURLINFO_CONTENT_TYPE, &ct);
//        if ((CURLE_OK == res) && ct) {
//            LOGD("fetch-preview content_type: %{public}s", ct);
//        }
//
//        int32_t responseCode;
//        curl_easy_getinfo(handle.get(), CURLINFO_RESPONSE_CODE, &responseCode);
//        responseData.SetCode(responseCode);
//        responseData.SetData(responseBody);
//        responseData.SetHeaders(responseHeader);
//
//        curl_slist_free_all(header);

        return true;
    }

//    bool SetOptionForGet(const RequestData requestData, CURL* curl) const
//    {
//        // refer to function buildConnectionWithParam() in HttpFetchImpl.java
//        LOGD("begin to set option for get and encode final url");
//        std::string url = requestData.GetUrl();
//        if (requestData.GetData() != "") {
//            std::size_t index = url.find(HttpConstant::URL_PARAM_SEPARATOR);
//            if (index != std::string::npos) {
//                std::string param = url.substr(index + 1);
//
//                std::string encodeIn = param + HttpConstant::URL_PARAM_DELIMITER + requestData.GetData();
//                char* encodeOut = curl_easy_escape(curl, encodeIn.c_str(), 0);
//                if (encodeOut != nullptr) {
//                    url = url.substr(0, index + 1) + encodeOut;
//                    curl_free(encodeOut);
//                }
//            } else {
//                char* encodeOut = curl_easy_escape(curl, requestData.GetData().c_str(), 0);
//                if (encodeOut != nullptr) {
//                    url = url + HttpConstant::URL_PARAM_SEPARATOR + encodeOut;
//                    curl_free(encodeOut);
//                }
//            }
//        }
//        LOGD("final url : %{public}s", url.c_str());
//        ACE_CURL_EASY_SET_OPTION(curl, CURLOPT_URL, url.c_str());
//        return true;
//    }
//
//    bool SetOptionForPost(const RequestData requestData, CURL* curl) const
//    {
//        ACE_CURL_EASY_SET_OPTION(curl, CURLOPT_URL, requestData.GetUrl().c_str());
//        ACE_CURL_EASY_SET_OPTION(curl, CURLOPT_POST, 1L);
//        return true;
//    }

private:
//    static size_t OnWritingMemoryBody(const void* data, size_t size, size_t memBytes, void* userData)
//    {
//        ((std::string*)userData)->append((char*)data, 0, size * memBytes);
//        return size * memBytes;
//    }
//    static size_t OnWritingMemoryHeader(const void* data, size_t size, size_t memBytes, void* userData)
//    {
//        ((std::string*)userData)->append((char*)data, 0, size * memBytes);
//        return size * memBytes;
//    }
//
//    bool Initialize()
//    {
//        if (initialized_) {
//            return true;
//        }
//
//        std::lock_guard<std::mutex> lock(mutex_);
//        if (initialized_) {
//            return true;
//        }
//        if (curl_global_init(CURL_GLOBAL_ALL) != CURLE_OK) {
//            LOGE("Failed to initialize 'curl'");
//            return false;
//        }
//        initialized_ = true;
//        return true;
//    }

    std::mutex mutex_;
    bool initialized_ = false;
};

FetchManagerImpl::FetchManagerImpl() = default;

FetchManagerImpl::~FetchManagerImpl()
{
//    curl_global_cleanup();x
}

} // namespace

FetchManager& FetchManager::GetInstance()
{
    return Singleton<FetchManagerImpl>::GetInstance();
}

} // namespace OHOS::Ace
