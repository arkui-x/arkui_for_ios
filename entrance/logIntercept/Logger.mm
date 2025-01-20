/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

#import "Logger.h"

#import "LogInterfaceBridge.h"

#define LOG_MIN_LEVEL 0
#define LOG_MAX_LEVEL 4

@implementation Logger

+ (instancetype)sharedInstance
{
    static Logger* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)NativeSetLogLevel:(int)logLevel
{
    if (logLevel < LOG_MIN_LEVEL || logLevel > LOG_MAX_LEVEL) {
        return;
    }
    SetLevel(logLevel);
}

- (void)NativeSetLogger:(id)log
{
    self.delegate = log;
}

- (void)PassLogMessage:(NSString*)strDomain level:(int)level info:(NSString*)strInfo
{
    if (![self.delegate respondsToSelector:@selector(d:msg:)]) {
        return;
    }

    switch (level) {
        case LOG_DEBUG:
            [self.delegate d:strDomain msg:strInfo];
            break;
        case LOG_INFO:
            [self.delegate i:strDomain msg:strInfo];
        case LOG_WARN:
            [self.delegate w:strDomain msg:strInfo];
            break;
        case LOG_ERROR:
            [self.delegate e:strDomain msg:strInfo];
            break;
        case LOG_FATAL:
            [self.delegate f:strDomain msg:strInfo];
            break;
        default:
            [self.delegate i:strDomain msg:strInfo];
            break;
    };
}

- (BOOL)isOsDelegateLog
{
    if ([self.delegate respondsToSelector:@selector(d:msg:)]) {
        return YES;
    }
    return NO;
}

@end
