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

#include <string>
#include <map>
#include "AceWebPatternBridge.h"
#include "core/components_ng/pattern/web/web_object_event.h"

OHOS::Ace::RefPtr<OHOS::Ace::WebResponse> response_ = nullptr;
void AceWebObject(const std::string& id, const std::string& event, void* object) {
    OHOS::Ace::WebObjectEventManager::GetInstance().OnObjectEvent(id, event, (void *)object);
}
bool AceWebObjectWithBoolReturn(const std::string& id, const std::string& event, void* object) {
    return OHOS::Ace::WebObjectEventManager::GetInstance().OnObjectEventWithBoolReturn(id, event, (void*)object);
}

bool AceWebObjectWithResponseReturn(const std::string& id, const std::string& event, void* object) {
    OHOS::Ace::RefPtr<OHOS::Ace::WebResponse> response =
        OHOS::Ace::WebObjectEventManager::GetInstance().OnObjectEventWithResponseReturn(id, event, (void*)object);
    if (response == nullptr) {
        return false;
    }
    response_ = response;
    return true;
}

void AceWebObjectWithUnResponseReturn(const std::string& id) {
    OHOS::Ace::WebObjectEventManager::GetInstance().UnRegisterObjectEventWithResponseReturn(id);
}

const OHOS::Ace::RefPtr<OHOS::Ace::WebResponse>& AceWebObjectGetResponse(){
    return response_;
}