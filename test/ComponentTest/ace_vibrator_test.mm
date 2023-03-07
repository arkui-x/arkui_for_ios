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

#include "ace_vibrator_test.h"

#include <memory>
#include <string>

#include "ace_init_task_excutor.h"
#include "vibrator_impl.h"

@implementation AceVibratorTest

AceInitTaskExcutor vibratorTaskExcutor;

+ (bool)testInitVibrator {
  std::shared_ptr<OHOS::Ace::Platform::VibratorImpl> vibratorImpl =
      std::make_shared<OHOS::Ace::Platform::VibratorImpl>(
          vibratorTaskExcutor.taskEexcutor_);
  if (vibratorImpl) {
    return true;
  }
  return false;
}

+ (bool)testVibrateInt {
  int32_t duration = 1;
  std::shared_ptr<OHOS::Ace::Platform::VibratorImpl> vibratorImpl =
      std::make_shared<OHOS::Ace::Platform::VibratorImpl>(
          vibratorTaskExcutor.taskEexcutor_);
  vibratorImpl->Vibrate(duration);
  return true;
}

+ (bool)testVibrateString {
  std::string effectId = "123";
  std::shared_ptr<OHOS::Ace::Platform::VibratorImpl> vibratorImpl =
      std::make_shared<OHOS::Ace::Platform::VibratorImpl>(
          vibratorTaskExcutor.taskEexcutor_);
  vibratorImpl->Vibrate(effectId);
  return true;
}

@end