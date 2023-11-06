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

void loadUrlOC(int id, const std::string& url, std::map<std::string, std::string> httpHeaders);

void loadDataOC(int id, const std::string& data, const std::string& mimeType, const std::string& encoding,
    const std::string& baseUrl, const std::string& historyUrl);

void EvaluateJavaScriptOC(int id, const std::string& script, void (*callbackOC)(const std::string& ocResult));

void backwardOC(int id);

void forwardOC(int id);

void refreshOC(int id);

std::string getUrlOC(int id);

bool accessBackwardOC(int id);

bool accessForwardOC(int id);

bool saveHttpAuthCredentialsOC(
    const std::string& host, const std::string& realm, const std::string& username, const char* password);

bool getHttpAuthCredentialsOC(const std::string& host, const std::string& realm,
    std::string& username, char* password, uint32_t passwordSize);

bool existHttpAuthCredentialsOC();

bool deleteHttpAuthCredentialsOC();
