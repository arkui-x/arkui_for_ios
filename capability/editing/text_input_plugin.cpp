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

#include "adapter/ios/capability/editing/text_input_plugin.h"

#include "adapter/ios/capability/editing/text_input_client_handler.h"
#include "adapter/ios/capability/editing/text_input_connection_impl.h"
#include "base/log/log.h"

namespace OHOS::Ace::Platform {

RefPtr<TextInputConnection> TextInputPlugin::Attach(const WeakPtr<TextInputClient>& client,
    const TextInputConfiguration& config, const RefPtr<TaskExecutor>& taskExecutor, int32_t instanceId)
{
    LOGE("vail->iOSTxtInput::Attach");
    auto connection = AceType::MakeRefPtr<TextInputConnectionImpl>(client, taskExecutor, config);
    TextInputClientHandler::GetInstance().SetCurrentConnection(connection);
    return connection;
}

} // namespace OHOS::Ace::Platform
