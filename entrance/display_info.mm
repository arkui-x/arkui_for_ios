/*
 * Copyright (c) 2021-2022 Huawei Device Co., Ltd.
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

#include "display_info.h"

#include <new>
#include <parcel.h>
#import <UIKit/UIKit.h>
#import <sys/utsname.h>


namespace OHOS::Rosen {
std::map<UIDeviceOrientation, DisplayOrientation> gUIDeviceOrientationToOrientationMap = {
    {UIDeviceOrientationUnknown, DisplayOrientation::PORTRAIT},
    {UIDeviceOrientationPortrait, DisplayOrientation::PORTRAIT},
    {UIDeviceOrientationPortraitUpsideDown, DisplayOrientation::PORTRAIT_INVERTED},
    {UIDeviceOrientationLandscapeLeft, DisplayOrientation::LANDSCAPE},
    {UIDeviceOrientationLandscapeRight, DisplayOrientation::LANDSCAPE_INVERTED},
    {UIDeviceOrientationFaceUp, DisplayOrientation::PORTRAIT},
    {UIDeviceOrientationFaceDown, DisplayOrientation::PORTRAIT}
};

DisplayInfo::DisplayInfo()
{
    id_ = 0;
    displayOrientation_ = gUIDeviceOrientationToOrientationMap[[UIDevice currentDevice].orientation];

    UIScreen *screen = [UIScreen mainScreen];
    CGFloat scale = screen.scale;
    width_ = static_cast<int32_t>([UIScreen mainScreen].bounds.size.width * scale);
    height_ = static_cast<int32_t>([UIScreen mainScreen].bounds.size.height * scale);
    densityPixels_ = scale;
    scaledDensity_ = scale;
    densityDpi_ = GetDevicePpi();
}

DisplayInfo::~DisplayInfo()
{
}

DisplayId DisplayInfo::GetDisplayId() const
{
    return id_;
}
int32_t DisplayInfo::GetWidth() const
{
    return width_;
}
int32_t DisplayInfo::GetHeight() const
{
    return height_;
}
Orientation DisplayInfo::GetOrientation() const
{
    return orientation_;
}
DisplayOrientation DisplayInfo::GetDisplayOrientation() const
{
    return displayOrientation_;
}

float DisplayInfo::GetDensityPixels() const
{
    return densityPixels_;
}

float DisplayInfo::GetScaledDensity() const
{
    return scaledDensity_;
}

int32_t DisplayInfo::GetDensityDpi() const
{
    return densityDpi_;
}

void DisplayInfo::SetDisplayId(DisplayId displayId)
{
    id_ = displayId;
}
void DisplayInfo::SetWidth(int32_t width)
{
    width_ = width;
}
void DisplayInfo::SetHeight(int32_t height)
{
    height_ = height;
}
void DisplayInfo::SetOrientation(Orientation orientation)
{
    orientation_ = orientation;
}
void DisplayInfo::SetDisplayOrientation(DisplayOrientation displayOrientation)
{
    displayOrientation_ = displayOrientation;
}

void DisplayInfo::SetDensityPixels(float densityPixels)
{
    densityPixels_ = densityPixels;
}

void DisplayInfo::SetScaledDensity(float scaledDensity)
{
    scaledDensity_ = scaledDensity;
}

void DisplayInfo::SetDensityDpi(int32_t dpi)
{
    densityDpi_ = dpi;
}

int32_t DisplayInfo::GetDevicePpi() const
{
    struct utsname systemInfo;
    uname(&systemInfo);
    std::string deviceString = systemInfo.machine;
    int devicePpi = 0;
    std::map<std::string,int32_t> g_dpi = {
        //iPhone
        {"iPhone16,2",460},//460 iPhone 15 Pro Max ppi
        {"iPhone16,1",460},//460 iPhone 15 Pro ppi
        {"iPhone15,5",460},//460 iPhone 15 Plus ppi
        {"iPhone15,4",460},//460 iPhone 15 ppi
        {"iPhone15,3",460},//460 iPhone 14 Pro Max ppi
        {"iPhone15,2",460},//460 iPhone 14 Pro ppi
        {"iPhone14,8",458},//458 iPhone 14 Plus ppi
        {"iPhone14,7",460},//460 iPhone 14 ppi
        {"iPhone14,6",326},//326 iPhone SE 3rd Gen ppi
        {"iPhone14,3",458},//458 iPhone 13 Pro Max ppi
        {"iPhone14,2",460},//460 iPhone 13 Pro ppi
        {"iPhone14,5",460},//460 iPhone 13 ppi
        {"iPhone14,4",476},//476 iPhone 13 mini ppi
        {"iPhone13,4",458},//458 iPhone 12 Pro Max ppi
        {"iPhone13,3",460},//460 iPhone 12 Pro ppi
        {"iPhone13,2",460},//460 iPhone 12 ppi
        {"iPhone13,1",476},//476 iPhone 12 mini ppi
        {"iPhone12,8",326},//326 iPhone SE 2nd Gen ppi
        {"iPhone12,5",458},//458 iPhone 11 Pro Max ppi
        {"iPhone12,3",458},//458 iPhone 11 Pro ppi
        {"iPhone12,1",326},//326 iPhone 11 ppi
        {"iPhone11,4",458},//458 iPhone XS Max ppi
        {"iPhone11,6",458},//458 iPhone XS Max ppi
        {"iPhone11,2",458},//458 iPhone XS ppi
        {"iPhone11,8",326},//326 iPhone XR ppi
        {"iPhone10.3",458},//458 iPhone X ppi
        {"iPhone10,6",458},//458 iPhone X ppi
        {"iPhone10,2",401},//401 iPhone 8 Plus ppi
        {"iPhone10,5",401},//401 iPhone 8 Plus ppi
        {"iPhone10,1",326},//326 iPhone 8 ppi
        {"iPhone10,4",326},//326 iPhone 8 ppi
        {"iPhone9,2",401},//401 iPhone 7 Plus ppi
        {"iPhone9,4",401},//401 iPhone 7 Plus ppi
        {"iPhone9,1",326},//326 iPhone 7 ppi
        {"iPhone9,3",326},//326 iPhone 7 ppi
        {"iPhone8,4",326},//326 iPhone SE ppi
        {"iPhone8,2",401},//401 iPhone 6s Plus ppi
        {"iPhone8,1",326},//326 iPhone 6s ppi
        {"iPhone7,1",401},//401 iPhone 6 Plus ppi
        {"iPhone7,2",326},//326 iPhone 6 ppi
        {"iPhone6,1",326},//326 iPhone 5s ppi
        {"iPhone6,2",326},//326 iPhone 5s ppi
        {"iPhone5,3",326},//326 iPhone 5c ppi
        {"iPhone5,4",326},//326 iPhone 5c ppi
        {"iPhone5,1",326},//326 iPhone 5 ppi
        {"iPhone5,2",326},//326 iPhone 5 ppi
        {"iPhone4,1",326},//326 iPhone 4s ppi
        {"iPhone3,1",326},//326 iPhone 4 ppi
        {"iPhone3,3",326},//326 iPhone 4 ppi
        {"iPhone2,1",163},//163 iPhone 3GS ppi
        {"iPad1,1",132},//132 iPad ppi
        {"iPad2,1",132},//132 iPad 2 ppi
        {"iPad2,2",132},//132 iPad 2 ppi
        {"iPad2,3",132},//132 iPad 2 ppi
        {"iPad2,4",132},//132 iPad 2 ppi
        {"iPad3,1",264},//264 iPad 3 ppi
        {"iPad3,2",264},//264 iPad 3 ppi
        {"iPad3,3",264},//264 iPad 3 ppi
        {"iPad3,4",264},//264 iPad 4 ppi
        {"iPad3,5",264},//264 iPad 4 ppi
        {"iPad3,6",264},//264 iPad 4 ppi
        {"iPad6,11",264},//264 iPad 5 ppi
        {"iPad6,12",264},//264 iPad 5 ppi
        {"iPad7,5",264},//264 iPad 6 ppi
        {"iPad7,6",264},//264 iPad 6 ppi
        {"iPad7,11",264},//264 iPad 7 ppi
        {"iPad7,12",264},//264 iPad 7 ppi
        {"iPad11,6",264},//264 iPad 8 ppi
        {"iPad11,7",264},//264 iPad 8 ppi
        {"iPad12,1",264},//264 iPad 9 ppi
        {"iPad12,2",264},//264 iPad 9 ppi
        {"iPad13,18",264},//264 iPad 10 ppi
        {"iPad13,19",264},//264 iPad 10 ppi
        {"iPad2,5",163},//163 iPad Mini ppi
        {"iPad2,6",326},//264 iPad Mini ppi
        {"iPad2,7",326},//264 iPad Mini ppi
        {"iPad4,4",326},//264 iPad Mini 2 ppi
        {"iPad4,5",326},//264 iPad Mini 2 ppi
        {"iPad4,6",326},//264 iPad Mini 2 ppi
        {"iPad4,7",326},//264 iPad Mini 3 ppi
        {"iPad4,8",326},//264 iPad Mini 3 ppi
        {"iPad4,9",326},//264 iPad Mini 3 ppi
        {"iPad5,1",326},//264 iPad Mini 4 ppi
        {"iPad5,2",326},//264 iPad Mini 4 ppi
        {"iPad11,1",326},//264 iPad Mini 5 ppi
        {"iPad11,2",326},//264 iPad Mini 5 ppi
        {"iPad14,1",326},//264 iPad Mini 6 ppi
        {"iPad14,2",326},//264 iPad Mini 6 ppi
        {"iPad4,1",264},//264 iPad Air ppi
        {"iPad4,2",264},//264 iPad Air ppi
        {"iPad4,3",264},//264 iPad Air ppi
        {"iPad5,3",264},//264 iPad Air 2 ppi
        {"iPad5,4",264},//264 iPad Air 2 ppi
        {"iPad11,3",264},//264 iPad Air 3 ppi
        {"iPad11,4",264},//264 iPad Air 3 ppi
        {"iPad13,1",264},//264 iPad Air 4 ppi
        {"iPad13,2",264},//264 iPad Air 4 ppi
        {"iPad13,16",264},//264 iPad Air 5 ppi
        {"iPad13,17",264},//264 iPad Air 5 ppi
        {"iPad6,3",264},//264 iPad Pro 9.7 ppi
        {"iPad6,4",264},//264 iPad Pro 9.7 ppi
        {"iPad6,7",264},//264 iPad Pro 12.9 ppi
        {"iPad6,8",264},//264 iPad Pro 12.9 ppi
        {"iPad7,1",264},//264 iPad Pro 12.9 inch 2nd gen ppi
        {"iPad7,2",264},//264 iPad Pro 12.9 inch 2nd gen ppi
        {"iPad7,3",264},//264 iPad Pro 10.5 inch ppi
        {"iPad7,4",264},//264 iPad Pro 10.5 inch ppi
        {"iPad8,1",264},//264 iPad Pro 11-inch ppi
        {"iPad8,2",264},//264 iPad Pro 11-inch ppi
        {"iPad8,3",264},//264 iPad Pro 11-inch ppi
        {"iPad8,4",264},//264 iPad Pro 11-inch ppi
        {"iPad8,5",264},//264 iPad Pro 12.9-inch 3rd gen ppi
        {"iPad8,6",264},//264 iPad Pro 12.9-inch 3rd gen ppi
        {"iPad8,7",264},//264 iPad Pro 12.9-inch 3rd gen ppi
        {"iPad8,8",264},//264 iPad Pro 12.9-inch 3rd gen ppi
        {"iPad8,9",264},//264 iPad Pro 11-inch 2nd gen ppi
        {"iPad8,10",264},//264 iPad Pro 11-inch 2nd gen ppi
        {"iPad8,11",264},//264 iPad Pro 12.9-inch 4th gen ppi
        {"iPad8,12",264},//264 iPad Pro 12.9-inch 4th gen ppi
        {"iPad13,4",264},//264 iPad Pro 11-inch 3nd gen ppi
        {"iPad13,5",264},//264 iPad Pro 11-inch 3nd gen ppi
        {"iPad13,6",264},//264 iPad Pro 11-inch 3nd gen ppi
        {"iPad13,7",264},//264 iPad Pro 11-inch 3nd gen ppi
        {"iPad13,8",264},//264 iPad Pro 12.9-inch 5th gen ppi
        {"iPad14,3",264},//264 iPad Pro 11-inch 4th gen ppi
        {"iPad14,4",264},//264 iPad Pro 11-inch 4th gen ppi
        {"iPad14,5",264},//264 iPad Pro 12.9-inch 6th gen ppi
        {"iPad14,6",264}//264 iPad Pro 12.9-inch 6th gen ppi
    };
    auto iter = g_dpi.find(deviceString);
    if (iter != g_dpi.end()) {
        devicePpi = iter->second;
    }
    return devicePpi;
}

} // namespace OHOS::Rosen