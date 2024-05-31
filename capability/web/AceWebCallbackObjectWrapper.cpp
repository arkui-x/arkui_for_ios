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

class AceWebDialogObjectWrapper final : public OHOS::Ace::WebCommonDialogObject {
public:
    std::string GetUrl(void* object);
    std::string GetMessage(void* object);
    std::string GetValue(void* object);
    void Confirm(void* object, const std::string& promptResult, int index);
    void Confirm(void* object, int index);
    void Cancel(void* object, int index);
};

std::string AceWebDialogObjectWrapper::GetUrl(void* object)
{
    AceWebDialogObject* acePtr = reinterpret_cast<AceWebDialogObject*>(object);
    return acePtr ? acePtr->GetUrl() : "";
}

std::string AceWebDialogObjectWrapper::GetMessage(void* object)
{
    AceWebDialogObject* acePtr = reinterpret_cast<AceWebDialogObject*>(object);
    return acePtr ? acePtr->GetMessage() : "";
}

std::string AceWebDialogObjectWrapper::GetValue(void* object)
{
    AceWebDialogObject* acePtr = reinterpret_cast<AceWebDialogObject*>(object);
    return acePtr ? acePtr->GetValue() : "";
}

void AceWebDialogObjectWrapper::Confirm(void* object, const std::string& promptResult, int index)
{
    DialogResultCallBack callback;
    AceWebDialogObject* acePtr = reinterpret_cast<AceWebDialogObject*>(object);
    callback = acePtr ? acePtr->GetDialogResultCallback() : callback;
    if (callback) {
        callback(static_cast<int>(AceWebHandleResult::PROMPTCONFIRM), promptResult);
    }
}

void AceWebDialogObjectWrapper::Confirm(void* object, int index)
{
    DialogResultCallBack callback;
    AceWebDialogObject* acePtr = reinterpret_cast<AceWebDialogObject*>(object);
    callback = acePtr ? acePtr->GetDialogResultCallback() : callback;
    if (callback) {
        callback(static_cast<int>(AceWebHandleResult::CONFIRM), "");
    }
}

void AceWebDialogObjectWrapper::Cancel(void* object, int index)
{
    DialogResultCallBack callback;
    AceWebDialogObject* acePtr = reinterpret_cast<AceWebDialogObject*>(object);
    callback = acePtr ? acePtr->GetDialogResultCallback() : callback;
    if (callback) {
        callback(static_cast<int>(AceWebHandleResult::CANCEL), "");
    }
}

class AceWebPermissionRequestObjectWrapper final : public OHOS::Ace::WebPermissionRequestObject {
public:
    std::string GetOrigin(void* object);
    int GetResourcesId(void* object);
    void Grant(void* object, const int resourcesId, int index);
    void Deny(void* object, int index);
};

std::string AceWebPermissionRequestObjectWrapper::GetOrigin(void* object)
{
    AceWebPermissionRequestObject* acePtr = reinterpret_cast<AceWebPermissionRequestObject*>(object);
    return acePtr ? acePtr->GetOrigin() : "";
}

int AceWebPermissionRequestObjectWrapper::GetResourcesId(void* object)
{
    AceWebPermissionRequestObject* acePtr = reinterpret_cast<AceWebPermissionRequestObject*>(object);
    return acePtr ? acePtr->GetResourcesId() : 0;
}

void AceWebPermissionRequestObjectWrapper::Grant(void* object, const int resourcesId, int index)
{
    PermissionResultCallback callback;
    AceWebPermissionRequestObject* acePtr = reinterpret_cast<AceWebPermissionRequestObject*>(object);
    callback = acePtr ? acePtr->GetPermissionResultCallback() : callback;
    if (callback) {
        callback(static_cast<int>(AceWebHandleResult::GRANT), resourcesId);
    }
}

void AceWebPermissionRequestObjectWrapper::Deny(void* object, int index)
{
    PermissionResultCallback callback;
    AceWebPermissionRequestObject* acePtr = reinterpret_cast<AceWebPermissionRequestObject*>(object);
    callback = acePtr ? acePtr->GetPermissionResultCallback() : callback;
    if (callback) {
        callback(static_cast<int>(AceWebHandleResult::DENY), 0);
    }
}

class AceWebHttpAuthRequestObjectWrapper final : public OHOS::Ace::WebHttpAuthRequestObject {
public:
    std::string GetHost(void* object);
    std::string GetRealm(void* object);
    bool Confirm(void* object, std::string& userName, std::string& pwd, int index);
    bool IsHttpAuthInfoSaved(void* object, int index);
    void Cancel(void* object, int index);
};

