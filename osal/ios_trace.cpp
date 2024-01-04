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

#include <cstdarg>
#include <cstdint>
#include <stdio.h>
#include <stdlib.h>
#include <string>

#include "securec.h"

#include "base/log/ace_trace.h"
#include "base/utils/time_util.h"
#include "frameworks/base/log/trace_id.h"
namespace OHOS::Ace {

class TraceIdImpl : public TraceId {};

TraceId* TraceId::CreateTraceId()
{
    return new TraceIdImpl();
}

std::string GetTraceTimeStamp()
{
    char time[32];

    if (snprintf_s(time, sizeof(time), sizeof(time) - 1, " %ld", GetSysTimestamp()) < 0) {
        return std::string();
    }
    return std::string(time);
}

bool AceTraceEnabled()
{
    return false;
}

void AceTraceBegin(const char* name)
{
    printf(">>>>> trace start! %s:%s\n", GetTraceTimeStamp().c_str(), name);
}

void AceTraceEnd()
{
    printf(">>>>> trace end! %s\n", GetTraceTimeStamp().c_str());
}

void AceAsyncTraceBegin(int32_t taskId, const char* name, bool isAnimationTrace) {}

void AceAsyncTraceEnd(int32_t taskId, const char* name, bool isAnimationTrace) {}

void AceCountTrace(const char *key, int32_t count)
{
}
} // namespace OHOS::Ace
