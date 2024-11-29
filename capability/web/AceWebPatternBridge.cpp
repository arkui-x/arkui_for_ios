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
#include "frameworks/core/components_ng/pattern/web/cross_platform/web_object_event.h"

void AceWebObject(const std::string& id, const std::string& event, void* object) {
    OHOS::Ace::WebObjectEventManager::GetInstance().OnObjectEvent(id, event, (void *)object);
}
bool AceWebObjectWithBoolReturn(const std::string& id, const std::string& event, void* object) {
    return OHOS::Ace::WebObjectEventManager::GetInstance().OnObjectEventWithBoolReturn(id, event, (void*)object);
}
