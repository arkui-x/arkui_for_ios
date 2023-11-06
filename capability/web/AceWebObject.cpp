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
