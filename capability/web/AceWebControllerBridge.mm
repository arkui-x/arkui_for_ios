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
#include <mutex>
#import "AceWebResourcePlugin.h"
#import "AceWebControllerBridge.h"
#import <Foundation/Foundation.h>

std::map<std::string, std::shared_ptr<AceWebDownloadImpl>> webDownloadImplMap;
std::map<std::string, std::chrono::steady_clock::time_point> lastReceivedTime;
std::map<std::string, int64_t> lastReceivedBytes;
std::mutex webDownloadImplMapMutex;

std::shared_ptr<AceWebDownloadImpl> getWebDownloadImpl(const std::string& guid)
{
    auto it = webDownloadImplMap.find(guid);
    if (it != webDownloadImplMap.end()) {
        return it->second;
    }
    return nullptr;
}

double calculateDownloadSpeed(const std::string& guid, int64_t receivedBytes)
{
    double speed = 0.0;
    auto webDownloadImpl = webDownloadImplMap[guid];
    auto currentTime = std::chrono::steady_clock::now();
    auto lastTime = lastReceivedTime[guid];
    auto lastBytes = lastReceivedBytes[guid];
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(currentTime - lastTime).count();
    if (duration > 0) {
        speed = (receivedBytes - lastBytes) / duration;
    }
    lastReceivedTime[guid] = currentTime;
    lastReceivedBytes[guid] = receivedBytes;
    return speed;
}

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

void zoomInOC(int id) {
    AceWeb *web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (!web) {
        NSLog(@"Error:AceWebControllerBridge web is NULL");
        return;
    }
    [web zoomIn];
}

void zoomOutOC(int id) {
    AceWeb *web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (!web) {
        NSLog(@"Error:AceWebControllerBridge web is NULL");
        return;
    }
    [web zoomOut];
}

bool isZoomAccessOC(int id) {
    AceWeb *web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (!web) {
        NSLog(@"Error:AceWebControllerBridge web is NULL");
        return false;
    }
    return [web isZoomAccess];
}

void stopOC(int id){
    AceWeb *web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if(web != nil){
        [web stop];
    }
}

std::string getOriginalUrlOC(int id) {
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (!web) {
        NSLog(@"Error:AceWebControllerBridge web is NULL");
        return "";
    }
    return [[web getOriginalUrl] UTF8String];
}

void pageUpOC(int id, bool value)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (!web) {
        NSLog(@"Error:AceWebControllerBridge web is NULL");
        return;
    }
    [web pageUp:value];
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

void evaluateJavaScriptOC(int webId, const std::string& script, int32_t asyncCallbackInfoId, void (*callbackOC)(const std::string& result, int32_t asyncCallbackInfoId))
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", webId]];
    if (web == nil) {
        return;
    }
    NSString* ocScript = [NSString stringWithCString:script.c_str() encoding:NSUTF8StringEncoding];
    [web evaluateJavaScript:ocScript
                callback:^(id _Nullable obj, NSError* _Nullable error) {
                    NSString* ocResult = [NSString stringWithFormat:@"%@", obj];
                    callbackOC([ocResult UTF8String], asyncCallbackInfoId);
                }];
}

