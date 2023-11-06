/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

#include "AceWebCallbackObjectWrapper.h"
#include "foundation/arkui/ace_engine/frameworks/core/components_ng/pattern/web/cross_platform/web_object_event.h"
#include "AceWebErrorReceiveInfoObject.h"
#include "AceWebObject.h"
#include <stdio.h>
#include <string.h>

class AceWebResourceObjectWrapper final : public OHOS::Ace::WebResourceRequestObject {
public:
    std::map<std::string, std::string> GetRequestHeader(void *object);
    std::string GetRequestUrl(void *object);
    std::string GetMethod(void *object);
    bool IsRequestGesture(void *object);
    bool IsMainFrame(void *object);
    bool IsRedirect(void *object);
};

std::map<std::string, std::string> AceWebResourceObjectWrapper::GetRequestHeader(void *object)
{
    return std::map<std::string, std::string>();
}

std::string AceWebResourceObjectWrapper::GetRequestUrl(void *object)
{
    AceWebErrorReceiveInfoObject* acePtr = reinterpret_cast<AceWebErrorReceiveInfoObject*>(object);
    auto requestURL = acePtr ? acePtr->GetRequestUrl() : "";
    if (strcmp(requestURL.c_str(), "") != 0) {
        return requestURL;
    } else {
        AceWebHttpErrorReceiveObject* aceHttpPtr = reinterpret_cast<AceWebHttpErrorReceiveObject*>(object);
        return aceHttpPtr ? aceHttpPtr->GetRequestUrl() : "";
    }
}

std::string AceWebResourceObjectWrapper::GetMethod(void *object)
{
    return "GET";
}

bool AceWebResourceObjectWrapper::IsRequestGesture(void *object)
{
    return true;
}

bool AceWebResourceObjectWrapper::IsMainFrame(void *object)
{
    return true;
}

bool AceWebResourceObjectWrapper::IsRedirect(void *object)
{
    return false;
}

class AceWebResourceErrorObject final : public OHOS::Ace::WebResourceErrorObject{
public:
    std::string GetErrorInfo(void *object);
    int GetErrorCode(void *object);
};

std::string AceWebResourceErrorObject::GetErrorInfo(void *object)
{
    AceWebErrorReceiveInfoObject* acePtr = reinterpret_cast<AceWebErrorReceiveInfoObject*>(object);
    return acePtr ? acePtr->GetErrorInfo() : "";
}

int AceWebResourceErrorObject::GetErrorCode(void *object)
{
    AceWebErrorReceiveInfoObject* acePtr = reinterpret_cast<AceWebErrorReceiveInfoObject*>(object);
    return acePtr ? acePtr->GetErrorCode() : 0;
}

class AceWebScrollObjectWrapper final : public OHOS::Ace::WebScrollObject {
public:
    float GetX(void* object);
    float GetY(void* object);
};

float AceWebScrollObjectWrapper::GetX(void* object)
{
    AceWebOnScrollObject* acePtr = reinterpret_cast<AceWebOnScrollObject*>(object);
    return acePtr ? acePtr->GetX() : 0.f;
}

float AceWebScrollObjectWrapper::GetY(void* object)
{
    AceWebOnScrollObject* acePtr = reinterpret_cast<AceWebOnScrollObject*>(object);
    return acePtr ? acePtr->GetY() : 0.f;
}

class AceWebScaleChangeObjectWrapper final : public OHOS::Ace::WebScaleChangeObject {
public:
    float GetNewScale(void* object);
    float GetOldScale(void* object);
};

float AceWebScaleChangeObjectWrapper::GetNewScale(void* object)
{
    AceWebOnScaleChangeObject* acePtr = reinterpret_cast<AceWebOnScaleChangeObject*>(object);
    return acePtr ? acePtr->GetNewScale() : 0.f;
}

float AceWebScaleChangeObjectWrapper::GetOldScale(void* object)
{
    AceWebOnScaleChangeObject* acePtr = reinterpret_cast<AceWebOnScaleChangeObject*>(object);
    return acePtr ? acePtr->GetOldScale() : 0.f;
}

class AceWebConsoleMessageObjectWrapper final : public OHOS::Ace::WebConsoleMessageObject {
public:
    std::string GetMessage(void* object);
    int GetMessageLevel(void* object);
    int GetLineNumber(void* object);
    std::string GetSourceId(void* object);
};

