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

#import "WantParams.h"

@implementation WantParams

typedef enum {
    VALUE_TYPE_DEFAULT = 0,
    VALUE_TYPE_BOOL = 1,
    VALUE_TYPE_INT = 5,
    VALUE_TYPE_DOUBLE = 9,
    VALUE_TYPE_STRING = 10,
    VALUE_TYPE_WANT_PARAMS = 101,
    VALUE_TYPE_ARRAY = 102,
} VALUE_TYPE;

- (NSMutableArray*)arrWantParams
{
    if (!_arrWantParams) {
        _arrWantParams = [[NSMutableArray alloc]init];
    }
    return _arrWantParams;
}

- (NSMutableDictionary*)dicWantParams
{
    if (!_dicWantParams) {
        _dicWantParams = [[NSMutableDictionary alloc]init];
    }
    return _dicWantParams;
}

- (void)addValue:(NSString*)key value:(id)value
{
    if (key == nil || value == nil) {
        return;
    }
    [self.dicWantParams setObject:value forKey:key];
    int valueType = VALUE_TYPE_DEFAULT;
    if ([value isKindOfClass:[NSNumber class]]) {
        valueType = [self getType:value];
        if (valueType == VALUE_TYPE_DOUBLE) {
            value = [NSDecimalNumber decimalNumberWithDecimal:[value decimalValue]];
        }
    } else if ([value isKindOfClass:[NSString class]]) {
        valueType = VALUE_TYPE_STRING;
    } else if ([value isKindOfClass:[WantParams class]]) {
        WantParams* wantParams = (WantParams*)value;
        valueType = VALUE_TYPE_WANT_PARAMS;
        NSDictionary* dic = @{ @"key" : key, @"type" : @(valueType), @"value" : wantParams.arrWantParams };
        [self.arrWantParams addObject:dic];
        return;
    } else if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSMutableArray class]]) {
        valueType = VALUE_TYPE_ARRAY;
        NSDictionary* dic = @{ @"key" : key, @"type" : @(valueType), @"value" : value };
        [self.arrWantParams addObject:dic];
        return;
    } else {
        NSLog(@"WantParams type error");
        return;
    }
    NSDictionary* dic = @{ @"key" : key, @"type" : @(valueType), @"value" : value };
    [self.arrWantParams addObject:dic];
}

- (int)getType:(id)value
{
    if (strcmp([value objCType], @encode(char)) == 0 || strcmp([value objCType], @encode(BOOL)) == 0) {
        return VALUE_TYPE_BOOL;
    } else if (strcmp([value objCType], @encode(int)) == 0) {
        return VALUE_TYPE_INT;
    } else if (strcmp([value objCType], @encode(double)) == 0 || strcmp([value objCType], @encode(float)) == 0) {
        return VALUE_TYPE_DOUBLE;
    }
    return VALUE_TYPE_DEFAULT;
}

- (NSString*)toWantParamsString
{
    NSString* strParams = @"";
    NSDictionary* dicParams = @{ @"params" : self.arrWantParams };
    if ([NSJSONSerialization isValidJSONObject:dicParams]) {
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:dicParams
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:nil];
        if (jsonData) {
            strParams = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            strParams = [self formatString:strParams];
        }
    }
    return strParams;
}

- (NSString*)formatString:(NSString*)strParams
{
    if (strParams == nil) {
        return @"";
    }
    strParams = [strParams stringByReplacingOccurrencesOfString:@" " withString:@""];
    strParams = [strParams stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    strParams = [strParams stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    strParams = [strParams stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    return strParams;
}

- (id)getValue:(NSString*)key
{
    if (key == nil || self.dicWantParams == nil) {
        return nil;
    }
    NSArray *arrKey = self.dicWantParams.allKeys;
    if (![key isKindOfClass:[NSString class]] || ![arrKey containsObject:key]) {
        return nil;
    }
    return self.dicWantParams[key];
}
@end