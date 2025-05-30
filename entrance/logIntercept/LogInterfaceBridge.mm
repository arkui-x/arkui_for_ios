/*
 * Copyright (c) 2024-2025 Huawei Device Co., Ltd.
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

#import "LogInterfaceBridge.h"

#import <Foundation/Foundation.h>
#include <iostream>
#include <string>

#import "Logger.h"

namespace {
    OHOS::Ace::LogLevel g_currentLogLevel = OHOS::Ace::LogLevel::ERROR;
}

void SetLevel(int level)
{
    OHOS::Ace::LogWrapper::SetLogLevel(static_cast<OHOS::Ace::LogLevel>(level));
    g_currentLogLevel = static_cast<OHOS::Ace::LogLevel>(level);
}

bool HasDelegateMethod()
{
    return [[Logger sharedInstance] isOsDelegateLog];
}

void PassLogMessageOC(const std::string& domain, const int& level, const std::string& logInfo)
{
    NSString* strLogInfo = [NSString stringWithUTF8String:logInfo.c_str()];
    NSString* strDomain = [NSString stringWithUTF8String:domain.c_str()];
    [[Logger sharedInstance] PassLogMessage:strDomain level:level info:strLogInfo];
}

OHOS::Ace::LogLevel GetCurrentLogLevel()
{
    return g_currentLogLevel;
}