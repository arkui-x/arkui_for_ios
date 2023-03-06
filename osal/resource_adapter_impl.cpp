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

#include "adapter/ios/osal/resource_adapter_impl.h"

#include "adapter/ios/entrance/ace_application_info_impl.h"
#include "adapter/ios/osal/resource_convertor.h"
#include "adapter/ios/osal/resource_theme_style.h"
#include "core/components/theme/theme_attributes.h"

namespace OHOS::Ace {

namespace {
constexpr char DELIMITER[] = "/";
} // namespace

const char* PATTERN_MAP[] = {
    THEME_PATTERN_BUTTON,
    THEME_PATTERN_CHECKBOX,
    THEME_PATTERN_DATA_PANEL,
    THEME_PATTERN_RADIO,
    THEME_PATTERN_SWIPER,
    THEME_PATTERN_SWITCH,
    THEME_PATTERN_TOOLBAR,
    THEME_PATTERN_TOGGLE,
    THEME_PATTERN_TOAST,
    THEME_PATTERN_DIALOG,
    THEME_PATTERN_DRAG_BAR,
    THEME_PATTERN_SEMI_MODAL,
    // append
    THEME_PATTERN_BADGE,
    THEME_PATTERN_CALENDAR,
    THEME_PATTERN_CAMERA,
    THEME_PATTERN_CLOCK,
    THEME_PATTERN_COUNTER,
    THEME_PATTERN_DIVIDER,
    THEME_PATTERN_FOCUS_ANIMATION,
    THEME_PATTERN_GRID,
    THEME_PATTERN_IMAGE,
    THEME_PATTERN_LIST,
    THEME_PATTERN_LIST_ITEM,
    THEME_PATTERN_MARQUEE,
    THEME_PATTERN_NAVIGATION_BAR,
    THEME_PATTERN_PICKER,
    THEME_PATTERN_PIECE,
    THEME_PATTERN_POPUP,
    THEME_PATTERN_PROGRESS,
    THEME_PATTERN_QRCODE,
    THEME_PATTERN_RATING,
    THEME_PATTERN_REFRESH,
    THEME_PATTERN_SCROLL_BAR,
    THEME_PATTERN_SEARCH,
    THEME_PATTERN_SELECT,
    THEME_PATTERN_SLIDER,
    THEME_PATTERN_STEPPER,
    THEME_PATTERN_TAB,
    THEME_PATTERN_TEXT,
    THEME_PATTERN_TEXTFIELD,
    THEME_PATTERN_TEXT_OVERLAY,
    THEME_PATTERN_VIDEO
};

constexpr uint32_t THEME_ID_LIGHT = 125829967;
constexpr uint32_t THEME_ID_DARK = 125829966;

void CheckThemeId(int32_t& themeId)
{
    if (themeId >= 0) {
        return;
    }
    auto deviceType = SystemProperties::GetDeviceType();
    themeId = (deviceType == DeviceType::PHONE || deviceType == DeviceType::UNKNOWN || deviceType == DeviceType::CAR)
                  ? THEME_ID_LIGHT
                  : THEME_ID_DARK;
}

RefPtr<ResourceAdapter> ResourceAdapter::Create()
{
    return AceType::MakeRefPtr<ResourceAdapterImpl>();
}

void ResourceAdapterImpl::Init(const ResourceInfo& resourceInfo)
{
    std::string packagePath = resourceInfo.GetPackagePath();
    auto resConfig = ConvertConfigToGlobal(resourceInfo.GetResourceConfiguration());
    std::shared_ptr<Global::Resource::ResourceManager> newResMgr(Global::Resource::CreateResourceManager());
    std::string appResIndexPath = packagePath + DELIMITER + "appres" + DELIMITER + "resources.index";
    auto appResRet = newResMgr->AddResource(appResIndexPath.c_str());
    std::string sysResIndexPath = packagePath + DELIMITER + "systemres" + DELIMITER + "resources.index";
    auto sysResRet = newResMgr->AddResource(sysResIndexPath.c_str());
    auto configRet = newResMgr->UpdateResConfig(*resConfig);
    LOGI("AddAppRes result=%{public}d, AddSysRes result=%{public}d,  UpdateResConfig result=%{public}d, "
         "ori=%{public}d, dpi=%{public}d, device=%{public}d",
        appResRet, sysResRet, configRet, resConfig->GetDirection(), resConfig->GetScreenDensity(),
        resConfig->GetDeviceType());
    resourceManager_ = newResMgr;
    packagePathStr_ = packagePath;
    Platform::AceApplicationInfoImpl::GetInstance().SetResourceManager(newResMgr);
}

void ResourceAdapterImpl::UpdateConfig(const ResourceConfiguration& config)
{
    LOGI("UpdateConfig ori=%{public}d, dpi=%{public}d, device=%{public}d, colorMode=%{public}d,",
        config.GetOrientation(), config.GetDensity(), config.GetDeviceType(), config.GetColorMode());
    auto resConfig = ConvertConfigToGlobal(config);
    LOGI("UpdateConfig ori=%{public}d, dpi=%{public}d, device=%{public}d", resConfig->GetDirection(),
        resConfig->GetScreenDensity(), resConfig->GetDeviceType());
    LOGI("UpdateConfig ori=%{public}d, dpi=%{public}d, device=%{public}d, "
         "colorMode=%{public}d, inputDevice=%{public}d",
        resConfig->GetDirection(), resConfig->GetScreenDensity(), resConfig->GetDeviceType(), resConfig->GetColorMode(),
        resConfig->GetInputDevice());
    resourceManager_->UpdateResConfig(*resConfig);
}

RefPtr<ThemeStyle> ResourceAdapterImpl::GetTheme(int32_t themeId)
{
    CheckThemeId(themeId);
    auto theme = AceType::MakeRefPtr<ResourceThemeStyle>(AceType::Claim(this));
    auto ret = resourceManager_->GetThemeById(themeId, theme->rawAttrs_);

    LOGI("theme themeId=%{public}d, ret=%{public}d, attr size=%{public}zu",
        themeId, ret, theme->rawAttrs_.size());

    std::string OHFlag = "ohos_"; // fit with resource/base/theme.json and pattern.json
    for (uint64_t i = 0; i < sizeof(PATTERN_MAP) / sizeof(PATTERN_MAP[0]); i++) {
        ResourceThemeStyle::RawAttrMap attrMap;
        std::string patternTag = PATTERN_MAP[i];
        std::string patternName =  OHFlag + PATTERN_MAP[i];
        ret = resourceManager_->GetPatternByName(patternName.c_str(), attrMap);
        LOGI("theme pattern[%{public}s, %{public}s], attr size=%{public}zu",
            patternTag.c_str(), patternName.c_str(), attrMap.size());
        if (attrMap.empty()) {
            continue;
        }
        theme->patternAttrs_[patternTag] = attrMap;
    }
    LOGI("theme themeId=%{public}d, ret=%{public}d, attr size=%{public}zu, pattern size=%{public}zu",
        themeId, ret, theme->rawAttrs_.size(), theme->patternAttrs_.size());
    if (theme->patternAttrs_.empty() && theme->rawAttrs_.empty()) {
        LOGW("theme resource get failed, use default theme config.");
        return nullptr;
    }

    theme->ParseContent();
    theme->patternAttrs_.clear();

    auto& attrMap = theme->rawAttrs_;
    auto iter = attrMap.find(THEME_ATTR_BG_COLOR);
    if (iter != attrMap.end()) {
        auto& attribute = iter->second;
        if (!attribute.empty()) {
            Color bgColor = Color::FromString(attribute);
            theme->SetAttr(THEME_ATTR_BG_COLOR, { .type = ThemeConstantsType::COLOR, .value = bgColor });
        }
    }

    return theme;
};

Color ResourceAdapterImpl::GetColor(uint32_t resId)
{
    uint32_t result = 0;
    if (resourceManager_) {
        auto state = resourceManager_->GetColorById(resId, result);
        if (state != Global::Resource::SUCCESS) {
            LOGE("GetColor error, id=%{public}u", resId);
        }
    }
    return Color(result);
}

Dimension ResourceAdapterImpl::GetDimension(uint32_t resId)
{
    float dimensionFloat = 0.0f;
    if (resourceManager_) {
        auto state = resourceManager_->GetFloatById(resId, dimensionFloat);
        if (state != Global::Resource::SUCCESS) {
            LOGE("GetDimension error, id=%{public}u", resId);
        }
    }
    return Dimension(static_cast<double>(dimensionFloat));
}

std::string ResourceAdapterImpl::GetString(uint32_t resId)
{
    std::string strResult;
    if (resourceManager_) {
        auto state = resourceManager_->GetStringById(resId, strResult);
        if (state != Global::Resource::SUCCESS) {
            LOGE("GetString error, id=%{public}u", resId);
        }
    }
    return strResult;
}

std::string ResourceAdapterImpl::GetPluralString(uint32_t resId, int quantity)
{
    std::string strResult;
    if (resourceManager_) {
        auto state = resourceManager_->GetPluralStringById(resId, quantity, strResult);
        if (state != Global::Resource::SUCCESS) {
            LOGE("GetPluralString error, id=%{public}u", resId);
        }
    }
    return strResult;
}

std::vector<std::string> ResourceAdapterImpl::GetStringArray(uint32_t resId) const
{
    std::vector<std::string> strResults;
    if (resourceManager_) {
        auto state = resourceManager_->GetStringArrayById(resId, strResults);
        if (state != Global::Resource::SUCCESS) {
            LOGE("GetStringArray error, id=%{public}u", resId);
        }
    }
    return strResults;
}

double ResourceAdapterImpl::GetDouble(uint32_t resId)
{
    float result = 0.0f;
    if (resourceManager_) {
        auto state = resourceManager_->GetFloatById(resId, result);
        if (state != Global::Resource::SUCCESS) {
            LOGE("GetDouble error, id=%{public}u", resId);
        }
    }
    return static_cast<double>(result);
}

int32_t ResourceAdapterImpl::GetInt(uint32_t resId)
{
    int32_t result = 0;
    if (resourceManager_) {
        auto state = resourceManager_->GetIntegerById(resId, result);
        if (state != Global::Resource::SUCCESS) {
            LOGE("GetInt error, id=%{public}u", resId);
        }
    }
    return result;
}

std::vector<uint32_t> ResourceAdapterImpl::GetIntArray(uint32_t resId) const
{
    std::vector<int> intVectorResult;
    if (resourceManager_) {
        auto state = resourceManager_->GetIntArrayById(resId, intVectorResult);
        if (state != Global::Resource::SUCCESS) {
            LOGE("GetIntArray error, id=%{public}u", resId);
        }
    }
    std::vector<uint32_t> result;
    std::transform(
        intVectorResult.begin(), intVectorResult.end(), result.begin(), [](int x) { return static_cast<uint32_t>(x); });
    return result;
}

bool ResourceAdapterImpl::GetBoolean(uint32_t resId) const
{
    bool result = false;
    if (resourceManager_) {
        auto state = resourceManager_->GetBooleanById(resId, result);
        if (state != Global::Resource::SUCCESS) {
            LOGE("GetBoolean error, id=%{public}u", resId);
        }
    }
    return result;
}

std::string ResourceAdapterImpl::GetMediaPath(uint32_t resId)
{
    std::string mediaPath;
    if (resourceManager_) {
        auto state = resourceManager_->GetMediaById(resId, mediaPath);
        if (state != Global::Resource::SUCCESS) {
            LOGE("GetMediaPath error, id=%{public}u", resId);
            return "";
        }   
        return "file://" + mediaPath;
    }
    return "";
}

std::string ResourceAdapterImpl::GetRawfile(const std::string& fileName)
{
    return "file://" + packagePathStr_ + "/resources/rawfile/" + fileName;
}

void ResourceAdapterImpl::UpdateResourceManager(const std::string& bundleName, const std::string& moduleName)
{
    return;
}

} // namespace OHOS::Ace