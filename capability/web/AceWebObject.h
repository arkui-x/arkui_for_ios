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

#ifndef AceWebObject_hpp
#define AceWebObject_hpp

#include <iostream>
#include <string>
class AceWebOnScrollObject {
public:
    AceWebOnScrollObject(const float x, const float y) : x_(x), y_(y) {}
    float GetX();
    float GetY();

private:
    float x_;
    float y_;
};

class AceWebOnScaleChangeObject {
public:
    AceWebOnScaleChangeObject(const float newScale, const float oldScale) : newScale_(newScale), oldScale_(oldScale) {}
    float GetNewScale();
    float GetOldScale();

private:
    float newScale_;
    float oldScale_;
};

class AceWebOnConsoleObject {
public:
    AceWebOnConsoleObject(const std::string& message, const int messageLevel)
        : message_(message), messageLevel_(messageLevel)
    {}
    std::string GetMessage();
    int GetMessageLevel();

private:
    std::string message_;
    int messageLevel_;
};

class AceWebHttpErrorReceiveObject {
public:
    AceWebHttpErrorReceiveObject(
        const std::string& url, const std::string& mimeType_, const std::string& contentEncoding, const int statusCode)
        : requestUrl_(url), mimeType_(mimeType_), contentEncoding_(contentEncoding), statusCode_(statusCode)
    {}
    std::string GetRequestUrl();
    std::string GetMimeType();
    std::string GetEncoding();
    int GetStatusCode();

private:
    std::string requestUrl_;
    std::string mimeType_;
    std::string contentEncoding_;
    int statusCode_;
};

#endif /* AceWebObject_hpp */