/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
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

#ifndef ACE_WEBVIEW_IOS_H
#define ACE_WEBVIEW_IOS_H

#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^AceWebDarkModeObserver)(BOOL isDarkModeEnabled);

@interface AceWebView : WKWebView

- (void)observeSystemDarkModeWithBlock:(AceWebDarkModeObserver)observer;
- (void)releaseDarkModeObserver;

@end

NS_ASSUME_NONNULL_END

#endif // ACE_WEBVIEW_IOS_H
