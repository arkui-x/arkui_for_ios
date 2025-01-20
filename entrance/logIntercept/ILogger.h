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
#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_LOGINTERCEPT_ILOGGER_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_LOGINTERCEPT_ILOGGER_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ILogger <NSObject>

typedef enum { LOG_DEBUG, LOG_INFO, LOG_WARN, LOG_ERROR, LOG_FATAL } LogLevel;

/**
 * Common interface for logging
 *
 */

@required

/**
 * Log wrapper for print debug log.
 *
 * @param tag message tag
 * @param msg message to print
 */
- (void)d:(NSString*)tag msg:(NSString*)msg;

/**
 * Log wrapper for print info log.
 *
 * @param tag message tag
 * @param msg message to print
 */
- (void)i:(NSString*)tag msg:(NSString*)msg;

/**
 * Log wrapper for print warning log.
 *
 * @param tag message tag
 * @param msg message to print
 */
- (void)w:(NSString*)tag msg:(NSString*)msg;

/**
 * Log wrapper for print error log.
 *
 * @param tag message tag
 * @param msg message to print
 */
- (void)e:(NSString*)tag msg:(NSString*)msg;

/**
 * Log wrapper for print fatal log.
 *
 * @param tag message tag
 * @param msg message to print
 */
- (void)f:(NSString*)tag msg:(NSString*)msg;

@end

NS_ASSUME_NONNULL_END
#endif // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_LOGINTERCEPT_ILOGGER_H
