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

#include "ace_init_task_excutor.h"

AceInitTaskExcutor::AceInitTaskExcutor() {
    std::promise<void> promiseInit;
    std::future<void> futureInit = promiseInit.get_future();
    flutter::TaskRunners taskRunner(label_, platform_, gpu_, ui_, io_);
    auto flutterTaskExecutor = OHOS::Ace::Referenced::MakeRefPtr<OHOS::Ace::FlutterTaskExecutor>();
    platform_->PostTask([&promiseInit, flutterTaskExecutor]() {
        flutterTaskExecutor->InitPlatformThread();
        promiseInit.set_value();
    });
    flutterTaskExecutor->InitJsThread();
    flutterTaskExecutor->InitOtherThreads(taskRunner);
    futureInit.wait();
    taskEexcutor_ = flutterTaskExecutor;
}