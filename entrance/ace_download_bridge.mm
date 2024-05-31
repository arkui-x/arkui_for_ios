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

#include "adapter/ios/entrance/ace_download_bridge.h"

#include <string>
#include <vector>
#include <utility>

#import <Foundation/Foundation.h>
#import "DownloadManager.h"

namespace OHOS::Ace::Platform {
bool AceDownloadBridge::download(const std::string& url, std::vector<uint8_t>& dataOut)
{
    NSString *urlstr = [NSString stringWithCString:url.c_str() encoding:NSUTF8StringEncoding];
    NSData *data = [[DownloadManager sharedManager] download:urlstr];
    if (![data isKindOfClass:[NSData class]]) {
        NSLog(@"DownloadManager data class error");
        return false;
    }
    if (!data || data.length == 0) {
        NSLog(@"DownloadManager no data");
        return false;
    }
    int32_t size = (int32_t)data.length;
    const uint8_t *newData = (const uint8_t*)data.bytes;
    std::copy(newData, newData+size, std::back_inserter(dataOut));
    return true;
}
}
