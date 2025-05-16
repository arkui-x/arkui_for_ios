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
#include <list>
#include "AceWebMessageExtImpl.h"
#include "AceWebDownloadImpl.h"
#include "web_javascript_value.h"

struct BackForwardItem{
    std::string URL;
    std::string title;
    std::string initialURL;
};

struct BackForwardResult{
    int currentIndex;
    std::list<BackForwardItem> backForwardItemList;
};

void loadUrlOC(int id, const std::string& url, std::map<std::string, std::string> httpHeaders);

bool accessStepOC(int id, int32_t step);

void scrollToOC(int id, float x, float y);

void scrollByOC(int id, float deltaX, float deltaY);

void zoomOC(int id, float factor);

void zoomInOC(int id);

void zoomOutOC(int id);

bool isZoomAccessOC(int id);

void stopOC(int id);

std::string getOriginalUrlOC(int id);

void pageUpOC(int id, bool value);

void setCustomUserAgentOC(int id, const std::string& userAgent);

std::string getCustomUserAgentOC(int id);

void loadDataOC(int id, const std::string& data, const std::string& mimeType, const std::string& encoding,
    const std::string& baseUrl, const std::string& historyUrl);

void evaluateJavaScriptOC(int webId, const std::string& script, int32_t asyncCallbackInfoId, void (*callbackOC)(const std::string& ocResult, int32_t asyncCallbackInfoId));

void evaluateJavaScriptExtOC(int webId, const std::string& script, int32_t asyncCallbackInfoId, 
    void (*callbackOC)(const std::string& type, const std::string& ocResult, int32_t asyncCallbackInfoId));

void backwardOC(int id);

void forwardOC(int id);

void refreshOC(int id);

std::string getUrlOC(int id);

bool accessBackwardOC(int id);

bool accessForwardOC(int id);

void removeCacheOC(int id, bool value);

void backOrForwardOC(int id, int32_t step);

std::string getTitleOC(int id);

int32_t getPageHeightOC(int id);

BackForwardResult getBackForwardEntriesOC(int id);

void createWebMessagePortsOC(int id, std::vector<std::string>& ports);

void postWebMessageOC(int id, std::string& message, std::vector<std::string>& ports, std::string& targetUrl);

bool postMessageEventOC(int id, const std::string& message);

bool postMessageEventExtOC(int id, const std::shared_ptr<AceWebMessageExtImpl> webMessageExtImpl);

void onMessageEventOC(int id, const std::string& portHandle,
    void (*callbackOC)(int32_t webId, const std::string& portHandle, const std::string& result));

void onMessageEventExtOC(int webId, const std::string& portHandle,
    void (*callbackOC)(int32_t webId, const std::string& portHandle, 
    const std::shared_ptr<AceWebMessageExtImpl> webMessageExtImpl));

void closePortOC(int id);

bool saveHttpAuthCredentialsOC(
    const std::string& host, const std::string& realm, const std::string& username, const char* password);

bool getHttpAuthCredentialsOC(const std::string& host, const std::string& realm,
    std::string& username, char* password, uint32_t passwordSize);

bool existHttpAuthCredentialsOC();

bool deleteHttpAuthCredentialsOC();

void setWebDebuggingAccessOC(bool webDebuggingAccess);

void pageDownOC(int id, bool value);

void postUrlOC(int id, const std::string& url, const std::vector<uint8_t>& postData);

void startDownloadOC(int webId, const std::string& url);

void onDownloadBeforeStartOC(int32_t webId,
    void (*callbackOC)(int32_t webId, const std::shared_ptr<AceWebDownloadImpl> webDownloadImpl));

void onDownloadUpdatedOC(int32_t webId,
    void (*callbackOC)(int32_t webId, const std::shared_ptr<AceWebDownloadImpl> webDownloadImpl));

void onDownloadFailedOC(int32_t webId,
    void (*callbackOC)(int32_t webId, const std::shared_ptr<AceWebDownloadImpl> webDownloadImpl));

void onDownloadFinishOC(int32_t webId,
    void (*callbackOC)(int32_t webId, const std::shared_ptr<AceWebDownloadImpl> webDownloadImpl));

void webDownloadItemStartOC(int webId, const std::string& guid, const std::string& path);

void webDownloadItemCancelOC(int webId, const std::string& guid);

void webDownloadItemPauseOC(int webId, const std::string& guid);

void webDownloadItemResumeOC(int webId, const std::string& guid);

void registerJavaScriptProxyOC(int webId, const std::string& objName, 
    const std::vector<std::string>& syncMethodList, const std::vector<std::string>& asyncMethodList,
    std::shared_ptr<OHOS::Ace::WebJSValue> (*callbackOC)(const std::string& objName,
    const std::string& methodName, const std::vector<std::shared_ptr<OHOS::Ace::WebJSValue>>& args));

void deleteJavaScriptRegisterOC(int webId, const std::string& objName);
