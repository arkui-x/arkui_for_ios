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
#ifndef ACE_ENGINE_ADAPTER_IOS_CAPABILITY_WEB_SCHEME_HANDLER_RESOURCE_HANDLER_H
#define ACE_ENGINE_ADAPTER_IOS_CAPABILITY_WEB_SCHEME_HANDLER_RESOURCE_HANDLER_H

#include "foundation/arkui/ace_engine/frameworks/base/utils/macros.h"
#include "resource_request.h"
#include "response.h"
#define ARKWEB_ERR_CONNECTION_FAILED -104

struct ACE_EXPORT ArkWeb_ResourceHandler {
    ArkWeb_ResourceHandler() = default;
    ~ArkWeb_ResourceHandler() = default;

    int32_t DidReceiveResponse(const ArkWeb_Response* response);
    int32_t DidReceiveData(const uint8_t* buffer, int64_t bufLen);
    int32_t DidFinish();
    int32_t DidFailWithError(int32_t error_code, const std::string& errorDescription, bool completeIfNoResponse);
    void DestroyArkWebResourceHandler();

    const ArkWeb_Response* response_ = nullptr;
    std::string buffer_ = "";
    int64_t bufferLen_ = 0;
    bool isFinished_ = false;
    bool isFailed_ = false;
    int32_t errorCode_ = 0;
    std::string errorDescription_ = "";
};
#endif  // ACE_ENGINE_ADAPTER_IOS_CAPABILITY_WEB_SCHEME_HANDLER_RESOURCE_HANDLER_H