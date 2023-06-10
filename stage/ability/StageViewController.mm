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

#import "adapter/ios/entrance/AcePlatformPlugin.h"
#import "InstanceIdGenerator.h"
#import "StageViewController.h"
#import "StageConfigurationManager.h"
#import "StageAssetManager.h"
#import "WindowView.h"
#import "StageApplication.h"

#include "app_main.h"
#include "window_view_adapter.h"

using AppMain = OHOS::AbilityRuntime::Platform::AppMain;
using WindowViwAdapter = OHOS::AbilityRuntime::Platform::WindowViewAdapter;
int32_t CURRENT_STAGE_INSTANCE_Id = 0;
@interface StageViewController () <UITraitEnvironment, WindowViewDelegate> {
    int32_t _instanceId;
    std::string _cInstanceName;
    WindowView *_windowView;
    BOOL _hasLaunch;
}

@property (nonatomic, strong, readwrite) NSString *instanceName;
@property (nonatomic, strong) NSString *bundleName;
@property (nonatomic, strong) NSString *moduleName;
@property (nonatomic, strong) NSString *abilityName;

@property (nonatomic, strong) AcePlatformPlugin *platformPlugin;
@end

@implementation StageViewController

CGFloat _brightness = 0.0;

#pragma mark - life cycle
- (instancetype)initWithInstanceName:(NSString *_Nonnull)instanceName {
    self = [super init];
    if (self) {
        _instanceId = InstanceIdGenerator.getAndIncrement;
        self.instanceName = [NSString stringWithFormat:@"%@:%d", instanceName, _instanceId];
        NSLog(@"StageVC->%@ init, instanceName is : %@", self, self.instanceName);
        _cInstanceName = [self getCPPString:self.instanceName];
        NSArray * nameArray = [self.instanceName componentsSeparatedByString:@":"];
        if (nameArray.count >= 3) {
            self.bundleName = nameArray[0];
            self.moduleName = nameArray[1];
            self.abilityName = nameArray[2];
        }
        
    }
    return self;
}

- (void)initWindowView {
    _windowView = [[WindowView alloc] init];
    _windowView.notifyDelegate = self;
    _windowView.frame = self.view.bounds;
    _windowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    WindowViwAdapter::GetInstance()->AddWindowView(_cInstanceName, (__bridge void*)_windowView);
    _brightness = [UIScreen mainScreen].brightness;
    [self.view addSubview: _windowView];
}

- (void) viewDidLoad {
    [super viewDidLoad];
    NSLog(@"StageVC->%@ viewDidLoad call. self.params : %@", self, self.params);
    [self initWindowView];
    [self initPlatformPlugin];
    [_windowView createSurfaceNode];

    std::string paramsString = [self getCPPString:self.params.length ? self.params : @""];
    AppMain::GetInstance()->DispatchOnCreate(_cInstanceName, paramsString);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"StageVC->%@ viewDidAppear call.", self);
    AppMain::GetInstance()->DispatchOnForeground(_cInstanceName);
    if (self.platformPlugin) {
        [self.platformPlugin notifyLifecycleChanged:false];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [UIScreen mainScreen].brightness = _brightness;
    NSLog(@"StageVC->%@ viewDidDisappear call.", self);
    AppMain::GetInstance()->DispatchOnBackground(_cInstanceName);
    if (self.platformPlugin) {
        [self.platformPlugin notifyLifecycleChanged:true];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    NSLog(@"StageVC->%@ didReceiveMemoryWarning call.", self);
    if (!self.view) {
    // Ability::OnWindowStageDestroy
    }
}

- (void)dealloc {
    NSLog(@"StageVC->%@ dealloc", self);
    [_windowView notifySurfaceDestroyed];
    [_windowView notifyWindowDestroyed];
    [_windowView release];
    [_platformPlugin releaseObject];
    [_platformPlugin release];
    AppMain::GetInstance()->DispatchOnDestroy(_cInstanceName);
    [super dealloc];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [[StageConfigurationManager configurationManager] colorModeUpdate:self.traitCollection.userInterfaceStyle];
        }
    }
}

- (int32_t)getInstanceId {
    return _instanceId;
}

#pragma mark - private method
- (void)initPlatformPlugin {
     self.platformPlugin = [[AcePlatformPlugin alloc]
        initPlatformPlugin:self instanceId:_instanceId moduleName:self.moduleName];
}

- (std::string)getCPPString:(NSString *)string {
    return [string UTF8String];
}

- (BOOL)isTopController {
    StageViewController *controller = [StageApplication getApplicationTopViewController];
    NSString *topInstanceName = controller.instanceName;
    if ([self.instanceName isEqualToString:topInstanceName]) {
        return true;
    }
    return false;
}

#pragma mark - WindowViewDelegate 
- (void)notifyApplicationWillEnterForeground {
    if (self.platformPlugin && [self isTopController]) {
        [self.platformPlugin notifyLifecycleChanged:false];
    }
}

- (void)notifyApplicationDidEnterBackground {
    if (self.platformPlugin && [self isTopController]) {
        [self.platformPlugin notifyLifecycleChanged:true];
    }
}

- (BOOL)prefersStatusBarHidden {
    return self.statusBarHidden;
}
@end