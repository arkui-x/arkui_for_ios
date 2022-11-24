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

#include "ace_storage_test.h"

#include <memory>
#include <string>

#include "ace_init_task_excutor.h"
#include "storage_impl.h"

@implementation AceStorageTest

AceInitTaskExcutor storageTaskExcutor;

+ (bool)testInitStorage {
    std::shared_ptr<OHOS::Ace::Platform::StorageImpl> storageImpl =
        std::make_shared<OHOS::Ace::Platform::StorageImpl>(storageTaskExcutor.taskEexcutor_);
    if (storageImpl) {
        return true;
    }
    return false;
}

+ (bool)testString {
    std::shared_ptr<OHOS::Ace::Platform::StorageImpl> storageImpl =
        std::make_shared<OHOS::Ace::Platform::StorageImpl>(storageTaskExcutor.taskEexcutor_);
    std::string key = "testString";
    std::string inputStr = "hello";
    storageImpl->SetString(key, inputStr);
    std::string outputStr = storageImpl->GetString(key);
    if (outputStr != inputStr) {
        return false;
    }
    return true;
}

+ (bool)testIntString {
    std::shared_ptr<OHOS::Ace::Platform::StorageImpl> storageImpl =
        std::make_shared<OHOS::Ace::Platform::StorageImpl>(storageTaskExcutor.taskEexcutor_);
    std::string key = "testIntString";
    std::string inputStr = "123";
    storageImpl->SetString(key, inputStr);
    std::string outputStr = storageImpl->GetString(key);
    if (outputStr != inputStr) {
        return false;
    }
    return true;
}

+ (bool)testDoubleString {
    std::shared_ptr<OHOS::Ace::Platform::StorageImpl> storageImpl =
        std::make_shared<OHOS::Ace::Platform::StorageImpl>(storageTaskExcutor.taskEexcutor_);
    std::string key = "testDoubleString";
    std::string inputStr = "123.312";
    storageImpl->SetString(key, inputStr);
    std::string outputStr = storageImpl->GetString(key);
    if (outputStr != inputStr) {
        return false;
    }
    return true;
}

+ (bool)testSpecialCharactersString {
    std::shared_ptr<OHOS::Ace::Platform::StorageImpl> storageImpl =
        std::make_shared<OHOS::Ace::Platform::StorageImpl>(storageTaskExcutor.taskEexcutor_);
    std::string key = "testSpecialCharactersString";
    std::string inputStr = "@@##";
    storageImpl->SetString(key, inputStr);
    std::string outputStr = storageImpl->GetString(key);
    if (outputStr != inputStr) {
        return false;
    }
    return true;
}

+ (bool)testEmptyString {
    std::shared_ptr<OHOS::Ace::Platform::StorageImpl> storageImpl =
        std::make_shared<OHOS::Ace::Platform::StorageImpl>(storageTaskExcutor.taskEexcutor_);
    std::string key = "testEmptyString";
    std::string inputStr = "";
    storageImpl->SetString(key, inputStr);
    std::string outputStr = storageImpl->GetString(key);
    if (outputStr != inputStr) {
        return false;
    }
    return true;
}

+ (bool)testDouble {
    std::shared_ptr<OHOS::Ace::Platform::StorageImpl> storageImpl =
        std::make_shared<OHOS::Ace::Platform::StorageImpl>(storageTaskExcutor.taskEexcutor_);
    std::string key = "testDouble";
    double inputDouble = 10.23;
    storageImpl->SetDouble(key, inputDouble);
    double outputDouble = 0.0;
    storageImpl->GetDouble(key, outputDouble);
    if (inputDouble != outputDouble) {
        return false;
    }
    return true;
}

+ (bool)testZeroDouble {
    std::shared_ptr<OHOS::Ace::Platform::StorageImpl> storageImpl =
        std::make_shared<OHOS::Ace::Platform::StorageImpl>(storageTaskExcutor.taskEexcutor_);
    std::string key = "testZeroDouble";
    double inputDouble = 0;
    storageImpl->SetDouble(key, inputDouble);
    double outputDouble = 1.1;
    storageImpl->GetDouble(key, outputDouble);
    if (inputDouble != outputDouble) {
        return false;
    }
    return true;
}

+ (bool)testBoolean {
    std::shared_ptr<OHOS::Ace::Platform::StorageImpl> storageImpl =
        std::make_shared<OHOS::Ace::Platform::StorageImpl>(storageTaskExcutor.taskEexcutor_);
    std::string key = "testBoolean";
    bool inputBool = true;
    storageImpl->SetBoolean(key, inputBool);
    bool outputBool = false;
    storageImpl->GetBoolean(key, outputBool);
    if (!outputBool) {
        return false;
    }
    return true;
}

+ (bool)testClear {
    std::shared_ptr<OHOS::Ace::Platform::StorageImpl> storageImpl =
        std::make_shared<OHOS::Ace::Platform::StorageImpl>(storageTaskExcutor.taskEexcutor_);
    std::string key = "testClear";
    std::string inputStr = "hello";
    storageImpl->SetString(key, inputStr);
    storageImpl->Clear();
    std::string outputStr = storageImpl->GetString(key);
    if (outputStr != "") {
        return false;
    }
    return true;
}

+ (bool)testDelete {
    std::shared_ptr<OHOS::Ace::Platform::StorageImpl> storageImpl =
        std::make_shared<OHOS::Ace::Platform::StorageImpl>(storageTaskExcutor.taskEexcutor_);
    std::string key = "testDelete";
    std::string inputStr = "hello";
    storageImpl->SetString(key, inputStr);
    storageImpl->Delete(key);
    std::string outputStr = storageImpl->GetString(key);
    if (outputStr != "") {
        return false;
    }
    return true;
}
@end