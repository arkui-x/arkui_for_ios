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

#include "base/utils/system_properties.h"

#include "base/log/log.h"

namespace OHOS::Ace {
namespace {

// Device type, same w/ java in AceView
constexpr int32_t ORIENTATION_PORTRAIT = 1;
constexpr int32_t ORIENTATION_LANDSCAPE = 2;
constexpr char UNDEFINED_PARAM[] = "undefined parameter";

} // namespace

bool SystemProperties::isRound_ = false;
bool SystemProperties::isDeviceAccess_ = false;
bool SystemProperties::developerModeOn_ = false;
int32_t SystemProperties::deviceWidth_ = 0;
int32_t SystemProperties::deviceHeight_ = 0;
int32_t SystemProperties::devicePhysicalWidth_ = 0;
int32_t SystemProperties::devicePhysicalHeight_ = 0;
double SystemProperties::resolution_ = 1.0;
DeviceType SystemProperties::deviceType_ { DeviceType::PHONE };
DeviceOrientation SystemProperties::orientation_ { DeviceOrientation::PORTRAIT };
std::string SystemProperties::brand_ = INVALID_PARAM;
std::string SystemProperties::manufacturer_ = INVALID_PARAM;
std::string SystemProperties::model_ = INVALID_PARAM;
std::string SystemProperties::product_ = INVALID_PARAM;
std::string SystemProperties::apiVersion_ = INVALID_PARAM;
std::string SystemProperties::releaseType_ = INVALID_PARAM;
std::string SystemProperties::paramDeviceType_ = INVALID_PARAM;
int32_t SystemProperties::mcc_ = MCC_UNDEFINED;
int32_t SystemProperties::mnc_ = MNC_UNDEFINED;
ColorMode SystemProperties::colorMode_ { ColorMode::LIGHT };
ScreenShape SystemProperties::screenShape_ { ScreenShape::NOT_ROUND };
LongScreenType SystemProperties::LongScreen_ { LongScreenType::NOT_LONG };
bool SystemProperties::unZipHap_ = true;
bool SystemProperties::rosenBackendEnabled_ = true;
bool SystemProperties::svgTraceEnable_ = false;
bool SystemProperties::downloadByNetworkEnabled_ = false;
bool SystemProperties::isHookModeEnabled_ = false;
bool SystemProperties::syncDebugTraceEnable_ = false;
bool SystemProperties::textTraceEnable_ = false;
bool SystemProperties::accessibilityEnabled_ = false;
bool SystemProperties::windowAnimationEnabled_ = false;
bool SystemProperties::debugEnabled_ = false;
bool SystemProperties::debugBoundaryEnabled_ = false;
bool SystemProperties::debugAutoUIEnabled_ = false;
bool SystemProperties::debugOffsetLogEnabled_ = false;
bool SystemProperties::extSurfaceEnabled_ = true;
uint32_t SystemProperties::dumpFrameCount_ = 0;
bool SystemProperties::layoutTraceEnable_ = false;
bool SystemProperties::buildTraceEnable_ = false;
bool SystemProperties::enableScrollableItemPool_ = false;
bool SystemProperties::navigationBlurEnabled_ = true;
bool SystemProperties::gridCacheEnabled_ = false;
bool SystemProperties::sideBarContainerBlurEnable_ = false;
bool SystemProperties::acePerformanceMonitorEnable_ = false;
bool SystemProperties::imageFileCacheConvertAstc_ = false;
int32_t SystemProperties::imageFileCacheConvertAstcThreshold_ = 2;
bool SystemProperties::traceInputEventEnable_ = false;
std::pair<float, float> SystemProperties::brightUpPercent_ = {};

bool SystemProperties::IsOpIncEnable()
{
    return false;
}

void SystemProperties::InitDeviceType(DeviceType type)
{
    // treat all other device type as phone
    if (type == DeviceType::TV)
        deviceType_ = type;
}

DeviceType SystemProperties::GetDeviceType()
{
    return deviceType_;
}
void SystemProperties::InitDeviceInfo(
    int32_t deviceWidth, int32_t deviceHeight, int32_t orientation, double resolution, bool isRound)
{
    // SetDeviceOrientation should be earlier than deviceWidth/Height's initialization
    SetDeviceOrientation(orientation);

    isRound_ = isRound;
    resolution_ = resolution;
    deviceWidth_ = deviceWidth;
    deviceHeight_ = deviceHeight;
    if (isRound_)
        screenShape_ = ScreenShape::ROUND;
    else
        screenShape_ = ScreenShape::NOT_ROUND;
}

void SystemProperties::SetDeviceOrientation(int32_t orientation)
{
    if (orientation == ORIENTATION_PORTRAIT && orientation_ != DeviceOrientation::PORTRAIT) {
        std::swap(deviceWidth_, deviceHeight_);
        orientation_ = DeviceOrientation::PORTRAIT;
    } else if (orientation == ORIENTATION_LANDSCAPE && orientation_ != DeviceOrientation::LANDSCAPE) {
        std::swap(deviceWidth_, deviceHeight_);
        orientation_ = DeviceOrientation::LANDSCAPE;
    } else {
        LOGW("SetDeviceOrientation, undefined orientation or current orientation is same as the orientation to set");
    }
}

void SystemProperties::InitDeviceTypeBySystemProperty()
{
    // empty.  Android doesn't use this function
}

float SystemProperties::GetFontWeightScale()
{
    // To Be Done
    return 1.0f;
}

void SystemProperties::InitMccMnc(int32_t mcc, int32_t mnc)
{
    mcc_ = mcc;
    mnc_ = mnc;
}

bool SystemProperties::IsScoringEnabled(const std::string& name)
{
    return false;
}

bool SystemProperties::GetDebugEnabled()
{
    return false;
}

bool SystemProperties::IsSyscapExist(const char* cap)
{
#ifdef OHOS_STANDARD_SYSTEM
    return HasSystemCapability(cap);
#else
    return false;
#endif
}

std::string SystemProperties::GetLanguage()
{
    return UNDEFINED_PARAM;
}

std::string SystemProperties::GetRegion()
{
    return UNDEFINED_PARAM;
}

std::string SystemProperties::GetPartialUpdatePkg()
{
    return "";
}

int32_t SystemProperties::GetSvgMode()
{
    // 1 for using svgdom of ArkUI, 0 for using SkiaSvgDom
#ifdef NG_BUILD
    return 0;
#else
    return 1;
#endif
}

bool SystemProperties::GetIsUseMemoryMonitor()
{
    return false;
}

bool SystemProperties::IsFormAnimationLimited()
{
    return false;
}

bool SystemProperties::GetImageFrameworkEnabled()
{
    return false;
}

bool SystemProperties::GetDebugPixelMapSaveEnabled()
{
    return false;
}

bool SystemProperties::GetResourceDecoupling()
{
    return false;
}

int32_t SystemProperties::GetJankFrameThreshold()
{
    return 0;
}

bool SystemProperties::GetTitleStyleEnabled()
{
    return false;
}

std::string SystemProperties::GetCustomTitleFilePath()
{
    return UNDEFINED_PARAM;
}

bool SystemProperties::Is24HourClock()
{
    return false;
}

bool SystemProperties::GetDisplaySyncSkipEnabled()
{
    return true;
}

bool SystemProperties::GetNavigationBlurEnabled()
{
    return navigationBlurEnabled_;
}

bool SystemProperties::GetGridCacheEnabled()
{
    return gridCacheEnabled_;
}

bool SystemProperties::GetSideBarContainerBlurEnable()
{
    return sideBarContainerBlurEnable_;
}

bool SystemProperties::GetGridIrregularLayoutEnabled()
{
    return false;
}

bool SystemProperties::WaterFlowUseSegmentedLayout()
{
    return false;
}

float SystemProperties::GetDefaultResolution()
{
    return 1.0f;
}

std::string SystemProperties::GetAtomicServiceBundleName()
{
    return UNDEFINED_PARAM;
}

} // namespace OHOS::Ace