void evaluateJavaScriptExtOC(int webId, const std::string& script, int32_t asyncCallbackInfoId,
    void (*callbackOC)(const std::string& type, const std::string& result, int32_t asyncCallbackInfoId))
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", webId]];
    if (web == nil) {
        return;
    }
    NSString* ocScript = [NSString stringWithCString:script.c_str() encoding:NSUTF8StringEncoding];
    [web evaluateJavaScript:ocScript
        callback:^(id _Nullable obj, NSError* _Nullable error) {
            NSString* ocType = @"";
            std::string ocResult = "";
            if (error == nil) {
                if ([obj isKindOfClass:[NSString class]]) {
                    ocType = @"STRING";
                    ocResult = [[NSString stringWithFormat:@"%@", obj] UTF8String];
                } else if ([obj isKindOfClass:[NSNumber class]]) {
                    NSNumber* number = (NSNumber*)obj;
                    if (strcmp([obj objCType], @encode(char)) == 0){
                        ocType = @"BOOL";
                        bool boolValue = [number boolValue];
                        ocResult = boolValue ? "true" : "false";
                    } else if (strcmp([obj objCType], @encode(int)) == 0){
                        ocType = @"INT";
                        ocResult = [number stringValue].UTF8String;
                    } else {
                        ocType = @"DOUBLE";
                        ocResult = [number stringValue].UTF8String;
                    }
                } else if ([obj isKindOfClass:[NSArray class]]) {
                    ocType = @"STRINGARRAY";
                    NSArray* array = (NSArray*)obj;
                    if (array.count > 0) {
                        id firstItem = array[0];
                        if ([firstItem isKindOfClass:[NSString class]]) {
                            ocType = @"STRINGARRAY";
                        } else if ([firstItem isKindOfClass:[NSNumber class]]) {
                            NSNumber* number = (NSNumber*)firstItem;
                            if (strcmp([number objCType], @encode(char)) == 0) {
                                ocType = @"BOOLEANARRAY";
                            } else if (strcmp([number objCType], @encode(int)) == 0) {
                                ocType = @"INTARRAY";
                            } else {
                                ocType = @"DOUBLEARRAY";
                            }
                        }
                        
                        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:array options:0 error:nil];
                        NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                        ocResult = [jsonString UTF8String];
                    }
                } else {
                    ocType = @"STRING";
                    ocResult = "This type not support, only string/number/boolean/array is supported";
                }
            } else {
                ocType = @"STRING";
                NSString* errorDescription = [error localizedDescription];
                ocResult = [errorDescription UTF8String];
            }
            callbackOC([ocType UTF8String], ocResult, asyncCallbackInfoId);
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

bool postMessageEventExtOC(int id, const std::shared_ptr<AceWebMessageExtImpl> webMessageExtImpl){
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (web == nil) {
        return false;
    }

    AceWebMessageType msgType = webMessageExtImpl->GetType();
    switch (msgType) {
        case AceWebMessageType::BOOLEAN:
            [web postMessageEventExt:@(webMessageExtImpl->GetBoolean())];
            break;
        case AceWebMessageType::INTEGER:
            [web postMessageEventExt:@(webMessageExtImpl->GetInt())];
            break;
        case AceWebMessageType::DOUBLE:
            [web postMessageEventExt:@(webMessageExtImpl->GetDouble())];
            break;
        case AceWebMessageType::STRING: {
            std::string value = webMessageExtImpl->GetString();
            NSString* ocValue = [NSString stringWithCString:value.c_str() encoding:NSUTF8StringEncoding];
            [web postMessageEventExt:ocValue];
            break;
        }
        case AceWebMessageType::STRINGARRAY: {
            NSMutableArray* ocArray = [NSMutableArray array];
            std::vector<std::string> value = webMessageExtImpl->GetStringArray();
            for (const auto& item : value) {
                NSString* ocItem = [NSString stringWithCString:item.c_str() encoding:NSUTF8StringEncoding];
                [ocArray addObject:ocItem];
            }
            [web postMessageEventExt:ocArray];
            break;
        }
        case AceWebMessageType::BOOLEANARRAY: {
            NSMutableArray* ocArray = [NSMutableArray array];
            std::vector<bool> value = webMessageExtImpl->GetBooleanArray();
            for (const auto& item : value) {
                bool boolValue = item;
                [ocArray addObject:@(boolValue)];
            }
            [web postMessageEventExt:ocArray];
            break;
        }
        case AceWebMessageType::DOUBLEARRAY: {
            NSMutableArray* ocArray = [NSMutableArray array];
            std::vector<double> value = webMessageExtImpl->GetDoubleArray();
            for (const auto& item : value) {
                NSNumber* number = [NSNumber numberWithDouble:item];
                [ocArray addObject:number];
            }
            [web postMessageEventExt:ocArray];
            break;
        }
        case AceWebMessageType::INT64ARRAY: {
            NSMutableArray* ocArray = [NSMutableArray array];
            std::vector<int64_t> value = webMessageExtImpl->GetInt64Array();
            for (const auto& item : value) {
                NSNumber* number = [NSNumber numberWithLongLong:item];
                [ocArray addObject:number];
            }
            [web postMessageEventExt:ocArray];
            break;
        }
        case AceWebMessageType::BINARY: {
            std::vector<uint8_t> value = webMessageExtImpl->GetArrayBuffer();
            NSData* ocData = [NSData dataWithBytes:value.data() length:value.size()];
            [web postMessageEventExt:ocData];
            break;
        }
        case AceWebMessageType::ERROR: {
            std::pair<std::string, std::string> errorInfo = webMessageExtImpl->GetError();
            NSString* errorName = [NSString stringWithCString:errorInfo.first.c_str() encoding:NSUTF8StringEncoding];
            NSString* errorMessage = [NSString stringWithCString:errorInfo.second.c_str() encoding:NSUTF8StringEncoding];
            NSError* error = [NSError errorWithDomain:errorName code:0 userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
            [web postMessageEventExt:error];
            break;
        }
        default:
            break;
    }
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

void onMessageEventExtOC(int webId, const std::string& portHandle,
    void (*callbackOC)(int32_t webId, const std::string& portHandle, 
    const std::shared_ptr<AceWebMessageExtImpl> webMessageExtImpl))
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", webId]];
    if (web == nil) {
        return;
    }

    [web onMessageEventExt:^(id _Nullable ocResult) {
        auto webMessageExtImpl = std::make_shared<AceWebMessageExtImpl>();
        if (webMessageExtImpl == nullptr) {
            NSLog(@"new WebMessageExt failed.");
            return;
        }
        if ([ocResult isKindOfClass:[NSString class]]) {
            webMessageExtImpl->SetString([ocResult UTF8String]);
        } else if ([ocResult isKindOfClass:[NSNumber class]]) {
            NSNumber* number = (NSNumber*)ocResult;
            if (strcmp([ocResult objCType], @encode(char)) == 0) {
                webMessageExtImpl->SetBoolean([number boolValue] ? true : false);
            } else if (strcmp([ocResult objCType], @encode(int)) == 0) {
                webMessageExtImpl->SetInt([number intValue]);
            } else {
                webMessageExtImpl->SetDouble([number doubleValue]);
            }
        } else if ([ocResult isKindOfClass:[NSArray class]]) {
            NSArray* array = (NSArray*)ocResult;
            if (array.count > 0) {
                id firstItem = array[0];
                if ([firstItem isKindOfClass:[NSString class]]) {
                    std::vector<std::string> stringArray;
                    for (NSString* item in array) {
                        stringArray.push_back([item UTF8String]);
                    }
                    webMessageExtImpl->SetStringArray(stringArray);
                } else if ([firstItem isKindOfClass:[NSNumber class]]) {
                    if (strcmp([firstItem objCType], @encode(char)) == 0) {
                        std::vector<bool> boolArray;
                        for (NSNumber* item in array) {
                            boolArray.push_back([item boolValue] ? true : false);
                        }
                        webMessageExtImpl->SetBooleanArray(boolArray);
                    } else if (strcmp([firstItem objCType], @encode(int)) == 0) {
                        std::vector<int64_t> intArray;
                        for (NSNumber* item in array) {
                            intArray.push_back([item intValue]);
                        }
                        webMessageExtImpl->SetInt64Array(intArray);
                    } else {
                        std::vector<double> doubleArray;
                        for (NSNumber* item in array) {
                            doubleArray.push_back([item doubleValue]);
                        }
                        webMessageExtImpl->SetDoubleArray(doubleArray);
                    }
                }
            }
        }
        callbackOC(webId, portHandle, webMessageExtImpl);
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

void setWebDebuggingAccessOC(bool webDebuggingAccess){
    [AceWeb setWebDebuggingAccess:webDebuggingAccess];
}

void pageDownOC(int id, bool value)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (!web) {
        NSLog(@"Error:AceWebControllerBridge web is NULL");
        return;
    }
    [web pageDown:value];
}

void postUrlOC(int id, const std::string& url, const std::vector<uint8_t>& postData)
{
    AceWeb *web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", id]];
    if (!web) {
        NSLog(@"Error:AceWebControllerBridge web is NULL");
        return;
    }
    NSData *data = [NSData dataWithBytes:postData.data() length:postData.size()];
    NSString *nsUrl = [NSString stringWithCString:url.c_str()];
    [web postUrl:nsUrl postData:data];
}

void startDownloadOC(int webId, const std::string& url)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", webId]];
    if (web == nil) {
        return;
    }

    NSString* ocUrl = [NSString stringWithCString:url.c_str() encoding:NSUTF8StringEncoding];
    [web startDownload:ocUrl];
}

void onDownloadBeforeStartOC(int32_t webId, 
    void (*callbackOC)(int32_t webId, const std::shared_ptr<AceWebDownloadImpl> webDownloadImpl))
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", webId]];
    if (web == nil) {
        return;
    }

    [web onDownloadBeforeStart:^(NSString* guid, NSString* method, NSString* mimeType, NSString* url) {
        auto webDownloadImpl = std::make_shared<AceWebDownloadImpl>();
        webDownloadImplMap[[guid UTF8String]] = webDownloadImpl;
        webDownloadImpl->SetGuid([guid UTF8String]);
        webDownloadImpl->SetMethod([method UTF8String]);
        webDownloadImpl->SetMimeType([mimeType UTF8String]);
        webDownloadImpl->SetUrl([url UTF8String]);
        webDownloadImpl->SetState(WebDownloadState::PENDING);
        callbackOC(webId, webDownloadImpl);
    }];
}

void onDownloadUpdatedOC(int32_t webId, 
    void (*callbackOC)(int32_t webId, const std::shared_ptr<AceWebDownloadImpl> webDownloadImpl))
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", webId]];
    if (web == nil) {
        return;
    }
    [web onDownloadUpdated:^(NSString* guid, NSString* state, int64_t totalBytes, int64_t receivedBytes, NSString* suggestedFileName) {
        auto webDownloadImpl = getWebDownloadImpl([guid UTF8String]);
        if (webDownloadImpl != nullptr) {
            if ([state isEqualToString:@"IN_PROGRESS"]) {
                double progress = (double)receivedBytes / (double)totalBytes;
                webDownloadImpl->SetGuid([guid UTF8String]);
                webDownloadImpl->SetTotalBytes(totalBytes);
                webDownloadImpl->SetReceivedBytes(receivedBytes);
                webDownloadImpl->SetLastErrorCode(0);
                webDownloadImpl->SetPercentComplete(progress*100);
                webDownloadImpl->SetCurrentSpeed(calculateDownloadSpeed([guid UTF8String], receivedBytes));
                webDownloadImpl->SetState(WebDownloadState::IN_PROGRESS);
                webDownloadImpl->SetSuggestedFileName([suggestedFileName UTF8String]);
            } else if ([state isEqualToString:@"PAUSED"]) {
                webDownloadImpl->SetState(WebDownloadState::PAUSED);
            } else if ([state isEqualToString:@"PENDING"]) {
                webDownloadImpl->SetState(WebDownloadState::PENDING);
            }
            callbackOC(webId, webDownloadImpl);
        }
    }];
}

void onDownloadFailedOC(int32_t webId, 
    void (*callbackOC)(int32_t webId, const std::shared_ptr<AceWebDownloadImpl> webDownloadImpl))
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", webId]];
    if (web == nil) {
        return;
    }

    [web onDownloadFailed:^(NSString* guid, NSString* state, int64_t code) {
        auto webDownloadImpl = getWebDownloadImpl([guid UTF8String]);
        if (webDownloadImpl != nullptr) {
            webDownloadImpl->SetGuid([guid UTF8String]);
            if ([state isEqualToString:@"CANCELED"]) {
                webDownloadImpl->SetLastErrorCode(40);
                webDownloadImpl->SetState(WebDownloadState::CANCELED);
            } else {
                webDownloadImpl->SetState(WebDownloadState::INTERRUPTED);
            }
            webDownloadImplMap.erase([guid UTF8String]);
            callbackOC(webId, webDownloadImpl);
        }
    }];
}

