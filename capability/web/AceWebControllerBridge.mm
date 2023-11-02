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
#import "AceWebControllerBridge.h"

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

void loadDataOC(int id, const std::string& data, const std::string& mimeType, const std::string& encoding,
    const std::string& baseUrl, const std::string& historyUrl)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return;
    }
    NSString* ocData = [NSString stringWithCString:data.c_str() encoding:NSUTF8StringEncoding];
    NSString* ocMimeType = [NSString stringWithCString:mimeType.c_str() encoding:NSUTF8StringEncoding];
    NSString* ocEncoding = [NSString stringWithCString:encoding.c_str() encoding:NSUTF8StringEncoding];
    NSString* ocBaseUrl = [NSString stringWithCString:baseUrl.c_str() encoding:NSUTF8StringEncoding];
    NSString* ocHistoryUrl = [NSString stringWithCString:historyUrl.c_str() encoding:NSUTF8StringEncoding];
    [web loadData:ocData mimeType:ocMimeType encoding:ocEncoding baseUrl:ocBaseUrl historyUrl:ocHistoryUrl];
}

void EvaluateJavaScriptOC(int id, const std::string& script, void (*callbackOC)(const std::string& result))
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return;
    }
    NSString* ocScript = [NSString stringWithCString:script.c_str() encoding:NSUTF8StringEncoding];
    [web EvaluateJavaScript:ocScript
                   callback:^(NSString* ocResult) {
                     callbackOC([ocResult UTF8String]);
                   }];
}

std::string getUrlOC(int id)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return "";
    }
    return [[web getUrl] UTF8String];
}

bool accessBackwardOC(int id)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return false;
    }
    return [web accessBackward];
}

bool accessForwardOC(int id)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return false;
    }
    return [web accessForward];
}

void backwardOC(int id)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return;
    }
    [web backward];
}

void forwardOC(int id)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return;
    }
    [web forward];
}

void refreshOC(int id)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return;
    }
    [web refresh];
}
