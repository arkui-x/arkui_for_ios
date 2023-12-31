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

#include "dm_common.h"
#include "wm_common.h"
#include "wm_single_instance.h"
#include "nocopyable.h"

namespace OHOS::Rosen {
class DisplayInfo : public virtual RefBase {
public:
    DisplayInfo();
    ~DisplayInfo();
    DISALLOW_COPY_AND_MOVE(DisplayInfo);
    DisplayId GetDisplayId() const;
    int32_t GetWidth() const;
    int32_t GetHeight() const;
    Orientation GetOrientation() const;
    DisplayOrientation GetDisplayOrientation() const;

    void SetDisplayId(DisplayId displayId);
    void SetWidth(int32_t width);
    void SetHeight(int32_t height);
    void SetOrientation(Orientation orientation);
    void SetDisplayOrientation(DisplayOrientation displayOrientation);

private:
    DisplayId id_ { DISPLAY_ID_INVALID };
    int32_t width_ { 0 };
    int32_t height_ { 0 };
    Orientation orientation_ { Orientation::UNSPECIFIED };
    DisplayOrientation displayOrientation_ { DisplayOrientation::UNKNOWN };
};
} // namespace OHOS::Rosen
#endif // FOUNDATION_DMSERVER_DISPLAY_INFO_H