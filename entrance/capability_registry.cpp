/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
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

#include "adapter/ios/entrance/capability_registry.h"

#include "adapter/ios/capability/clipboard/clipboard_proxy_impl.h"
#include "adapter/ios/capability/editing/text_input_plugin.h"
#include "adapter/ios/capability/environment/environment_proxy_impl.h"
#include "adapter/ios/capability/storage/storage_proxy_impl.h"
#include "adapter/ios/capability/vibrator/vibrator_proxy_impl.h"
#include "core/common/clipboard/clipboard_proxy.h"
#include "core/common/environment/environment_proxy.h"
#include "core/common/ime/text_input_proxy.h"
#include "core/common/storage/storage_proxy.h"
#include "core/common/vibrator/vibrator_proxy.h"

namespace OHOS::Ace::Platform {

void CapabilityRegistry::Register()
{
    ClipboardProxy::GetInstance()->SetDelegate(std::make_unique<ClipboardProxyImpl>());
    TextInputProxy::GetInstance().SetDelegate(std::make_unique<TextInputPlugin>());
    EnvironmentProxy::GetInstance()->SetDelegate(std::make_unique<EnvironmentProxyImpl>());
    StorageProxy::GetInstance()->SetDelegate(std::make_unique<StorageProxyImpl>());
    VibratorProxy::GetInstance().SetDelegate(std::make_unique<VibratorProxyImpl>());
}

} // namespace OHOS::Ace::Platform
