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

#include "frameworks/base/utils/utils.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UIKit.h>

namespace OHOS::Ace::Platform {

void ClipboardImpl::AddPixelMapRecord(const RefPtr<PasteDataMix>& pasteData, const RefPtr<PixelMap>& pixmap) {}
void ClipboardImpl::AddImageRecord(const RefPtr<PasteDataMix>& pasteData, const std::string& uri) {}
void ClipboardImpl::AddTextRecord(const RefPtr<PasteDataMix>& pasteData, const std::string& selectedStr) {}
void ClipboardImpl::SetData(const RefPtr<PasteDataMix>& pasteData, CopyOptions copyOption) {}
void ClipboardImpl::GetData(const std::function<void(const std::string&, bool isLastRecord)>& textCallback,
    const std::function<void(const RefPtr<PixelMap>&, bool isLastRecord)>& pixelMapCallback,
    const std::function<void(const std::string&, bool isLastRecord)>& urlCallback, bool syncMode)
{}

RefPtr<PasteDataMix> ClipboardImpl::CreatePasteDataMix()
{
    return AceType::MakeRefPtr<PasteDataMix>();
}

void ClipboardImpl::SetData(const std::string& data, CopyOptions copyOption, bool isDragData)
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

void ClipboardImpl::HasData(const std::function<void(bool hasData)>& callback)
{
    if (callback) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        if (pasteboard) {
            callback(pasteboard.hasStrings);
        }
    }
}

void ClipboardImpl::SetPixelMapData(const RefPtr<PixelMap>& pixmap, CopyOptions copyOption)
{
    if (!taskExecutor_ || !callbackSetClipboardPixmapData_) {
        LOGE("Failed to set the pixmap data to clipboard.");
        return;
    }
    taskExecutor_->PostTask([callbackSetClipboardPixmapData = callbackSetClipboardPixmapData_,
                                pixmap] { callbackSetClipboardPixmapData(pixmap); },
        TaskExecutor::TaskType::UI);
}

void ClipboardImpl::GetPixelMapData(const std::function<void(const RefPtr<PixelMap>&)>& callback, bool syncMode)
{
    if (!taskExecutor_ || !callbackGetClipboardPixmapData_ || !callback) {
        LOGE("Failed to get the pixmap data from clipboard.");
        return;
    }
    taskExecutor_->PostTask([callbackGetClipboardPixmapData = callbackGetClipboardPixmapData_,
                                callback] { callback(callbackGetClipboardPixmapData()); },
        TaskExecutor::TaskType::UI);
}

void ClipboardImpl::RegisterCallbackSetClipboardPixmapData(CallbackSetClipboardPixmapData callback)
{
    callbackSetClipboardPixmapData_ = callback;
}

void ClipboardImpl::RegisterCallbackGetClipboardPixmapData(CallbackGetClipboardPixmapData callback)
{
    callbackGetClipboardPixmapData_ = callback;
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
