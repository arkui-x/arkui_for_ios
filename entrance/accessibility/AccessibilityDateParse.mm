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
#import "AccessibilityDateParse.h"

#define MAX_DIGIT_CHAR '9'
#define MAX_TRIMMED_LENGTH 20
#define MAX_SOURCE_LENGTH 30
#define MOON_DIGITS_LENGTH 2
#define YEAR_DIGITS_LENGTH 4

@implementation AccessibilityDateParse

+ (NSDate *)parseDateIfPossible:(NSString *)sourceString
{
    if (sourceString.length == 0 || ![self quickDigitHeuristic:sourceString]) {
        return nil;
    }
    NSString *trimmedString = [sourceString stringByTrimmingCharactersInSet:
                               NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSDate *parsedDate = nil;
    if ((parsedDate = [self tryCachedFormatters:trimmedString])) {
        return parsedDate;
    }
    if ((parsedDate = [self iso8601Parse:trimmedString])) {
        return parsedDate;
    }
    if (trimmedString.length > MAX_TRIMMED_LENGTH) {
        NSString *substringCandidate = [self firstRegexDateSubstring:trimmedString];
        if (substringCandidate.length > 0 && ![substringCandidate isEqualToString:trimmedString]) {
            if ((parsedDate = [self parseDateIfPossible:substringCandidate])) {
                return parsedDate;
            }
        }
    }
    return [self detectorParse:trimmedString];
}

+ (BOOL)quickDigitHeuristic:(NSString *)sourceString
{
    int digitCount = 0;
    for (NSUInteger idx = 0; idx < sourceString.length && digitCount < 4; idx++) {
        unichar ch = [sourceString characterAtIndex:idx];
        if (ch >= '0' && ch <= MAX_DIGIT_CHAR) {
            digitCount++;
        }
    }
    return digitCount >= YEAR_DIGITS_LENGTH;
}

+ (NSArray<NSDateFormatter *> *)formatters
{
    static NSArray<NSDateFormatter *> *formatterArray;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *patternArray = @[
            @"yyyy-MM-dd",
            @"yyyy/MM/dd",
            @"yyyy-M-d",
            @"yyyy/M/d",
            @"yyyyMMdd"
        ];
        NSMutableArray *mutableFormatters = [NSMutableArray array];
        for (NSString *pattern in patternArray) {
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter.dateFormat = pattern;
            [mutableFormatters addObject:formatter];
        }
        formatterArray = mutableFormatters;
    });
    return formatterArray;
}

+ (NSDate *)tryCachedFormatters:(NSString *)sourceString
{
    if (sourceString.length < YEAR_DIGITS_LENGTH || sourceString.length > MAX_SOURCE_LENGTH) {
        return nil;
    }
    for (NSDateFormatter *formatter in [self formatters]) {
        NSDate *parsedDate = [formatter dateFromString:sourceString];
        if (parsedDate) {
            return parsedDate;
        }
    }
    return nil;
}

+ (NSDate *)iso8601Parse:(NSString *)sourceString
{
    if ([sourceString rangeOfString:@"T"].location == NSNotFound) {
        return nil;
    }
    static NSISO8601DateFormatter *isoFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        isoFormatter = [[NSISO8601DateFormatter alloc] init];
        if (@available(iOS 11.0, *)) {
            isoFormatter.formatOptions =
                NSISO8601DateFormatWithInternetDateTime;
        }
    });
    return [isoFormatter dateFromString:sourceString];
}

+ (NSRegularExpression *)inlineRegex
{
    static NSRegularExpression *cachedRegex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *datePattern = [NSString stringWithFormat:@"d{1,%d}",MOON_DIGITS_LENGTH];
        NSString *pattern = [NSString stringWithFormat:
            @"\\b\\d{%d}[-/]\\%@([-/]\\%@)?(?:[ T]\\%@:\\d{2}(:\\d{2})?)?\\b",
            YEAR_DIGITS_LENGTH, datePattern, datePattern, datePattern];
        cachedRegex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                options:0
                                                                  error:nil];
    });
    return cachedRegex;
}

+ (NSString *)firstRegexDateSubstring:(NSString *)sourceString
{
    NSTextCheckingResult *matchResult =
        [[self inlineRegex] firstMatchInString:sourceString
                                       options:0
                                         range:NSMakeRange(0, sourceString.length)];
    if (matchResult) {
        return [sourceString substringWithRange:matchResult.range];
    }
    return nil;
}

+ (NSDataDetector *)sharedDetector
{
    static NSDataDetector *dateDetector;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeDate error:nil];
    });
    return dateDetector;
}

+ (NSDate *)detectorParse:(NSString *)sourceString
{
    __block NSDate *detectedDate = nil;
    [[self sharedDetector] enumerateMatchesInString:sourceString
                                            options:0
                                              range:NSMakeRange(0, sourceString.length)
                                         usingBlock:^(
        NSTextCheckingResult * _Nullable result,
        NSMatchingFlags flags,
        BOOL * _Nonnull stop) {
        if (result.resultType == NSTextCheckingTypeDate) {
            detectedDate = result.date;
            *stop = YES;
        }
    }];
    return detectedDate;
}

+ (NSDateFormatter *)sharedOutputFormatter
{
    static NSDateFormatter *outputFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        outputFormatter = [[NSDateFormatter alloc] init];
        outputFormatter.dateStyle = NSDateFormatterMediumStyle;
        outputFormatter.timeStyle = NSDateFormatterNoStyle;
        outputFormatter.locale = [NSLocale autoupdatingCurrentLocale];
        outputFormatter.timeZone = [NSTimeZone localTimeZone];
    });
    return outputFormatter;
}

@end