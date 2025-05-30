/*
 * Copyright (c) 2022-2025 Huawei Device Co., Ltd.
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

#include "base/log/log_wrapper.h"

#ifdef _GNU_SOURCE
#include <dlfcn.h>
#endif
#include <mutex>

#include <thread>

#include "securec.h"

#ifdef ACE_INSTANCE_LOG
#include "core/common/container.h"
#endif

#import <os/log.h>
#include "LogInterfaceBridge.h"

namespace OHOS::Ace {
namespace {

constexpr uint32_t MAX_BUFFER_SIZE = 4000; // MAX_BUFFER_SIZE same with hilog
constexpr uint32_t MAX_TIME_SIZE = 32;
const char* const LOGLEVELNAME[] = { "DEBUG", "INFO", "WARNING", "ERROR", "FATAL" };

static void StripFormatString(const std::string& prefix, std::string& str)
{
    for (auto pos = str.find(prefix, 0); pos != std::string::npos; pos = str.find(prefix, pos)) {
        str.erase(pos, prefix.size());
    }
}

const char* LOG_TAGS[] = {
    "Ace",
    "Console",
};

#ifdef ACE_INSTANCE_LOG
constexpr const char* INSTANCE_ID_GEN_REASONS[] = {
    "scope",
    "active",
    "default",
    "singleton",
    "foreground",
    "undefined",
};
#endif

} // namespace

// initial static member object
LogLevel LogWrapper::level_ = LogLevel::DEBUG;

const char* GetNameForLogLevel(LogLevel level)
{
    if (level <= LogLevel::FATAL) {
        return LOGLEVELNAME[static_cast<int>(level)];
    }
    return "UNKNOWN";
}

char LogWrapper::GetSeparatorCharacter()
{
    return '/';
}

std::string GetTimeStamp()
{
    time_t tt = time(nullptr);
    tm* t = localtime(&tt);
    char time[MAX_TIME_SIZE];

    if (sprintf_s(time, MAX_TIME_SIZE, " %02d/%02d %02d:%02d:%02d", t->tm_mon + 1, t->tm_mday, t->tm_hour, t->tm_min,
            t->tm_sec) < 0) {
        return std::string();
    }
    return std::string(time);
}

constexpr os_log_type_t LOG_TYPE[] = { OS_LOG_TYPE_DEBUG, OS_LOG_TYPE_INFO, OS_LOG_TYPE_DEFAULT, OS_LOG_TYPE_ERROR,
    OS_LOG_TYPE_FAULT };
    
void LogWrapper::PrintLog(LogDomain domain, LogLevel level, AceLogTag tag, const char* fmt, va_list args)
{
    if (!OHOS::Ace::LogWrapper::JudgeLevel(level)) {
        return;
    }
    std::string newFmt(fmt);
    StripFormatString("{public}", newFmt);
    StripFormatString("{private}", newFmt);

    char buf[MAX_BUFFER_SIZE];
    if (vsnprintf_s(buf, sizeof(buf), sizeof(buf) - 1, newFmt.c_str(), args) < 0 && errno == EINVAL) {
        return;
    }

    if (HasDelegateMethod() && level >= GetCurrentLogLevel()) {
        std::string logInfo(buf);
        PassLogMessageOC(LOG_TAGS[static_cast<uint32_t>(domain)], static_cast<int>(level), logInfo);
        return;
    }

    os_log_type_t logType = LOG_TYPE[static_cast<int>(level)];
    os_log_t log = os_log_create(LOG_TAGS[static_cast<uint32_t>(domain)], GetNameForLogLevel(level));
    os_log(log, "[%{public}s] %{public}s", GetNameForLogLevel(level), buf);
}

#ifdef ACE_INSTANCE_LOG
int32_t LogWrapper::GetId()
{
    return Container::CurrentId();
}

const std::string LogWrapper::GetIdWithReason()
{
    int32_t currentId = ContainerScope::CurrentId();
    std::pair<int32_t, InstanceIdGenReason> idWithReason = ContainerScope::CurrentIdWithReason();
    return std::to_string(currentId) + ":" + std::to_string(idWithReason.first) + ":" +
           INSTANCE_ID_GEN_REASONS[static_cast<uint32_t>(idWithReason.second)];
}
#endif

bool LogBacktrace(size_t maxFrameNums)
{
    static const char* (*pfnGetTrace)(size_t, size_t);
#ifdef _GNU_SOURCE
    if (!pfnGetTrace) {
        pfnGetTrace = (decltype(pfnGetTrace))dlsym(RTLD_DEFAULT, "GetTrace");
    }
#endif
    if (!pfnGetTrace) {
        return false;
    }

    static std::mutex mtx;
    std::lock_guard lock(mtx);
    size_t skipFrameNum = 2;
    LOGI("Backtrace: skipFrameNum=%{public}zu maxFrameNums=%{public}zu\n%{public}s",
        skipFrameNum, maxFrameNums, pfnGetTrace(skipFrameNum, maxFrameNums));
    return true;
}

} // namespace OHOS::Ace
