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

#ifndef ACE_WEB_SCHEME_HANDLER_H
#define ACE_WEB_SCHEME_HANDLER_H

#include <functional>
#include <iostream>
#include <memory>
#include <string>

#include "foundation/arkui/ace_engine/frameworks/base/utils/macros.h"
#include "scheme_handler/response.h"
#include "scheme_handler/scheme_handler.h"
#include "scheme_handler/resource_request.h"
#include "scheme_handler/resource_handler.h"

class ACE_EXPORT AceWebSchemeHandler {
public:
    AceWebSchemeHandler() = default;
    ~AceWebSchemeHandler() = default;

    static void setOnRequestStart(ArkWeb_SchemeHandler* handler, ArkWeb_OnRequestStart callback);
    static void setOnRequestStop(ArkWeb_SchemeHandler* handler, ArkWeb_OnRequestStop callback);
    static void destroySchemeHandler(ArkWeb_SchemeHandler* handler);
    static ArkWeb_SchemeHandler* CreateArkHandler();
};

#endif // ACE_WEB_SCHEME_HANDLER_H
