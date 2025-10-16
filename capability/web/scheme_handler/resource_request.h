/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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
#ifndef ACE_ENGINE_ADAPTER_IOS_CAPABILITY_WEB_SCHEME_HANDLER_RESOURCE_REQUEST_H
#define ACE_ENGINE_ADAPTER_IOS_CAPABILITY_WEB_SCHEME_HANDLER_RESOURCE_REQUEST_H

#include <string>
#include <vector>

using WebHeaderList = std::vector<std::pair<std::string, std::string>>;
struct ArkWeb_ResourceRequest {
    std::string url_ = "";
    std::string method_ = "";
    std::string referrer_ = "";
    bool isRedirect_ = false;
    bool isMainFrame_ = false;
    bool hasGesture_ = false;
    int32_t requestResourceType_ = -1;
    std::string frameUrl_ = "";
    WebHeaderList headerList_;
    ArkWeb_ResourceRequest() = default;
    ArkWeb_ResourceRequest(const std::string& m, const std::string& u) : method_(m), url_(u) {}
};

#ifdef __OBJC__
@class WKNavigationAction;
#ifdef __cplusplus
extern "C" {
#endif
ArkWeb_ResourceRequest* CreateResourceRequest(WKNavigationAction* navigationAction);
#ifdef __cplusplus
}
#endif
#endif // __OBJC__
#endif  // ACE_ENGINE_ADAPTER_IOS_CAPABILITY_WEB_SCHEME_HANDLER_RESOURCE_REQUEST_H