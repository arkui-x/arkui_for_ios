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

#include "adapter/ios/osal/platformview/platform_view_plugin.h"

#include "base/log/log.h"
#include "adapter/ios/osal/platformview/platform_view_impl.h"

namespace OHOS::Ace::Platform {

RefPtr<NG::PlatformViewInterface> PlatformViewPlugin::Attach(const std::string& id)
{
    auto platformView = AceType::MakeRefPtr<NG::PlatformViewImpl>(id);
    return platformView;
}

} // namespace OHOS::Ace::Platform
