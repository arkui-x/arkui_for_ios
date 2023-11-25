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

#ifndef AceWebObject_hpp
#define AceWebObject_hpp

#include <iostream>
#include <string>

typedef bool (^HttpAuthRequestMethod)(int action, std::string name, std::string pwd);
typedef void (^PermissionRequestMethod)(int action, int ResourcesId);
typedef void (^DialogResultMethod)(int action, std::string promptResult);
using AuthResultCallback = std::function<bool(const int, const std::string&, const std::string&)>;
using PermissionResultCallback = std::function<void(const int, const int)>;
using DialogResultCallBack = std::function<void(const int, const std::string&)>;

class AceWebOnScrollObject {
public:
    AceWebOnScrollObject(const float x, const float y) : x_(x), y_(y) {}
    float GetX();
    float GetY();

private:
    float x_;
    float y_;
};

class AceWebOnScaleChangeObject {
public:
    AceWebOnScaleChangeObject(const float newScale, const float oldScale) : newScale_(newScale), oldScale_(oldScale) {}
    float GetNewScale();
    float GetOldScale();

private:
    float newScale_;
    float oldScale_;
};

class AceWebOnConsoleObject {
public:
    AceWebOnConsoleObject(const std::string& message, const int messageLevel)
        : message_(message), messageLevel_(messageLevel) {}
    std::string GetMessage();
    int GetMessageLevel();

private:
    std::string message_;
    int messageLevel_;
};

class AceWebHttpErrorReceiveObject {
public:
    AceWebHttpErrorReceiveObject(
        const std::string& url, const std::string& mimeType_, const std::string& contentEncoding, const int statusCode)
        : requestUrl_(url), mimeType_(mimeType_), contentEncoding_(contentEncoding), statusCode_(statusCode) {}
    std::string GetRequestUrl();
    std::string GetMimeType();
    std::string GetEncoding();
    int GetStatusCode();

private:
    std::string requestUrl_;
    std::string mimeType_;
    std::string contentEncoding_;
    int statusCode_;
};

class AceWebDialogObject {
public:
    AceWebDialogObject(const std::string& url, const std::string& message, const std::string& value)
        : url_(url), message_(message), value_(value) {}
    std::string GetUrl();
    std::string GetMessage();
    std::string GetValue();
    void SetDialogResultCallback(DialogResultMethod dialogResultCallback)
    {
        dialogResultCallback_ = dialogResultCallback;
    }

    DialogResultCallBack GetDialogResultCallback()
    {
        return [this](const int action, const std::string& promptResult) -> void {
            dialogResultCallback_(action, promptResult);
        };
    }

private:
    std::string url_;
    std::string message_;
    std::string value_;

    DialogResultMethod dialogResultCallback_;
};

class AceWebPermissionRequestObject {
public:
    AceWebPermissionRequestObject(const std::string& origin, const int type) : origin_(origin), type_(type) {}
    std::string GetOrigin();
    int GetResourcesId();
    void SetPermissionResultCallback(PermissionRequestMethod permissionResultCallback)
    {
        permissionResultCallback_ = permissionResultCallback;
    }

    PermissionResultCallback GetPermissionResultCallback()
    {
        return
            [this](const int action, const int ResourcesId) -> void { permissionResultCallback_(action, ResourcesId); };
    }

private:
    std::string origin_;
    int type_;
    PermissionRequestMethod permissionResultCallback_;
};

class AceWebOnHttpAuthRequestObject {
public:
    AceWebOnHttpAuthRequestObject(const std::string& host, const std::string& realm) : host_(host), realm_(realm) {}
    std::string GetHost();
    std::string GetRealm();
    void SetAuthResultCallback(HttpAuthRequestMethod authResultCallback)
    {
        authResultCallback_ = authResultCallback;
    }

    AuthResultCallback GetAuthResultCallback()
    {
        return [this](const int action, const std::string& name, const std::string& pwd) -> bool {
            return authResultCallback_(action, name, pwd);
        };
    }

private:
    std::string host_;
    std::string realm_;
    HttpAuthRequestMethod authResultCallback_;
};

class AceWebDownloadResponseObject {
public:
    AceWebDownloadResponseObject(
        const std::string& url, const std::string& mimetype, const long contentLength, const std::string& userAgent)
        : url_(url), mimetype_(mimetype), contentLength_(contentLength), userAgent_(userAgent) {}
    std::string GetUrl();
    std::string GetMimetype();
    long GetContentLength();
    std::string GetUserAgent();

private:
    std::string url_;
    std::string mimetype_;
    long contentLength_;
    std::string userAgent_;
};

#endif /* AceWebObject_hpp */