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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_CAPABILITY_CLIPBOARD_CLIPBOARD_PROXY_IMPL_H
#define FOUNDATION_ACE_ADAPTER_IOS_CAPABILITY_CLIPBOARD_CLIPBOARD_PROXY_IMPL_H

#include "core/common/clipboard/clipboard.h"

namespace OHOS::Ace::Platform {

class ClipboardImpl final : public Clipboard {
public:
    explicit ClipboardImpl(const RefPtr<TaskExecutor>& taskEexcutor);
    ~ClipboardImpl() override = default;

    void SetData(
        const std::string& data, CopyOptions copyOption = CopyOptions::InApp, bool isDragData = false) override;
    void GetData(const std::function<void(const std::string&)>& callback, bool syncMode = false) override;
    void SetPixelMapData(const RefPtr<PixelMap>& pixmap, CopyOptions copyOption = CopyOptions::InApp) override {}
    void GetPixelMapData(const std::function<void(const RefPtr<PixelMap>&)>& callback, bool syncMode = false) override
    {}
    void Clear() override;

private:
    ACE_DISALLOW_COPY_AND_MOVE(ClipboardImpl);
};

} // namespace OHOS::Ace::Platform

#endif // FOUNDATION_ACE_ADAPTER_IOS_CAPABILITY_CLIPBOARD_CLIPBOARD_PROXY_IMPL_H
