/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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
 
#import "ParameterHelper.h"

@implementation ParameterHelper

+ (id)objectWithJSONString:(NSString*)jsonString {
    if (!jsonString.length) {
        NSLog(@"no jsonString");
        return nil;
    }
    NSData* jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError* error;
    id jsonObj = [NSJSONSerialization JSONObjectWithData:jsonData
                                                options:kNilOptions
                                                error:&error];
    if (error) {
        NSLog(@"json -> objct faild, error : %@", error);
        return nil;
    }
    
    return jsonObj;
}

+ (NSString*)jsonStringWithObject:(id)object {

    if (![NSJSONSerialization isValidJSONObject:object]) {
        NSLog(@"objct -> json faild, object is not valid");
        return nil;
    }

    NSError* error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:object
                                                        options:kNilOptions
                                                        error:&error];

    NSString* json = [[NSString alloc] initWithData:jsonData
                                            encoding:NSUTF8StringEncoding];
    if (error) {
        NSLog(@"objc -> json faild, error: %@", error);
        return nil;
    }
    return json;
}

@end
