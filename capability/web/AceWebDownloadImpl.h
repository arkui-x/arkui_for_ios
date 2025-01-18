/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef AceWebDownloadImpl_hpp
#define AceWebDownloadImpl_hpp

#include <string>
#include "foundation/arkui/ace_engine/frameworks/base/utils/macros.h"

enum class ACE_EXPORT WebDownloadState : int{
    IN_PROGRESS = 0,
    COMPLETE,
    CANCELED,
    INTERRUPTED,
    PENDING,
    PAUSED,
    MAX_DOWNLOAD_STATE,
};

class ACE_EXPORT AceWebDownloadImpl {
public:
    AceWebDownloadImpl();
    ~AceWebDownloadImpl() = default;

    void SetGuid(const std::string& guid);
    std::string GetGuid();

    void SetCurrentSpeed(double speed);
    double GetCurrentSpeed();

    void SetPercentComplete(double percent);
    double GetPercentComplete();

    void SetTotalBytes(int64_t totalBytes);
    int64_t GetTotalBytes();

    void SetState(WebDownloadState state);
    WebDownloadState GetState();

    void SetMethod(const std::string& method);
    std::string GetMethod();

    void SetMimeType(const std::string& mimeType);
    std::string GetMimeType();

    void SetUrl(const std::string& url);
    std::string GetUrl();

    void SetSuggestedFileName(const std::string& suggestedFileName);
    std::string GetSuggestedFileName();

    void SetReceivedBytes(int64_t receivedBytes);
    int64_t GetReceivedBytes();

    void SetFullPath(const std::string& fullPath);
    std::string GetFullPath();

    void SetLastErrorCode(int32_t lastErrorCode);
    int32_t GetLastErrorCode();
private:
    std::string guid_;
    double currentSpeed_;
    double percentComplete_;
    int64_t totalBytes_;
    WebDownloadState state_;
    std::string method_;
    std::string mimeType_;
    std::string url_;
    std::string suggestedFileName_;
    int64_t receivedBytes_;
    std::string fullPath_;
    int32_t lastErrorCode_;
};
#endif /* AceWebDownloadImpl_hpp */