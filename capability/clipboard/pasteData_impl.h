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

#ifndef FOUNDATION_ARKUI_ACE_ENGINE_ADAPTER_IOS_CAPABILITY_CLIPBOARD_PASTEDATA_IMPL_H
#define FOUNDATION_ARKUI_ACE_ENGINE_ADAPTER_IOS_CAPABILITY_CLIPBOARD_PASTEDATA_IMPL_H
 
#include "multiType_record_impl.h"
 
namespace OHOS::Ace {
 
class PasteDataImpl : public PasteDataMix {
    DECLARE_ACE_TYPE(PasteDataImpl, PasteDataMix);
 
 public:
    PasteDataImpl();
    ~PasteDataImpl() = default;

    void AddRecord(const RefPtr<MultiTypeRecordImpl>& record);

    const std::vector<RefPtr<MultiTypeRecordImpl>>& GetRecords() const;
 
 private:
    std::vector<RefPtr<MultiTypeRecordImpl>> records_;
 };
 
 } // namespace OHOS::Ace
 
 #endif // FOUNDATION_ARKUI_ACE_ENGINE_ADAPTER_IOS_CAPABILITY_CLIPBOARD_PASTEDATA_IMPL_H
 