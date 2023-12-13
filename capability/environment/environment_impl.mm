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

#include "adapter/ios/capability/environment/environment_impl.h"

#import <UIKit/UIKit.h>

namespace OHOS::Ace::Platform {

EnvironmentImpl::EnvironmentImpl(const RefPtr<TaskExecutor>& taskExecutor) : Environment(taskExecutor) {}

std::string EnvironmentImpl::GetAccessibilityEnabled()
{
    std::string result;
    if (taskExecutor_) {
        taskExecutor_->PostSyncTask([&result] { 
          result = "false";
          // 辅助功能->旁白、切换控制
          bool enabled = UIAccessibilityIsVoiceOverRunning() || UIAccessibilityIsSwitchControlRunning();
          if(enabled){
            result = "true";
          }
        }, TaskExecutor::TaskType::JS);
    }
    return result;
}

} // namespace OHOS::Ace::Platform