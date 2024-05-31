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

#include <map>
#include <string>
#include <vector>
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

bool accessStepOC(int id, int32_t step){
    AceWeb *web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if(web != nil){
        return [web accessStep:step];
    }
    return false;
}

void scrollToOC(int id, float x, float y){
    AceWeb *web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if(web != nil){
        [web scrollTo:x y:y];
    }
}

void scrollByOC(int id, float deltaX, float deltaY){
    AceWeb *web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if(web != nil){
        [web scrollBy:deltaX deltaY:deltaY];
    }
}

void zoomOC(int id, float factor){
    AceWeb *web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if(web != nil){
        [web zoom:factor];
    }
}

void stopOC(int id){
    AceWeb *web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if(web != nil){
        [web stop];
    }
}

void setCustomUserAgentOC(int id, const std::string& userAgent){
    AceWeb *web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if(web != nil){
        NSString *ocUserAgent = [NSString stringWithCString:userAgent.c_str() encoding:NSUTF8StringEncoding];
        [web setCustomUserAgent:ocUserAgent];
    }
}

std::string getCustomUserAgentOC(int id){
    AceWeb *web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if(web == nil){
        return "";
    }
    return [[web getCustomUserAgent] UTF8String];
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

void EvaluateJavaScriptOC(int id, const std::string& script, int32_t asyncCallbackInfoId, void (*callbackOC)(const std::string& result, int32_t asyncCallbackInfoId))
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return;
    }
    NSString* ocScript = [NSString stringWithCString:script.c_str() encoding:NSUTF8StringEncoding];
    [web EvaluateJavaScript:ocScript
                   callback:^(NSString* ocResult) {
                     callbackOC([ocResult UTF8String], asyncCallbackInfoId);
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

void removeCacheOC(int id, bool value)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return;
    }
    [web removeCache:value];
}

void backOrForwardOC(int id, int32_t step)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return;
    }
    [web backOrForward:step];
}

std::string getTitleOC(int id)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return "";
    }
    return [[web getTitle] UTF8String];
}

int32_t getPageHeightOC(int id)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return 0;
    }
    return (int)[web getPageHeight];
}

BackForwardResult getBackForwardEntriesOC(int id)
{
    BackForwardResult backForwardResult;
    BackForwardItem backForwardItem;
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web != nil) {
        NSArray* backList = web.getWeb.backForwardList.backList;
        NSArray* forwardList = web.getWeb.backForwardList.forwardList;
        backForwardResult.currentIndex = (int)backList.count;
        for (WKBackForwardListItem* backItem in backList) {
            backForwardItem.URL = [[backItem.URL absoluteString] UTF8String];
            backForwardItem.title = [backItem.title UTF8String];
            backForwardItem.initialURL = [[backItem.initialURL absoluteString] UTF8String];
            backForwardResult.backForwardItemList.push_back(backForwardItem);
        }
        backForwardItem.URL = [[web.getWeb.backForwardList.currentItem.URL absoluteString] UTF8String];
        backForwardItem.title = [web.getWeb.backForwardList.currentItem.title UTF8String];
        backForwardItem.initialURL = [[web.getWeb.backForwardList.currentItem.initialURL absoluteString] UTF8String];
        backForwardResult.backForwardItemList.push_back(backForwardItem);
        for (WKBackForwardListItem* forwardItem in forwardList) {
            backForwardItem.URL = [[forwardItem.URL absoluteString] UTF8String];
            backForwardItem.title = [forwardItem.title UTF8String];
            backForwardItem.initialURL = [[forwardItem.initialURL absoluteString] UTF8String];
            backForwardResult.backForwardItemList.push_back(backForwardItem);
        }
    }
    return backForwardResult;
}

void createWebMessagePortsOC(int id, std::vector<std::string>& ports)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return;
    }

    NSArray* portsName = @[ @"port1", @"port2" ];
    [web createWebMessagePorts:portsName];
    ports.push_back([portsName[0] UTF8String]);
    ports.push_back([portsName[1] UTF8String]);
}

void postWebMessageOC(int id, std::string& message, std::vector<std::string>& ports, std::string& targetUrl)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return;
    }
    NSString* ocMessage = [NSString stringWithCString:message.c_str() encoding:NSUTF8StringEncoding];
    NSString* ocTargetUrl = [NSString stringWithCString:targetUrl.c_str() encoding:NSUTF8StringEncoding];

    for (const auto& port : ports) {
        NSString* ocPort = [NSString stringWithCString:port.c_str() encoding:NSUTF8StringEncoding];
        [web postWebMessage:ocMessage port:ocPort targetUrl:ocTargetUrl];
    }
}

bool postMessageEventOC(int id, const std::string& message)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return false;
    }
    NSString* ocMessage = [NSString stringWithCString:message.c_str() encoding:NSUTF8StringEncoding];
    [web postMessageEvent:ocMessage];
    return true;
}

void onMessageEventOC(int id, const std::string& portHandle,
    void (*callbackOC)(int32_t webId, const std::string& portHandle, const std::string& result))
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return;
    }

    [web onMessageEvent:^(NSString* ocResult) {
      callbackOC(id, portHandle, [ocResult UTF8String]);
    }];
}

void closePortOC(int id)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return;
    }
    [web closePort];
}

bool saveHttpAuthCredentialsOC(
    const std::string& host, const std::string& realm, const std::string& username, const char* password)
{
    NSString* ocHost = [NSString stringWithCString:host.c_str() encoding:NSUTF8StringEncoding];
    NSString* ocRealm = [NSString stringWithCString:realm.c_str() encoding:NSUTF8StringEncoding];
    NSString* ocUsername = [NSString stringWithCString:username.c_str() encoding:NSUTF8StringEncoding];
    NSString* ocPassword = [NSString stringWithUTF8String:password];
    return [AceWeb saveHttpAuthCredentials:ocHost realm:ocRealm username:ocUsername password:ocPassword];
}

bool getHttpAuthCredentialsOC(const std::string& host, const std::string& realm, std::string& username, char* password, uint32_t passwordSize)
{
    NSString* ocHost = [NSString stringWithCString:host.c_str() encoding:NSUTF8StringEncoding];
    NSString* ocRealm = [NSString stringWithCString:realm.c_str() encoding:NSUTF8StringEncoding];
    NSURLCredential* value = [AceWeb getHttpAuthCredentials:ocHost realm:ocRealm];
    if (value == nil) {
        return false;
    }
    username = [value.user UTF8String];
    strlcpy(password, (char*)[value.password UTF8String], passwordSize);
    return true;
}

bool existHttpAuthCredentialsOC()
{
    return [AceWeb existHttpAuthCredentials];
}

bool deleteHttpAuthCredentialsOC()
{
    return [AceWeb deleteHttpAuthCredentials];
}
