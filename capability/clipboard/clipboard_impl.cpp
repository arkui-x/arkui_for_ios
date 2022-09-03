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

#include "adapter/android/capability/java/jni/clipboard/clipboard_impl.h"

#include "adapter/android/capability/java/jni/clipboard/clipboard_jni.h"

namespace OHOS::Ace::Platform {

ClipboardImpl::ClipboardImpl(const RefPtr<TaskExecutor>& taskExecutor) : Clipboard(taskExecutor) {}

void ClipboardImpl::SetData(const std::string& data, CopyOptions copyOption)
{
    if (taskExecutor_) {
        taskExecutor_->PostTask([data] { ClipboardJni::SetData(data); }, TaskExecutor::TaskType::PLATFORM);
    }
}

void ClipboardImpl::GetData(const std::function<void(const std::string&)>& callback)
{
    if (taskExecutor_) {
        taskExecutor_->PostTask([callback, taskExecutor = WeakClaim(RawPtr(
                                               taskExecutor_))] { ClipboardJni::GetData(callback, taskExecutor); },
            TaskExecutor::TaskType::PLATFORM);
    }
}

void ClipboardImpl::Clear()
{
    if (taskExecutor_) {
        taskExecutor_->PostTask([] { ClipboardJni::Clear(); }, TaskExecutor::TaskType::PLATFORM);
    }
}

} // namespace OHOS::Ace::Platform
