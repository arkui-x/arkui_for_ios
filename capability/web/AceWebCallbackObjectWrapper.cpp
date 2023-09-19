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
    return acePtr ? acePtr->GetRequestUrl() : "";
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

void InjectAceWebResourceObject()
{
    auto aceWebResourceObjectWrapper = OHOS::Ace::Referenced::MakeRefPtr<AceWebResourceObjectWrapper>();
    OHOS::Ace::WebObjectEventManager::GetInstance().SetResourceRequestObject(aceWebResourceObjectWrapper);
    auto aceWebResourceErrorObject = OHOS::Ace::Referenced::MakeRefPtr<AceWebResourceErrorObject>();
    OHOS::Ace::WebObjectEventManager::GetInstance().SetResourceErrorObject(aceWebResourceErrorObject);
}