std::string AceWebHttpAuthRequestObjectWrapper::GetHost(void* object)
{
    AceWebOnHttpAuthRequestObject* acePtr = reinterpret_cast<AceWebOnHttpAuthRequestObject*>(object);
    return acePtr ? acePtr->GetHost() : "";
}

std::string AceWebHttpAuthRequestObjectWrapper::GetRealm(void* object)
{
    AceWebOnHttpAuthRequestObject* acePtr = reinterpret_cast<AceWebOnHttpAuthRequestObject*>(object);
    return acePtr ? acePtr->GetRealm() : "";
}

bool AceWebHttpAuthRequestObjectWrapper::Confirm(void* object, std::string& userName, std::string& pwd, int index)
{
    AuthResultCallback callback;
    AceWebOnHttpAuthRequestObject* acePtr = reinterpret_cast<AceWebOnHttpAuthRequestObject*>(object);
    callback = acePtr ? acePtr->GetAuthResultCallback() : callback;
    if (callback) {
        return callback(static_cast<int>(AceWebHandleResult::CONFIRM), userName, pwd);
    }
    return false;
}

bool AceWebHttpAuthRequestObjectWrapper::IsHttpAuthInfoSaved(void* object, int index)
{
    AuthResultCallback callback;
    AceWebOnHttpAuthRequestObject* acePtr = reinterpret_cast<AceWebOnHttpAuthRequestObject*>(object);
    callback = acePtr ? acePtr->GetAuthResultCallback() : callback;
    if (callback) {
        return callback(static_cast<int>(AceWebHandleResult::HTTPAUTHINFOSAVED), "", "");
    }
    return false;
}

void AceWebHttpAuthRequestObjectWrapper::Cancel(void* object, int index)
{
    AuthResultCallback callback;
    AceWebOnHttpAuthRequestObject* acePtr = reinterpret_cast<AceWebOnHttpAuthRequestObject*>(object);
    callback = acePtr ? acePtr->GetAuthResultCallback() : callback;
    if (callback) {
        callback(static_cast<int>(AceWebHandleResult::CANCEL), "", "");
    }
}

class AceWebDownloadResponseObjectWrapper final : public OHOS::Ace::WebDownloadResponseObject {
public:
    std::string GetUrl(void* object);
    std::string GetMimetype(void* object);
    long GetContentLength(void* object);
    std::string GetContentDisposition(void* object);
    std::string GetUserAgent(void* object);
};

std::string AceWebDownloadResponseObjectWrapper::GetUrl(void* object)
{
    AceWebDownloadResponseObject* acePtr = reinterpret_cast<AceWebDownloadResponseObject*>(object);
    return acePtr ? acePtr->GetUrl() : "";
}

std::string AceWebDownloadResponseObjectWrapper::GetMimetype(void* object)
{
    AceWebDownloadResponseObject* acePtr = reinterpret_cast<AceWebDownloadResponseObject*>(object);
    return acePtr ? acePtr->GetMimetype() : "";
}

long AceWebDownloadResponseObjectWrapper::GetContentLength(void* object)
{
    AceWebDownloadResponseObject* acePtr = reinterpret_cast<AceWebDownloadResponseObject*>(object);
    return acePtr ? acePtr->GetContentLength() : 0;
}

std::string AceWebDownloadResponseObjectWrapper::GetContentDisposition(void* object)
{
    return "contentDisposition";
}

std::string AceWebDownloadResponseObjectWrapper::GetUserAgent(void* object)
{
    AceWebDownloadResponseObject* acePtr = reinterpret_cast<AceWebDownloadResponseObject*>(object);
    return acePtr ? acePtr->GetUserAgent() : "";
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
    auto aceCommonDialogObject = OHOS::Ace::Referenced::MakeRefPtr<AceWebDialogObjectWrapper>();
    OHOS::Ace::WebObjectEventManager::GetInstance().SetCommonDialogObject(aceCommonDialogObject);
    auto acePermissionRequestObject = OHOS::Ace::Referenced::MakeRefPtr<AceWebPermissionRequestObjectWrapper>();
    OHOS::Ace::WebObjectEventManager::GetInstance().SetPermissionRequestObject(acePermissionRequestObject);
    auto aceWebHttpAuthRequestObject = OHOS::Ace::Referenced::MakeRefPtr<AceWebHttpAuthRequestObjectWrapper>();
    OHOS::Ace::WebObjectEventManager::GetInstance().SetHttpAuthRequestObject(aceWebHttpAuthRequestObject);
    auto aceWebDownloadResponseObject = OHOS::Ace::Referenced::MakeRefPtr<AceWebDownloadResponseObjectWrapper>();
    OHOS::Ace::WebObjectEventManager::GetInstance().SetDownloadResponseObject(aceWebDownloadResponseObject);
}