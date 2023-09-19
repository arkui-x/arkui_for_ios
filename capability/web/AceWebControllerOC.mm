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

#include <string>
#include <map>
#import "AceWebResourcePlugin.h"
#import "AceWebControllerOC.h"

#import <Foundation/Foundation.h>

void loadUrlOC(int id, const std::string& url, std::map<std::string, std::string> httpHeaders) {

    AceWeb *web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if(web == nil){
        return;
    }
    NSString *ocUrl = [NSString stringWithCString:url.c_str() encoding:NSUTF8StringEncoding];
    NSMutableDictionary * dict = [NSMutableDictionary dictionary];
    for (auto it = httpHeaders.begin(); it != httpHeaders.end(); it++) {
        NSString * key = (0 == it->first.length())?(@""):(@(it->first.c_str()));
        NSString * value = (0 == it->second.length())?(@""):(@(it->second.c_str()));
        [dict setObject:value forKey:key];
    }
    
    NSDictionary * nd = [NSDictionary dictionaryWithDictionary:dict];

    [web loadUrl:ocUrl header:nd];
}



