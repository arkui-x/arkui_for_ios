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

#include "AceWebDownloadImpl.h"

AceWebDownloadImpl::AceWebDownloadImpl()
{
    this->guid_ = "";
    this->currentSpeed_ = 0;
    this->percentComplete_ = 0;
    this->totalBytes_ = 0;
    this->state_ = WebDownloadState::PENDING;
    this->method_ = "";
    this->mimeType_ = "";
    this->url_ = "";
    this->suggestedFileName_ = "";
    this->receivedBytes_ = 0;
    this->fullPath_ = "";
    this->lastErrorCode_ = 0;
}

void AceWebDownloadImpl::SetGuid(std::string guid)
{
    guid_ = guid;
}

std::string AceWebDownloadImpl::GetGuid()
{
    return guid_;
}

void AceWebDownloadImpl::SetCurrentSpeed(double speed)
{
    currentSpeed_ = speed;
}

double AceWebDownloadImpl::GetCurrentSpeed()
{
    return currentSpeed_;
}

void AceWebDownloadImpl::SetPercentComplete(double percent)
{
    percentComplete_ = percent;
}

double AceWebDownloadImpl::GetPercentComplete()
{
    return percentComplete_;
}

void AceWebDownloadImpl::SetTotalBytes(int64_t totalBytes)
{
    totalBytes_ = totalBytes;
}

int64_t AceWebDownloadImpl::GetTotalBytes()
{
    return totalBytes_;
}

void AceWebDownloadImpl::SetState(WebDownloadState state)
{
    state_ = state;
}

WebDownloadState AceWebDownloadImpl::GetState()
{
    return state_;
}

void AceWebDownloadImpl::SetMethod(std::string method)
{
    method_ = method;
}

std::string AceWebDownloadImpl::GetMethod()
{
    return method_;
}

void AceWebDownloadImpl::SetMimeType(std::string mimeType)
{
    mimeType_ = mimeType;
}

std::string AceWebDownloadImpl::GetMimeType()
{
    return mimeType_;
}

void AceWebDownloadImpl::SetUrl(std::string url)
{
    url_ = url;
}

std::string AceWebDownloadImpl::GetUrl()
{
    return url_;
}

void AceWebDownloadImpl::SetSuggestedFileName(std::string suggestedFileName)
{
    suggestedFileName_ = suggestedFileName;
}

std::string AceWebDownloadImpl::GetSuggestedFileName()
{
    return suggestedFileName_;
}

void AceWebDownloadImpl::SetReceivedBytes(int64_t receivedBytes)
{
    receivedBytes_ = receivedBytes;
}

int64_t AceWebDownloadImpl::GetReceivedBytes()
{
    return receivedBytes_;
}

void AceWebDownloadImpl::SetFullPath(std::string fullPath)
{
    fullPath_ = fullPath;
}

std::string AceWebDownloadImpl::GetFullPath()
{
    return fullPath_;
}

void AceWebDownloadImpl::SetLastErrorCode(int32_t lastErrorCode)
{
    lastErrorCode_ = lastErrorCode;
}

int32_t AceWebDownloadImpl::GetLastErrorCode()
{
    return lastErrorCode_;
}