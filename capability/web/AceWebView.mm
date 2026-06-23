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
#import "AceWebView.h"

@interface AceWebView ()

@property (nonatomic, copy, nullable) AceWebDarkModeObserver darkModeObserver;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 170000
@property (nonatomic, strong, nullable) id<UITraitChangeRegistration> darkModeRegistration;
#endif

@end

@implementation AceWebView

- (void)observeSystemDarkModeWithBlock:(AceWebDarkModeObserver)observer
{
    self.darkModeObserver = observer;
    [self notifyDarkMode];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 170000
    if (@available(iOS 17.0, *)) {
        [self releaseTraitChangeRegistration];
        self.darkModeRegistration = [self registerForTraitChanges:@[ UITraitUserInterfaceStyle.class ]
                                                       withTarget:self
                                                           action:@selector(notifyDarkMode)];
    }
#endif
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (previousTraitCollection == nil ||
            self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
            [self notifyDarkMode];
        }
    }
}

- (BOOL)currentDarkModeEnabled
{
    if (@available(iOS 13.0, *)) {
        return self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

- (void)notifyDarkMode
{
    BOOL isDarkModeEnabled = [self currentDarkModeEnabled];
    if (self.darkModeObserver != nil) {
        self.darkModeObserver(isDarkModeEnabled);
    }
}

- (void)releaseDarkModeObserver
{
    self.darkModeObserver = nil;
    [self releaseTraitChangeRegistration];
}

- (void)releaseTraitChangeRegistration
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 170000
    if (@available(iOS 17.0, *)) {
        if (self.darkModeRegistration != nil) {
            [self unregisterForTraitChanges:self.darkModeRegistration];
        }
        self.darkModeRegistration = nil;
    }
#endif
}

@end