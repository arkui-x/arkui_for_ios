/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_WINDOW_VIEW_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_WINDOW_VIEW_H

#include <UIKit/UIKit.h>
#include <memory>

namespace OHOS::Rosen {
class Window;
}

@interface WindowView : UIView

- (void)setWindowDelegate:(std::shared_ptr<OHOS::Rosen::Window>)window;
- (void)createSurfaceNode;
- (void)notifySurfaceChangedWithWidth:(int32_t)width height:(int32_t)height;
- (void)notifySurfaceDestroyed;

@end

#endif  // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_WINDOW_VIEW_H
