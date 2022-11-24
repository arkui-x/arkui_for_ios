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

#ifndef ACE_INIT_TASK_EXCUTOR_H
#define ACE_INIT_TASK_EXCUTOR_H

#include "flutter/common/task_runners.h"
#include "flutter/fml/task_runner.h"

#include "base/thread/background_task_executor.h"
#include "base/thread/task_executor.h"
#include "core/common/flutter/flutter_task_executor.h"

class AceInitTaskExcutor {
public:
    AceInitTaskExcutor();
    ~AceInitTaskExcutor() = default;
    OHOS::Ace::RefPtr<OHOS::Ace::TaskExecutor> taskEexcutor_;

private:
    const std::string label_ = "task executor";
    std::unique_ptr<fml::Thread> ThreadFirst_ = std::make_unique<fml::Thread>("thread_1");
    std::unique_ptr<fml::Thread> ThreadSecond_ = std::make_unique<fml::Thread>("thread_2");
    std::unique_ptr<fml::Thread> ThreadThird_ = std::make_unique<fml::Thread>("thread_3");
    std::unique_ptr<fml::Thread> ThreadFourth_ = std::make_unique<fml::Thread>("thread_4");
    fml::RefPtr<fml::TaskRunner> platform_ = ThreadFirst_->GetTaskRunner();
    fml::RefPtr<fml::TaskRunner> gpu_ = ThreadSecond_->GetTaskRunner();
    fml::RefPtr<fml::TaskRunner> ui_ = ThreadThird_->GetTaskRunner();
    fml::RefPtr<fml::TaskRunner> io_ = ThreadFourth_->GetTaskRunner();
};

#endif // ACE_INIT_TASK_EXCUTOR_H