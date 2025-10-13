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

#include <new>
#include "AceWebSchemeHandler.h"

void AceWebSchemeHandler::setOnRequestStart(ArkWeb_SchemeHandler* handler, ArkWeb_OnRequestStart callback) {
    if (handler != nullptr) {
        handler->on_request_start = callback;
    }
}

void AceWebSchemeHandler::setOnRequestStop(ArkWeb_SchemeHandler* handler, ArkWeb_OnRequestStop callback) {
    if (handler != nullptr) {
        handler->on_request_stop = callback;
    }
}

void AceWebSchemeHandler::destroySchemeHandler(ArkWeb_SchemeHandler* handler) {
    if (handler != nullptr) {
        delete handler;
        handler = nullptr;
    }
}

ArkWeb_SchemeHandler* AceWebSchemeHandler::CreateArkHandler() {
    ArkWeb_SchemeHandler* handler = new (std::nothrow) ArkWeb_SchemeHandler();
    return handler;
}
