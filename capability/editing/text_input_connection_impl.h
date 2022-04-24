/*
 * Copyright (c) 2021 Huawei Device Co., Ltd.
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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_CAPABILITY_EDITING_TEXT_INPUT_CONNECTION_IMPL_H
#define FOUNDATION_ACE_ADAPTER_IOS_CAPABILITY_EDITING_TEXT_INPUT_CONNECTION_IMPL_H

#include "core/common/ime/text_input_client.h"
#include "core/common/ime/text_input_connection.h"
#include "core/common/ime/text_input_configuration.h"

namespace OHOS::Ace::Platform {

class TextInputConnectionImpl : public TextInputConnection {
public:
    explicit TextInputConnectionImpl(const WeakPtr<TextInputClient>& client,const RefPtr<TaskExecutor>& taskExecutor);
    TextInputConnectionImpl(const WeakPtr<TextInputClient>& client, const RefPtr<TaskExecutor>& taskExecutor,const TextInputConfiguration& config);
    ~TextInputConnectionImpl() override = default;

    // Implement TextInputConnection
    void Show(bool isFocusViewChanged, int32_t instanceId) override;
    void SetEditingState(const TextEditingValue& value, int32_t instanceId, bool needFireChangeEvent) override;
    void Close(int32_t instanceId) override;
    
private:
    TextInputConnectionImpl() = delete;
    bool Attached();
    TextInputConfiguration config_;
    bool needFireChangeEvent_ = true;
};

} // namespace OHOS::Ace::Platform

#endif // FOUNDATION_ACE_ADAPTER_IOS_CAPABILITY_EDITING_TEXT_INPUT_CONNECTION_IMPL_H