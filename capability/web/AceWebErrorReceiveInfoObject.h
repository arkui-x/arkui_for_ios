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

#ifndef AceWebErrorReceiveInfoObject_hpp
#define AceWebErrorReceiveInfoObject_hpp
#include <string>
#include <iostream>

class AceWebErrorReceiveInfoObject {
public:
    AceWebErrorReceiveInfoObject(const std::string& url,const std::string& info, long code):
                requestUrl_(url), errorInfo_(info), errorCode_(code) {}
    std::string GetRequestUrl();
    std::string GetErrorInfo();
    long GetErrorCode();
private:
    std::string requestUrl_;
    std::string errorInfo_ ;
    long errorCode_ = 0;
};

#endif /* AceWebErrorReceiveInfoObject_hpp */
