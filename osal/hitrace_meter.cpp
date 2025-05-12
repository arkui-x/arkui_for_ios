/*
 * Copyright (C) 2025 Huawei Device Co., Ltd.
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

#include "hitrace_meter.h"

#include "ui/base/macros.h"

ACE_FORCE_EXPORT void UpdateTraceLabel() {}

ACE_FORCE_EXPORT void SetTraceDisabled(bool disable) {}

ACE_FORCE_EXPORT void StartTrace(uint64_t tag, const std::string& name, float limit) {}

ACE_FORCE_EXPORT void StartTraceEx(HiTraceOutputLevel level, uint64_t tag, const char* name, const char* customArgs) {}

ACE_FORCE_EXPORT void StartTraceDebug(bool isDebug, uint64_t tag, const std::string& name, float limit) {}

ACE_FORCE_EXPORT void StartTraceArgs(uint64_t tag, const char* fmt, ...) {}

ACE_FORCE_EXPORT void StartTraceArgsDebug(bool isDebug, uint64_t tag, const char* fmt, ...) {}

ACE_FORCE_EXPORT void StartTraceWrapper(uint64_t tag, const char* name) {}

ACE_FORCE_EXPORT void FinishTrace(uint64_t tag) {}

ACE_FORCE_EXPORT void FinishTraceEx(HiTraceOutputLevel level, uint64_t tag) {}

ACE_FORCE_EXPORT void FinishTraceDebug(bool isDebug, uint64_t tag) {}

ACE_FORCE_EXPORT void StartAsyncTrace(uint64_t tag, const std::string& name, int32_t taskId, float limit) {}

ACE_FORCE_EXPORT void StartAsyncTraceEx(HiTraceOutputLevel level, uint64_t tag, const char* name, int32_t taskId,
    const char* customCategory, const char* customArgs) {}

ACE_FORCE_EXPORT void StartAsyncTraceDebug(bool isDebug, uint64_t tag, const std::string& name, int32_t taskId,
    float limit) {}

ACE_FORCE_EXPORT void StartAsyncTraceArgs(uint64_t tag, int32_t taskId, const char* fmt, ...) {}

ACE_FORCE_EXPORT void StartAsyncTraceArgsDebug(bool isDebug, uint64_t tag, int32_t taskId, const char* fmt, ...) {}

ACE_FORCE_EXPORT void StartAsyncTraceWrapper(uint64_t tag, const char* name, int32_t taskId) {}

ACE_FORCE_EXPORT void StartTraceChain(uint64_t tag, const struct HiTraceIdStruct* hiTraceId, const char* name) {}

ACE_FORCE_EXPORT void FinishAsyncTrace(uint64_t tag, const std::string& name, int32_t taskId) {}

ACE_FORCE_EXPORT void FinishAsyncTraceEx(HiTraceOutputLevel level, uint64_t tag, const char* name, int32_t taskId) {}

ACE_FORCE_EXPORT void FinishAsyncTraceDebug(bool isDebug, uint64_t tag, const std::string& name, int32_t taskId) {}

ACE_FORCE_EXPORT void FinishAsyncTraceArgs(uint64_t tag, int32_t taskId, const char* fmt, ...) {}

ACE_FORCE_EXPORT void FinishAsyncTraceArgsDebug(bool isDebug, uint64_t tag, int32_t taskId, const char* fmt, ...) {}

ACE_FORCE_EXPORT void FinishAsyncTraceWrapper(uint64_t tag, const char* name, int32_t taskId) {}

ACE_FORCE_EXPORT void MiddleTrace(uint64_t tag, const std::string& beforeValue, const std::string& afterValue) {}

ACE_FORCE_EXPORT void MiddleTraceDebug(bool isDebug, uint64_t tag, const std::string& beforeValue,
    const std::string& afterValue) {}

ACE_FORCE_EXPORT void CountTrace(uint64_t tag, const std::string& name, int64_t count) {}

ACE_FORCE_EXPORT void CountTraceEx(HiTraceOutputLevel level, uint64_t tag, const char* name, int64_t count) {}

ACE_FORCE_EXPORT void CountTraceDebug(bool isDebug, uint64_t tag, const std::string& name, int64_t count) {}

ACE_FORCE_EXPORT void CountTraceWrapper(uint64_t tag, const char* name, int64_t count) {}

ACE_FORCE_EXPORT bool IsTagEnabled(uint64_t tag)
{
    return false;
}

ACE_FORCE_EXPORT void ParseTagBits(const uint64_t tag, std::string& bitStrs) {}

ACE_FORCE_EXPORT int StartCaptureAppTrace(TraceFlag flag, uint64_t tags, uint64_t limitSize, std::string& fileName)
{
    return 0;
}

ACE_FORCE_EXPORT int StopCaptureAppTrace(void)
{
    return 0;
}

ACE_FORCE_EXPORT HitracePerfScoped::HitracePerfScoped(bool isDebug, uint64_t tag, const std::string& name) :
    mTag_(tag), mName_(name) {}

ACE_FORCE_EXPORT HitracePerfScoped::~HitracePerfScoped() {}

ACE_FORCE_EXPORT HitraceMeterFmtScoped::HitraceMeterFmtScoped(uint64_t tag, const char* fmt, ...) : mTag(tag) {}
