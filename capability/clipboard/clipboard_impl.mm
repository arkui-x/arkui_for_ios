/*
 * Copyright (c) 2022-2025 Huawei Device Co., Ltd.
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
#include "multiType_record_impl.h"
#include "pasteData_impl.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

namespace OHOS::Ace::Platform {

void ClipboardImpl::AddPixelMapRecord(const RefPtr<PasteDataMix>& pasteData, const RefPtr<PixelMap>& pixmap) {}
void ClipboardImpl::AddImageRecord(const RefPtr<PasteDataMix>& pasteData, const std::string& uri) {}
void ClipboardImpl::AddTextRecord(const RefPtr<PasteDataMix>& pasteData, const std::string& selectedStr)
{
    CHECK_NULL_VOID(pasteData);
    auto pasteDataImpl = AceType::DynamicCast<PasteDataImpl>(pasteData);
    CHECK_NULL_VOID(pasteDataImpl);
    auto multiTypeRecord = AceType::MakeRefPtr<MultiTypeRecordImpl>();
    if (selectedStr.empty()) {
        LOGE("Text data is empty.");
        return;
    }
    multiTypeRecord->SetPlainText(selectedStr);
    pasteDataImpl->AddRecord(multiTypeRecord);
}

void ClipboardImpl::AddSpanStringRecord(const RefPtr<PasteDataMix>& pasteData, std::vector<uint8_t>& data)
{
    CHECK_NULL_VOID(pasteData);
    auto pasteDataImpl = AceType::DynamicCast<PasteDataImpl>(pasteData);
    CHECK_NULL_VOID(pasteDataImpl);
    auto multiTypeRecord = AceType::MakeRefPtr<MultiTypeRecordImpl>();
    if (data.empty()) {
        LOGE("SpanString data is empty.");
        return;
    }
    multiTypeRecord->SetSpanStringBuffer(data);
    pasteDataImpl->AddRecord(multiTypeRecord);
}

void ClipboardImpl::AddMultiTypeRecord(
    const RefPtr<PasteDataMix>& pasteData, const RefPtr<MultiTypeRecordMix>& multiTypeRecord)
{
    CHECK_NULL_VOID(pasteData);
    auto pasteDataImpl = AceType::DynamicCast<PasteDataImpl>(pasteData);
    CHECK_NULL_VOID(pasteDataImpl);

    auto multiTypeRecordImpl = AceType::DynamicCast<MultiTypeRecordImpl>(multiTypeRecord);
    CHECK_NULL_VOID(multiTypeRecordImpl);
    if (multiTypeRecordImpl->GetUri().empty()){
        pasteDataImpl->AddRecord(multiTypeRecordImpl);
    }
}

void ClipboardImpl::SetData(const RefPtr<PasteDataMix>& pasteData, CopyOptions copyOption)
{
    auto peData = AceType::DynamicCast<PasteDataImpl>(pasteData);
    CHECK_NULL_VOID(peData);
    taskExecutor_->PostTask(
        [peData]() {
            auto records = peData->GetRecords();
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            NSMutableArray<NSDictionary<NSString *, id> *> *items = [NSMutableArray array];

            for (auto it = records.rbegin(); it != records.rend(); ++it) {
                auto multiTypeRecord = AceType::DynamicCast<MultiTypeRecordImpl>(*it);
                if (!multiTypeRecord) {
                    continue;
                }
                
                NSMutableDictionary *item = [NSMutableDictionary dictionary];
                if (!multiTypeRecord->GetPlainText().empty()) {
                    NSString *plainText = [NSString stringWithUTF8String:multiTypeRecord->GetPlainText().c_str()];
                    [item setObject:plainText forKey:UTTypePlainText.identifier];
                }

                if (!multiTypeRecord->GetSpanStringBuffer().empty()) {
                    NSData *spanData = [NSData dataWithBytes:multiTypeRecord->GetSpanStringBuffer().data()
                                                    length:multiTypeRecord->GetSpanStringBuffer().size()];
                    [item setObject:spanData forKey:@"com.arkuix.custom-span-type"];
                }
                [items addObject:item];
            }
            [pasteboard setItems:items];
        },
        TaskExecutor::TaskType::PLATFORM, "ArkUIClipboardSetMixDataWithCopyOption", PriorityType::IMMEDIATE);
}

void ClipboardImpl::GetData(const std::function<void(const std::string&, bool isLastRecord)>& textCallback,
    const std::function<void(const RefPtr<PixelMap>&, bool isLastRecord)>& pixelMapCallback,
    const std::function<void(const std::string&, bool isLastRecord)>& urlCallback, bool syncMode)
{}

void ClipboardImpl::GetSpanStringData(
    const std::function<void(std::vector<std::vector<uint8_t>>&, const std::string&, bool&)>& callback, bool syncMode)
{
    if (callback) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        NSArray<NSDictionary<NSString *, id> *> *items = pasteboard.items;
        std::vector<std::vector<uint8_t>> arrays;
        std::string text = "";
        bool isMultiTypeRecord = false;

        for (NSDictionary<NSString *, id> *item in items) {
            NSString *plainText = item[UTTypePlainText.identifier];
            NSData *spanData = item[@"com.arkuix.custom-span-type"];

            if (plainText) {
                text += plainText.UTF8String;
            }

            if (spanData && plainText != nil) {
                const unsigned char *bytes = static_cast<const unsigned char *>(spanData.bytes);
                arrays.emplace_back(std::vector<uint8_t>(bytes, bytes + spanData.length));
            }
        }
        callback(arrays, text, isMultiTypeRecord);
    }
}

RefPtr<PasteDataMix> ClipboardImpl::CreatePasteDataMix()
{
    return AceType::MakeRefPtr<PasteDataImpl>();
}

void ClipboardImpl::SetData(const std::string& data, CopyOptions copyOption, bool isDragData)
{
    if (taskExecutor_) {
        taskExecutor_->PostTask([weak = AceType::WeakClaim(RawPtr(taskExecutor_)),data]{
            auto executor = weak.Upgrade();
            if(executor){
                executor->PostTask([data]{
                    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                    NSMutableDictionary *item = [NSMutableDictionary dictionary];
                    NSString *plainText = [NSString stringWithCString:data.c_str() encoding:NSUTF8StringEncoding];
                    [item setObject:plainText forKey:UTTypePlainText.identifier];
                    [pasteboard setItems:@[item]];
                },TaskExecutor::TaskType::BACKGROUND, "ArkUI-XClipboardImplSetDataBackground");
            }
        },TaskExecutor::TaskType::PLATFORM, "ArkUI-XClipboardImplSetDataPlatform");
    }
}

void ClipboardImpl::GetData(const std::function<void(const std::string&)>& callback, bool syncMode)
{
    if (callback) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        NSArray<NSDictionary<NSString *, id> *> *items = pasteboard.items;
        NSMutableString *allText = [NSMutableString string];
        for (NSDictionary<NSString *, id> *item in items) {
            NSString *plainText = item[UTTypePlainText.identifier];
            if (plainText) {
                [allText appendString:plainText];
            }
        }
        auto data = allText.UTF8String;
        callback(data);
    }
}

void ClipboardImpl::HasData(const std::function<void(bool hasData)>& callback)
{
    if (callback) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        if (pasteboard) {
            bool hasCustomData = [pasteboard dataForPasteboardType:@"com.arkuix.spanstring"] != nil;
            callback(pasteboard.hasStrings || hasCustomData);
        }
    }
}

void ClipboardImpl::HasDataType(const std::function<void(bool hasData)>& callback, const std::vector<std::string>& mimeTypes)
{
    HasData(callback);
}

void ClipboardImpl::SetPixelMapData(const RefPtr<PixelMap>& pixmap, CopyOptions copyOption)
{
    if (!taskExecutor_ || !callbackSetClipboardPixmapData_) {
        LOGE("Failed to set the pixmap data to clipboard.");
        return;
    }
    taskExecutor_->PostTask([callbackSetClipboardPixmapData = callbackSetClipboardPixmapData_,
                                pixmap] { callbackSetClipboardPixmapData(pixmap); },
        TaskExecutor::TaskType::UI, "ArkUI-XClipboardImplSetPixelMapData");
}

void ClipboardImpl::GetPixelMapData(const std::function<void(const RefPtr<PixelMap>&)>& callback, bool syncMode)
{
    if (!taskExecutor_ || !callbackGetClipboardPixmapData_ || !callback) {
        LOGE("Failed to get the pixmap data from clipboard.");
        return;
    }
    taskExecutor_->PostTask([callbackGetClipboardPixmapData = callbackGetClipboardPixmapData_,
                                callback] { callback(callbackGetClipboardPixmapData()); },
        TaskExecutor::TaskType::UI, "ArkUI-XClipboardImplGetPixelMapData");
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
                },TaskExecutor::TaskType::BACKGROUND, "ArkUI-XClipboardImplClearBackground");
            }
        },TaskExecutor::TaskType::PLATFORM, "ArkUI-XClipboardImplClearPlatform");
    }
}

} // namespace OHOS::Ace::Platform
