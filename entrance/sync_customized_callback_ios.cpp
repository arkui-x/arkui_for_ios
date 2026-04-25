/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
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

#include "core/components_ng/render/adapter/sync_customized_callback.h"

#include <CoreFoundation/CoreFoundation.h>
namespace OHOS::Ace::NG {

std::pair<int32_t, std::shared_ptr<Media::PixelMap>> SyncCustomizedCallback::GetPixelMap(
    std::chrono::duration<int, std::milli> timeout)
{
    std::pair<int32_t, std::shared_ptr<Media::PixelMap>> result(ERROR_CODE_INTERNAL_ERROR, nullptr);
    CFTimeInterval runLoopTimeoutSec = 0.01;
    std::unique_lock<std::mutex> lock(mutex_);
    auto startTime = std::chrono::steady_clock::now();
    while (pixelMap_ == nullptr && errorCode_ == ERROR_CODE_NO_ERROR) {
        auto now = std::chrono::steady_clock::now();
        if (now - startTime > timeout) {
            return { ERROR_CODE_COMPONENT_SNAPSHOT_TIMEOUT, nullptr };
        }
        lock.unlock();
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, runLoopTimeoutSec, true);
        lock.lock();
    }
    if (ERROR_CODE_NO_ERROR != errorCode_) {
        return { errorCode_, nullptr };
    }
    if (pixelMap_) {
        result = { ERROR_CODE_NO_ERROR, pixelMap_ };
    }
    return result;
}

} // namespace OHOS::Ace::NG
