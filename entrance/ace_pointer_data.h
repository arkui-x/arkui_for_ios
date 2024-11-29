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

#ifndef FOUNDATION_ADAPTER_IOS_ENTRANCE_ACE_POINTER_DATA_H
#define FOUNDATION_ADAPTER_IOS_ENTRANCE_ACE_POINTER_DATA_H

#include <cstring>
#include <vector>
namespace OHOS::Ace::Platform {

struct alignas(8) AcePointerData {

enum class PointerAction : int64_t {
    kCanceled,
    kAdded,
    kRemoved,
    kHovered,
    kDowned,
    kMoved,
    kUped,
    kPanZoomStarted,
    kPanZoomUpdated,
    kPanZoomEnded,
};

enum class ToolType : int64_t {
    Touch,
    Mouse,
    Stylus,
    InvertedStylus,
    Trackpad,
};
    int64_t pointer_id { -1 };
    int64_t device_id { -1 };
    double pressure;
    double display_x;
    double display_y;
    double window_x;
    double window_y;
    double radius_major;
    double radius_min;
    double radius_max;
    double tilt;
    double orientation;
    int64_t time_stamp;
    int64_t finger_count { 0 };
    PointerAction pointer_action;
    ToolType tool_type;
    bool actionPoint { true };

    void Clear();
};// namespace OHOS::Ace::Platform
}
#endif // FOUNDATION_ADAPTER_IOS_ENTRANCE_ACE_POINTER_DATA_H