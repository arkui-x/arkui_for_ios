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

#include "adapter/ios/entrance/utils.h"

#include <cstdio>
#include <regex>
#include <sstream>
#include <string>

#include "foundation/appframework/window_manager/interfaces/innerkits/wm/wm_common.h"

namespace OHOS::Ace {

NG::SafeAreaInsets ConvertAvoidArea(const OHOS::Rosen::AvoidArea& avoidArea)
{
    return NG::SafeAreaInsets({ avoidArea.leftRect_.posX_, avoidArea.leftRect_.posX_ + avoidArea.leftRect_.width_ },
        { avoidArea.topRect_.posY_, avoidArea.topRect_.posY_ + avoidArea.topRect_.height_ },
        { avoidArea.rightRect_.posX_, avoidArea.rightRect_.posX_ + avoidArea.rightRect_.width_ },
        { avoidArea.bottomRect_.posY_, avoidArea.bottomRect_.posY_ + avoidArea.bottomRect_.height_ });
}
} // namespace OHOS::Ace