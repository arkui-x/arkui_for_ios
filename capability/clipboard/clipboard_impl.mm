/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
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

#include "adapter/ios/capability/clipboard/clipboard_impl.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UIKit.h>

namespace OHOS::Ace::Platform {

ClipboardImpl::ClipboardImpl(const RefPtr<TaskExecutor>& taskExecutor) : Clipboard(taskExecutor) {}

void ClipboardImpl::SetData(const std::string& data)
{
    if (taskExecutor_) {
        taskExecutor_->PostTask([weak = AceType::WeakClaim(RawPtr(taskExecutor_)),data]{
            auto executor = weak.Upgrade();
            if(executor){
                executor->PostTask([data]{
                    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                    pasteboard.string = [NSString stringWithCString:data.c_str() encoding:NSUTF8StringEncoding];
                },TaskExecutor::TaskType::BACKGROUND);
            }
        },TaskExecutor::TaskType::PLATFORM);
    }
}

void ClipboardImpl::GetData(const std::function<void(const std::string&)>& callback, bool syncMode)
{
    if (callback) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        NSString *stringInPasteboard = pasteboard.string?:@"";
        auto data = stringInPasteboard.UTF8String;
        callback(data);
    }
}

void ClipboardImpl::Clear()
{
    if (taskExecutor_) {
        taskExecutor_->PostTask([weak = AceType::WeakClaim(RawPtr(taskExecutor_))]{
            auto executor = weak.Upgrade();
            if(executor){
                executor->PostTask([]{
                    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                    pasteboard.string = @"";
                },TaskExecutor::TaskType::BACKGROUND);
            }
        },TaskExecutor::TaskType::PLATFORM);
    }
}

} // namespace OHOS::Ace::Platform
