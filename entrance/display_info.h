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

#ifndef FOUNDATION_DMSERVER_DISPLAY_INFO_H
#define FOUNDATION_DMSERVER_DISPLAY_INFO_H

#include <cstdint>
#include <parcel.h>
#include <map>
#include <string>

#include "base/utils/macros.h"
#include "dm_common.h"
#include "wm_common.h"
#include "wm_single_instance.h"
#include "nocopyable.h"

namespace OHOS::Rosen {
class ACE_EXPORT DisplayInfo : public virtual RefBase {
public:
    DisplayInfo();
    ~DisplayInfo();
    DISALLOW_COPY_AND_MOVE(DisplayInfo);
    DisplayId GetDisplayId() const;
    int32_t GetWidth() const;
    int32_t GetHeight() const;
    Orientation GetOrientation() const;
    DisplayOrientation GetDisplayOrientation() const;
    float GetDensityPixels() const;
    float GetScaledDensity() const;
    int32_t GetDensityDpi() const;

    void SetDisplayId(DisplayId displayId);
    void SetWidth(int32_t width);
    void SetHeight(int32_t height);
    void SetOrientation(Orientation orientation);
    void SetDisplayOrientation(DisplayOrientation displayOrientation);
    void SetDensityPixels(float densityPixels);
    void SetScaledDensity(float scaledDensity);
    void SetDensityDpi(int32_t dpi);
    int32_t GetXDpi();
    int32_t GetYDpi();

private:
    DisplayId id_ { DISPLAY_ID_INVALID };
    int32_t width_ { 0 };
    int32_t height_ { 0 };
    Orientation orientation_ { Orientation::UNSPECIFIED };
    DisplayOrientation displayOrientation_ { DisplayOrientation::UNKNOWN };
    float densityPixels_ { 0.0f };
    float scaledDensity_ { 0.0f };
    int32_t densityDpi_ { 0.0f };
    int32_t GetDevicePpi() const;
};
} // namespace OHOS::Rosen
#endif // FOUNDATION_DMSERVER_DISPLAY_INFO_H