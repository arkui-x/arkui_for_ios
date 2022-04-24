/*
 * Copyright (c) 2021 Huawei Device Co., Ltd.
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

#include "base/log/ace_trace.h"

#include <stdio.h>
#include <stdlib.h>
#include <cstdarg>
#include <cstdint>
#include <string>
#include "base/utils/time_util.h"

namespace OHOS::Ace {

std::string GetTraceTimeStamp()
{
    // time_t tt = time(nullptr);
    // struct timeval tv;
    // struct timezone tz;
    // gettimeofday(&tv, &tz);

    // tm* t = localtime(&tv.tv_sec);
    char time[32];

    if (snprintf(time, 32, " %ld", GetSysTimestamp()) < 0) {
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

} // namespace OHOS::Ace
