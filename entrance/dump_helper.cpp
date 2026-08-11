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
#include "base/external_instance_id_mapper.h"
#include "base/utils/utils.h"
#include "core/common/ace_engine.h"

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
    int32_t containerId = ExternalInstanceIdMapper::GetInstance().GetInstanceId(
        static_cast<uint32_t>(instanceId));
    if (containerId < 0) {
        containerId = instanceId;
    }
    auto container = AceEngine::Get().GetContainer(containerId);
    CHECK_NULL_VOID(container);
    if (dumpParamsVector.empty()) {
        dumpParamsVector.push_back("-element");
    }
    std::vector<std::string> info;
    container->Dump(dumpParamsVector, info);
    DumpLog::GetInstance().Reset();
}

} // namespace OHOS::Ace::Platform
