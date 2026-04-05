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

#ifndef FOUNDATION_ACE_ENGINE_ADAPTER_IOS_CAPABILITY_VIBRATOR_HAPTIC_VIBRATOR_H
#define FOUNDATION_ACE_ENGINE_ADAPTER_IOS_CAPABILITY_VIBRATOR_HAPTIC_VIBRATOR_H

#include <string>

namespace OHOS::Ace::Platform {
class HapticVibrator {
public:
    HapticVibrator() = delete;
    ~HapticVibrator() = delete;

    static void StartVibraFeedback(const std::string& effectId);
};
} // namespace OHOS::Ace::Platform

#endif // FOUNDATION_ACE_ENGINE_ADAPTER_IOS_CAPABILITY_VIBRATOR_HAPTIC_VIBRATOR_H
