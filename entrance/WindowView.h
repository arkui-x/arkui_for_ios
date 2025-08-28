/*
 * Copyright (c) 2023-2025 Huawei Device Co., Ltd.
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
@property (nonatomic, assign) UIInterfaceOrientationMask OrientationMask;
@property (nonatomic, assign) UIViewController*viewController;
@property (nonatomic, assign) BOOL focusable;
@property (nonatomic, assign) BOOL isFocused;
@property (nonatomic, assign) BOOL fullScreen;
@property (nonatomic, assign) NSInteger zOrder;
@property (nonatomic, assign) float brightness;

- (UIViewController*)getViewController;

- (void)setWindowDelegate:(std::shared_ptr<OHOS::Rosen::Window>)window;
- (void)createSurfaceNode;
- (BOOL)requestFocus;
- (void)setTouchHotAreas:(CGRect[])rects size:(NSInteger)size;
- (BOOL)showOnView:(UIView*)rootView;
- (BOOL)hide;
- (void)notifySurfaceChangedWithWidth:(int32_t)width height:(int32_t)height density:(float)density;
- (void)notifySurfaceDestroyed;
- (void)notifyForeground;
- (void)notifyBackground;
- (void)notifyHandleWillTerminate;
- (void)notifyActiveChanged:(BOOL)isActive;
- (void)notifyWindowDestroyed;
- (void)notifySafeAreaChanged;
- (void)notifyTraitCollectionDidChange:(BOOL)isSplitScreen;
- (std::shared_ptr<OHOS::Rosen::Window>)getWindow;
- (void)notifyApplicationForeground:(BOOL)isForeground;

- (void)updateBrightness:(BOOL)isShow;
- (BOOL)processBackPressed;
- (void)keyboardWillChangeFrame:(NSNotification*)notification;
- (void)keyboardWillBeHidden:(NSNotification*)notification;
- (void)startBaseDisplayLink;
@end

#endif  // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_WINDOW_VIEW_H
