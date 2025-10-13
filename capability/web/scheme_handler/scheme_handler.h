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

#ifndef ACE_ENGINE_ADAPTER_IOS_CAPABILITY_WEB_SCHEME_HANDLER_H
#define ACE_ENGINE_ADAPTER_IOS_CAPABILITY_WEB_SCHEME_HANDLER_H

struct ArkWeb_ResourceRequest;
struct ArkWeb_ResourceHandler;
typedef void (*ArkWeb_OnRequestStart)(struct ArkWeb_SchemeHandler* schemeHandler,
                                     struct ArkWeb_ResourceRequest* resourceRequest,
                                     ArkWeb_ResourceHandler* resourceHandler,
                                     bool* intercept);

typedef void (*ArkWeb_OnRequestStop)(struct ArkWeb_SchemeHandler* schemeHandler,
                                     struct ArkWeb_ResourceRequest* resourceRequest);

struct ArkWeb_SchemeHandler {
  ArkWeb_OnRequestStart on_request_start;
  ArkWeb_OnRequestStop on_request_stop;
  void* user_data{nullptr};
  bool fromEts = false;
};

#endif  // ACE_ENGINE_ADAPTER_IOS_CAPABILITY_WEB_SCHEME_HANDLER_H
