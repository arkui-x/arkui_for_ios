/*
 * Copyright (c) 2024-2026 Huawei Device Co., Ltd.
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

#include "adapter/ios/capability/vibrator/haptic_vibrator.h"
#include "core/common/vibrator/vibrator_utils.h"

namespace OHOS::Ace::NG {
namespace {
const std::string VIBRATOR_TYPE_LONG_PRESS_LIGHT = "haptic.long_press_light";
const std::string VIBRATOR_TYPE_SLIDE = "haptic.slide";
const std::string VIBRATOR_TYPE_SLIDE_LIGHT = "haptic.slide";
const std::string VIBRATOR_TYPE_INVALID = "vibrator.type.invalid";

const std::string GetVibratorType(const std::string& vibratorType)
{
    if (vibratorType == "longPress.light") {
        return VIBRATOR_TYPE_LONG_PRESS_LIGHT;
    } else if (vibratorType == "slide") {
        return VIBRATOR_TYPE_SLIDE;
    } else if (vibratorType == "slide.light") {
        return VIBRATOR_TYPE_SLIDE_LIGHT;
    }
    return VIBRATOR_TYPE_INVALID;
}
} // namespace

void VibratorUtils::StartVibraFeedback()
{
    Platform::HapticVibrator::StartVibraFeedback(VIBRATOR_TYPE_SLIDE);
}

void VibratorUtils::StartVibraFeedback(const std::string& vibratorType)
{
    const std::string realVibratorType = GetVibratorType(vibratorType);
    if (realVibratorType != VIBRATOR_TYPE_INVALID) {
        Platform::HapticVibrator::StartVibraFeedback(realVibratorType);
    }
}

void VibratorUtils::StartViratorDirectly(const std::string& vibratorType)
{
    Platform::HapticVibrator::StartVibraFeedback(vibratorType);
}
} // namespace OHOS::Ace::NG
