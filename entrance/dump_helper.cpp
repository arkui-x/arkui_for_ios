/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

#include "dump_helper.h"

#include <time.h>
#include "base/log/dump_log.h"
#include "base/log/log.h"
#include "core/common/ace_engine.h"
#include "core/common/container.h"

namespace OHOS::Ace::Platform {

void DumpHelper::Dump(int32_t instanceId, std::vector<std::string> dumpParamsVector)
{
    time_t currentTime = std::time(NULL);
    char chCurrentTime[64];
    std::strftime(chCurrentTime, sizeof(chCurrentTime), "%Y%m%d%H%M%S", std::localtime(&currentTime));
    std::string stCurrentTime = chCurrentTime;
    std::string filename = Ace::AceApplicationInfo::GetInstance().GetDataFileDirPath() + "/arkui_dump_" + stCurrentTime + ".txt";

    FILE *fp = fopen(filename.c_str(), "wb");
    if (fp == nullptr) {
        LOGE("Dump failed: fp is nullptr");
        return;
    }
    DumpLog::DumpFile* file = new DumpLog::DumpFile(fp);

    if (file == nullptr) {
        LOGE("Dump failed: file is nullptr");
        return;
    }
    DumpLog::GetInstance().SetDumpFile(file);
    auto container = AceEngine::Get().GetContainer(instanceId);
    CHECK_NULL_VOID(container);
    std::vector<std::string> info;
    if (dumpParamsVector.empty()) {
        dumpParamsVector.push_back("-element");
    }
    container->Dump(dumpParamsVector, info);
    DumpLog::GetInstance().Reset();
}

} // namespace OHOS::Ace::Platform