std::string AceWebConsoleMessageObjectWrapper::GetMessage(void* object)
{
    AceWebOnConsoleObject* acePtr = reinterpret_cast<AceWebOnConsoleObject*>(object);
    return acePtr ? acePtr->GetMessage() : "";
}

int AceWebConsoleMessageObjectWrapper::GetMessageLevel(void* object)
{
    AceWebOnConsoleObject* acePtr = reinterpret_cast<AceWebOnConsoleObject*>(object);
    return acePtr ? acePtr->GetMessageLevel() : 0;
}

int AceWebConsoleMessageObjectWrapper::GetLineNumber(void* object)
{
    return 0;
}

std::string AceWebConsoleMessageObjectWrapper::GetSourceId(void* object)
{
    return "SourceId";
}

class AceWebResourceResponseObjectWrapper final : public OHOS::Ace::WebResourceResponseObject {
public:
    std::map<std::string, std::string> GetResponseHeader(void* object);
    std::string GetMimeType(void* object);
    std::string GetEncoding(void* object);
    std::string GetResponseData(void* object);
    std::string GetReason(void* object);
    int GetStatusCode(void* object);
};

std::map<std::string, std::string> AceWebResourceResponseObjectWrapper::GetResponseHeader(void* object)
{
    return std::map<std::string, std::string>();
}

std::string AceWebResourceResponseObjectWrapper::GetMimeType(void* object)
{
    AceWebHttpErrorReceiveObject* acePtr = reinterpret_cast<AceWebHttpErrorReceiveObject*>(object);
    return acePtr ? acePtr->GetMimeType() : "";
}

std::string AceWebResourceResponseObjectWrapper::GetEncoding(void* object)
{
    AceWebHttpErrorReceiveObject* acePtr = reinterpret_cast<AceWebHttpErrorReceiveObject*>(object);
    return acePtr ? acePtr->GetEncoding() : "";
}

std::string AceWebResourceResponseObjectWrapper::GetResponseData(void* object)
{
    return "ResponseData";
}

std::string AceWebResourceResponseObjectWrapper::GetReason(void* object)
{
    return "ResponseReason";
}

int AceWebResourceResponseObjectWrapper::GetStatusCode(void* object)
{
    AceWebHttpErrorReceiveObject* acePtr = reinterpret_cast<AceWebHttpErrorReceiveObject*>(object);
    return acePtr ? acePtr->GetStatusCode() : 0;
}

void InjectAceWebResourceObject()
{
    auto aceWebResourceObjectWrapper = OHOS::Ace::Referenced::MakeRefPtr<AceWebResourceObjectWrapper>();
    OHOS::Ace::WebObjectEventManager::GetInstance().SetResourceRequestObject(aceWebResourceObjectWrapper);
    auto aceWebResourceErrorObject = OHOS::Ace::Referenced::MakeRefPtr<AceWebResourceErrorObject>();
    OHOS::Ace::WebObjectEventManager::GetInstance().SetResourceErrorObject(aceWebResourceErrorObject);
    auto aceWebOnScrollObject = OHOS::Ace::Referenced::MakeRefPtr<AceWebScrollObjectWrapper>();
    OHOS::Ace::WebObjectEventManager::GetInstance().SetScrollObject(aceWebOnScrollObject);
    auto aceWebOnScaleChangeObject = OHOS::Ace::Referenced::MakeRefPtr<AceWebScaleChangeObjectWrapper>();
    OHOS::Ace::WebObjectEventManager::GetInstance().SetScaleChangeObject(aceWebOnScaleChangeObject);
    auto aceWebOnConsoleObject = OHOS::Ace::Referenced::MakeRefPtr<AceWebConsoleMessageObjectWrapper>();
    OHOS::Ace::WebObjectEventManager::GetInstance().SetConsoleMessageObject(aceWebOnConsoleObject);
    auto aceWebResourceResponseObject = OHOS::Ace::Referenced::MakeRefPtr<AceWebResourceResponseObjectWrapper>();
    OHOS::Ace::WebObjectEventManager::GetInstance().SetResourceResponseObject(aceWebResourceResponseObject);
}