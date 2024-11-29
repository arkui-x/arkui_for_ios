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

#include "AceWebObject.h"

float AceWebOnScrollObject::GetX() {
    return this->x_;
}

float AceWebOnScrollObject::GetY() {
     return this->y_;
}

float AceWebOnScaleChangeObject::GetOldScale() {
    return this->oldScale_;
}

float AceWebOnScaleChangeObject::GetNewScale() {
    return this->newScale_;
}

std::string AceWebOnConsoleObject::GetMessage() {
    return this->message_;
}

int AceWebOnConsoleObject::GetMessageLevel() {
    return this->messageLevel_;
}

std::string AceWebHttpErrorReceiveObject::GetRequestUrl() {
    return this->requestUrl_;
}

std::string AceWebHttpErrorReceiveObject::GetMimeType() {
    return this->mimeType_;
}

std::string AceWebHttpErrorReceiveObject::GetEncoding() {
     return this->contentEncoding_;
}

int AceWebHttpErrorReceiveObject::GetStatusCode() {
    return this->statusCode_;
}

std::string AceWebDialogObject::GetUrl() {
    return this->url_;
}

std::string AceWebDialogObject::GetMessage() {
    return this->message_;
}

std::string AceWebDialogObject::GetValue() {
    return this->value_;
}

std::string AceWebPermissionRequestObject::GetOrigin() {
    return this->origin_;
}

int AceWebPermissionRequestObject::GetResourcesId() {
     return this->type_;
}

std::string AceWebOnHttpAuthRequestObject::GetHost() {
    return this->host_;
}

std::string AceWebOnHttpAuthRequestObject::GetRealm() {
     return this->realm_;
}

std::string AceWebDownloadResponseObject::GetUrl() {
    return this->url_;
}

std::string AceWebDownloadResponseObject::GetMimetype() {
     return this->mimetype_;
}

long AceWebDownloadResponseObject::GetContentLength() {
     return this->contentLength_;
}

std::string AceWebDownloadResponseObject::GetUserAgent() {
    return this->userAgent_;
}
