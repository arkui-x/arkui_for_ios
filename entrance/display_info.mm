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


namespace OHOS::Rosen {
std::map<UIDeviceOrientation, DisplayOrientation> gUIDeviceOrientationToOrientationMap = {
    {UIDeviceOrientationUnknown, DisplayOrientation::UNKNOWN},
    {UIDeviceOrientationPortrait, DisplayOrientation::PORTRAIT},
    {UIDeviceOrientationPortraitUpsideDown, DisplayOrientation::PORTRAIT_INVERTED},
    {UIDeviceOrientationLandscapeLeft, DisplayOrientation::LANDSCAPE},
    {UIDeviceOrientationLandscapeRight, DisplayOrientation::LANDSCAPE_INVERTED},
    {UIDeviceOrientationFaceUp, DisplayOrientation::UNKNOWN},
    {UIDeviceOrientationFaceDown, DisplayOrientation::UNKNOWN}
};

DisplayInfo::DisplayInfo()
{
    id_ = 0;
    displayOrientation_ = gUIDeviceOrientationToOrientationMap[[UIDevice currentDevice].orientation];

    UIScreen *screen = [UIScreen mainScreen];
    CGFloat scale = screen.scale;
    width_ = static_cast<int32_t>([UIScreen mainScreen].bounds.size.width * scale);
    height_ = static_cast<int32_t>([UIScreen mainScreen].bounds.size.height * scale);
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
} // namespace OHOS::Rosen