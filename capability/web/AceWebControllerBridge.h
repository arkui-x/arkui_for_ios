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

void stopOC(int id);

void setCustomUserAgentOC(int id, const std::string& userAgent);

std::string getCustomUserAgentOC(int id);

void loadDataOC(int id, const std::string& data, const std::string& mimeType, const std::string& encoding,
    const std::string& baseUrl, const std::string& historyUrl);

void EvaluateJavaScriptOC(int id, const std::string& script, int32_t asyncCallbackInfoId, void (*callbackOC)(const std::string& ocResult, int32_t asyncCallbackInfoId));

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

void onMessageEventOC(int id, const std::string& portHandle,
    void (*callbackOC)(int32_t webId, const std::string& portHandle, const std::string& result));

void closePortOC(int id);

bool saveHttpAuthCredentialsOC(
    const std::string& host, const std::string& realm, const std::string& username, const char* password);

bool getHttpAuthCredentialsOC(const std::string& host, const std::string& realm,
    std::string& username, char* password, uint32_t passwordSize);

bool existHttpAuthCredentialsOC();

bool deleteHttpAuthCredentialsOC();
