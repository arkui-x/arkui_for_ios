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

#import "StageContainerView.h"
#import <set>

@implementation StageContainerView
/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame: frame]) {
        [self setupNotificationCenterObservers];
    }
    return self;
}
- (void)showWindow:(WindowView *)window {
    NSLog(@"showWindow");
   UIView* aboveView = nullptr;
    for (UIView* view in self.subviews.reverseObjectEnumerator) {
        if (window.zOrder < ((WindowView *)view).zOrder) {
            aboveView = view;
        } else {
            break;
        }
    }
    if (!aboveView) {
        [self addSubview:window];
    } else {
        [self insertSubview:window belowSubview:aboveView];
    }

    if (window.focusable) {
        [self setActiveWindow:window];
    }
}

- (BOOL)requestFocus:(WindowView*)window {
    if (!window.focusable) {
        return NO;
    }
    BOOL res = NO;
    for (UIView *subview in [self.subviews reverseObjectEnumerator]) {
       if (subview == window) {
            res = YES;
           break;
       }
    }
    if (res) {
        [self bringSubviewToFront:window];
        self.activeWindow = window;
        return YES;
    }
    return NO;
}
- (void)setMainWindow:(WindowView *)mainWindow {
    _mainWindow = mainWindow;
    self.activeWindow = mainWindow;
    [self addSubview:mainWindow];
}
- (void)hiddenWindow:(WindowView *)window {
    [window removeFromSuperview];
    self.activeWindow = self.mainWindow;
}

- (void)setupNotificationCenterObservers {
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(applicationBecameActive:)
                   name:UIApplicationDidBecomeActiveNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(applicationWillResignActive:)
                   name:UIApplicationWillResignActiveNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(applicationDidEnterBackground:)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
    
    [center addObserver:self
               selector:@selector(applicationWillEnterForeground:)
                   name:UIApplicationWillEnterForegroundNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(handleWillTerminate:)
                   name:UIApplicationWillTerminateNotification
                 object:nil];
}
#pragma mark - Application lifecycle notifications

- (void)applicationBecameActive:(NSNotification *)notification {
    [self notifyActiveChanged:YES];
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    [self notifyActiveChanged:NO];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
   [self notifyBackground];
    if ([self.notifyDelegate respondsToSelector:@selector(notifyApplicationDidEnterBackground)]) {
        [self.notifyDelegate notifyApplicationDidEnterBackground];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    [self notifyForeground];
    if ([self.notifyDelegate respondsToSelector:@selector(notifyApplicationWillEnterForeground)]) {
        [self.notifyDelegate notifyApplicationWillEnterForeground];
    }
}

- (void)handleWillTerminate:(NSNotification*)notification {
    if ([self.notifyDelegate respondsToSelector:@selector(notifyApplicationWillTerminateNotification)]) {
        [self.notifyDelegate notifyApplicationWillTerminateNotification];
    }

    for (UIView *subview in [self.subviews reverseObjectEnumerator]) {
       if ([subview isKindOfClass:[WindowView class]]) {
           [(WindowView*)subview notifyHandleWillTerminate];
       }
    }
}

- (void)notifyActiveChanged:(BOOL)isActive {
    self.activeWindow.isFocused = isActive;
   for (UIView *subview in [self.subviews reverseObjectEnumerator]) {
       if ([subview isKindOfClass:[WindowView class]]) {
           [(WindowView*)subview notifyActiveChanged:isActive];
       }
   }
}

- (void)notifyForeground {
    for (UIView *subview in [self.subviews reverseObjectEnumerator]) {
       if ([subview isKindOfClass:[WindowView class]]) {
           [(WindowView*)subview notifyForeground];
           [(WindowView*)subview notifyApplicationForeground:YES];
       }
    }
}
- (void)notifyBackground {
    for (UIView *subview in [self.subviews reverseObjectEnumerator]) {
       if ([subview isKindOfClass:[WindowView class]]) {
           [(WindowView*)subview notifyBackground];
           [(WindowView*)subview notifyApplicationForeground:NO];
       }
    }
}

- (void)setActiveWindow:(WindowView *)activeWindow {
    if (_activeWindow != activeWindow && activeWindow.focusable) {
        _activeWindow.isFocused = NO;
        _activeWindow = activeWindow;
        _activeWindow.isFocused = YES;
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    //系统默认会忽略isUserInteractionEnabled设置为NO、隐藏、alpha小于等于0.01的视图
    if (!self.isUserInteractionEnabled || self.isHidden || self.alpha <= 0.01) {
        return nil;
    }
    if ([self pointInside:point withEvent:event]) {
        for (UIView *subview in [self.subviews reverseObjectEnumerator]) {
            CGPoint convertedPoint = [self convertPoint:point toView:subview];
            UIView *hitTestView = [subview hitTest:convertedPoint withEvent:event];
            if (hitTestView) {
                if ([hitTestView isKindOfClass:[WindowView class]] && self.activeWindow != hitTestView) {
                    if (self.activeWindow != hitTestView && hitTestView != self.mainWindow) {
                        [self bringSubviewToFront:hitTestView];
                    }
                    self.activeWindow = (WindowView *)hitTestView;
                }
                return hitTestView;
            }
        }

        return self;
    }
    return nil;
}

- (void)dealloc {
    NSLog(@"StageContainerView->%@ dealloc",self);
    self.notifyDelegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
