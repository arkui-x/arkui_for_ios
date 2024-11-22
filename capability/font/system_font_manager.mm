/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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
#include "adapter/ios/capability/font/system_font_manager.h"

#import <Foundation/foundation.h>
#import <UIKit/UIKit.h>

namespace OHOS::Ace::Platform {

std::unique_ptr<FontNameFamilyMap> SystemFontManager::fontNameFamilyMap_ = nullptr;

void SystemFontManager::GetSystemFontList(std::vector<std::string>& fontList)
{
    GetSystemFontNameFamilyMap();
    if (!fontNameFamilyMap_) {
        return;
    }
    for (auto iter = fontNameFamilyMap_->begin(); iter != fontNameFamilyMap_->end(); iter++) {
        fontList.push_back(iter->first);
    }
}

bool SystemFontManager::GetSystemFont(const std::string& fontName, FontInfo& fontInfo)
{
    static std::map<std::string, FontInfo> fontInfoCache;
    auto findIter = fontInfoCache.find(fontName);
    if (fontInfoCache.end() != findIter) {
        fontInfo.fullName = findIter->first;
        fontInfo.family = findIter->second.family;
        fontInfo.postScriptName = findIter->second.postScriptName;
        fontInfo.italic = findIter->second.italic;
        fontInfo.monoSpace = findIter->second.monoSpace;
        fontInfo.symbolic = findIter->second.symbolic;
        return true;
    }
    return GetSystemFontDetailByName(fontName, fontInfo);
}

bool SystemFontManager::GetSystemFontDetailByName(const std::string& fontName, FontInfo& fontInfo)
{
    GetSystemFontNameFamilyMap();
    if (!fontNameFamilyMap_) {
        return false;
    }
    auto findIter = fontNameFamilyMap_->find(fontName);
    if (fontNameFamilyMap_->end() == findIter) {
        return false;
    }
    fontInfo.fullName = findIter->first;
    fontInfo.family = findIter->second;
    NSString* name = [NSString stringWithFormat:@"%s", fontName.c_str()];
    CGFloat fontSize = [UIFont systemFontSize];
    UIFont* font = [UIFont fontWithName:name size:fontSize];
    if (!font) {
        return false;
    }
    fontInfo.postScriptName = std::string([font.fontDescriptor.postscriptName UTF8String]);
    if (font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitItalic) {
        fontInfo.italic = true;
    }
    if (font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitMonoSpace) {
        fontInfo.monoSpace = true;
    }
    uint32_t mask = font.fontDescriptor.symbolicTraits & UIFontDescriptorClassMask;
    if (UIFontDescriptorClassSymbolic == mask) {
        fontInfo.symbolic = true;
    }
    return true;
}

void SystemFontManager::GetSystemFontNameFamilyMap()
{
    if (!fontNameFamilyMap_) {
        fontNameFamilyMap_ = std::make_unique<FontNameFamilyMap>();
    }
    if (!fontNameFamilyMap_->empty()) {
        return;
    }
    NSArray* familyNames = [UIFont familyNames];
    for (id familyName in familyNames) {
        std::string family = std::string([familyName UTF8String]);
        NSArray* fontNames = [UIFont fontNamesForFamilyName:familyName];
        for (id fontName in fontNames) {
            std::string name = std::string([fontName UTF8String]);
            fontNameFamilyMap_->emplace(name, family);
        }
    }
}
} // namespace OHOS::Ace::Platform