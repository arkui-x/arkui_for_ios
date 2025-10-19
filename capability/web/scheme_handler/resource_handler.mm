/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

#import <Foundation/Foundation.h>
#include "resource_handler.h"

int32_t ArkWeb_ResourceHandler::DidReceiveResponse(const ArkWeb_Response* response) {
    if (response == nullptr) {
        return -1;
    }
    response_ = response;
    return 0;
}

int32_t ArkWeb_ResourceHandler::DidReceiveData(const uint8_t* buffer, int64_t bufLen) {
    if (buffer == nullptr || bufLen <= 0) {
        return -1;
    }
    NSData *data = [NSData dataWithBytes:buffer length:bufLen];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    const char *utf8String = [str UTF8String];
    if (utf8String != nullptr) {
        buffer_ = std::string(utf8String);
    }
    bufferLen_ = bufLen;
    return 0;
}

int32_t ArkWeb_ResourceHandler::DidFinish() {
    isFinished_ = true;
    return 0;
}

int32_t ArkWeb_ResourceHandler::DidFailWithError(int32_t error_code, const std::string& errorDescription, bool completeIfNoResponse) {
    isFailed_ = true;
    errorCode_ = error_code;
    errorDescription_ = errorDescription;
    if (completeIfNoResponse && response_ == nullptr) {
        ArkWeb_Response *response = new ArkWeb_Response();
        response->errorCode_ = ARKWEB_ERR_CONNECTION_FAILED;
        response->errorDescription_ = "ERR_CONNECTION_FAILED";
        response_ = response;
    }
    return 0;
}

void ArkWeb_ResourceHandler::DestroyArkWebResourceHandler()
{
    if (response_ != nullptr) {
        delete response_;
        response_ = nullptr;
    }
    buffer_.clear();
    bufferLen_ = 0;
    isFinished_ = false;
    isFailed_ = false;
    errorCode_ = 0;
    errorDescription_ = "";
}