void onDownloadFinishOC(int32_t webId, 
    void (*callbackOC)(int32_t webId, const std::shared_ptr<AceWebDownloadImpl> webDownloadImpl))
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", webId]];
    if (web == nil) {
        return;
    }

    [web onDownloadFinish:^(NSString* guid, NSString* path) {
        auto webDownloadImpl = getWebDownloadImpl([guid UTF8String]);
        if (webDownloadImpl != nullptr) {
            webDownloadImpl->SetGuid([guid UTF8String]);
            webDownloadImpl->SetFullPath([path UTF8String]);
            webDownloadImpl->SetPercentComplete(100);
            webDownloadImpl->SetReceivedBytes(webDownloadImpl->GetTotalBytes());
            webDownloadImpl->SetState(WebDownloadState::COMPLETE);
            webDownloadImplMap.erase([guid UTF8String]);
            callbackOC(webId, webDownloadImpl);
        }
    }];
}

void webDownloadItemStartOC(int webId, const std::string& guid, const std::string& path)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", webId]];
    if (web == nil) {
        return;
    }

    NSString* ocPath = [NSString stringWithCString:path.c_str() encoding:NSUTF8StringEncoding];
    NSString* ocGuid = [NSString stringWithCString:guid.c_str() encoding:NSUTF8StringEncoding];
    [web webDownloadItemStart:ocGuid ocPath:ocPath];
}

void webDownloadItemCancelOC(int webId, const std::string& guid)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", webId]];
    if (web == nil) {
        return;
    }

    NSString* ocGuid = [NSString stringWithCString:guid.c_str() encoding:NSUTF8StringEncoding];
    [web webDownloadItemCancel:ocGuid];
    webDownloadImplMap.erase(guid);
}

void webDownloadItemPauseOC(int webId, const std::string& guid)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", webId]];
    if (web == nil) {
        return;
    }
    NSString* ocGuid = [NSString stringWithCString:guid.c_str() encoding:NSUTF8StringEncoding];
    [web webDownloadItemPause:ocGuid];
}

void webDownloadItemResumeOC(int webId, const std::string& guid)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", webId]];
    if (web == nil) {
        return;
    }
    NSString* ocGuid = [NSString stringWithCString:guid.c_str() encoding:NSUTF8StringEncoding];
    [web webDownloadItemResume:ocGuid];
}
