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

#include "ace_clipboard_test.h"

#include <memory>
#include <string>
#include <unistd.h>

#include "ace_init_task_excutor.h"
#include "clipboard_impl.h"

@implementation AceClipboardTest

AceInitTaskExcutor clipboardTaskExcutor;

+ (bool)testInitClipboard {
    std::shared_ptr<OHOS::Ace::Platform::ClipboardImpl> clipboardImpl =
        std::make_shared<OHOS::Ace::Platform::ClipboardImpl>(clipboardTaskExcutor.taskEexcutor_);
    if (clipboardImpl) {
        return true;
    }
    return false;
}

+ (bool)testStringSetAndGet {
    std::shared_ptr<OHOS::Ace::Platform::ClipboardImpl> clipboardImpl =
        std::make_shared<OHOS::Ace::Platform::ClipboardImpl>(clipboardTaskExcutor.taskEexcutor_);
    std::string inputStr = "hello";
    clipboardImpl->SetData(inputStr);
    sleep(1);
    std::string outputStr = "";
    clipboardImpl->GetData([&outputStr](const std::string& data) { outputStr.assign(data); });
    if (outputStr == inputStr) {
        return true;
    }
    return false;
}

+ (bool)testIntSetAndGet {
    std::shared_ptr<OHOS::Ace::Platform::ClipboardImpl> clipboardImpl =
        std::make_shared<OHOS::Ace::Platform::ClipboardImpl>(clipboardTaskExcutor.taskEexcutor_);
    std::string inputStr = "123";
    clipboardImpl->SetData(inputStr);
    sleep(1);
    std::string outputStr = "";
    clipboardImpl->GetData([&outputStr](const std::string& data) { outputStr.assign(data); });
    if (outputStr == inputStr) {
        return true;
    }
    return false;
}

+ (bool)testDoubleSetAndGet {
    std::shared_ptr<OHOS::Ace::Platform::ClipboardImpl> clipboardImpl =
        std::make_shared<OHOS::Ace::Platform::ClipboardImpl>(clipboardTaskExcutor.taskEexcutor_);
    std::string inputStr = "123.123";
    clipboardImpl->SetData(inputStr);
    sleep(1);
    std::string outputStr = "";
    clipboardImpl->GetData([&outputStr](const std::string& data) { outputStr.assign(data); });
    if (outputStr == inputStr) {
        return true;
    }
    return false;
}

+ (bool)testSpecialCharactersSetAndGet {
    std::shared_ptr<OHOS::Ace::Platform::ClipboardImpl> clipboardImpl =
        std::make_shared<OHOS::Ace::Platform::ClipboardImpl>(clipboardTaskExcutor.taskEexcutor_);
    std::string inputStr = "@@###";
    clipboardImpl->SetData(inputStr);
    sleep(1);
    std::string outputStr = "";
    clipboardImpl->GetData([&outputStr](const std::string& data) { outputStr.assign(data); });
    if (outputStr == inputStr) {
        return true;
    }
    return false;
}

+ (bool)testCopyOptionsLocal {
    std::shared_ptr<OHOS::Ace::Platform::ClipboardImpl> clipboardImpl =
        std::make_shared<OHOS::Ace::Platform::ClipboardImpl>(clipboardTaskExcutor.taskEexcutor_);
    std::string inputStr = "hello";
    clipboardImpl->SetData(inputStr, OHOS::Ace::CopyOptions::Local);
    sleep(1);
    std::string outputStr = "";
    clipboardImpl->GetData([&outputStr](const std::string& data) { outputStr.assign(data); });
    if (outputStr == inputStr) {
        return true;
    }
    return false;
}

+ (bool)testCopyOptionsDistributed {
    std::shared_ptr<OHOS::Ace::Platform::ClipboardImpl> clipboardImpl =
        std::make_shared<OHOS::Ace::Platform::ClipboardImpl>(clipboardTaskExcutor.taskEexcutor_);
    std::string inputStr = "hello";
    clipboardImpl->SetData(inputStr, OHOS::Ace::CopyOptions::Distributed);
    sleep(1);
    std::string outputStr = "";
    clipboardImpl->GetData([&outputStr](const std::string& data) { outputStr.assign(data); });
    if (outputStr == inputStr) {
        return true;
    }
    return false;
}

+ (bool)testIsDragData {
    std::shared_ptr<OHOS::Ace::Platform::ClipboardImpl> clipboardImpl =
        std::make_shared<OHOS::Ace::Platform::ClipboardImpl>(clipboardTaskExcutor.taskEexcutor_);
    std::string inputStr = "hello";
    clipboardImpl->SetData(inputStr, OHOS::Ace::CopyOptions::InApp, true);
    sleep(1);
    std::string outputStr = "";
    clipboardImpl->GetData([&outputStr](const std::string& data) { outputStr.assign(data); });
    if (outputStr == inputStr) {
        return true;
    }
    return false;
}

+ (bool)testClear {
    std::shared_ptr<OHOS::Ace::Platform::ClipboardImpl> clipboardImpl =
        std::make_shared<OHOS::Ace::Platform::ClipboardImpl>(clipboardTaskExcutor.taskEexcutor_);
    std::string inputStr = "hello";
    clipboardImpl->SetData(inputStr);
    sleep(1);
    clipboardImpl->Clear();
    std::string outputStr = "";
    clipboardImpl->GetData([&outputStr](const std::string& data) { outputStr.assign(data); });
    if (outputStr == "") {
        return true;
    }
    return false;
}
@end