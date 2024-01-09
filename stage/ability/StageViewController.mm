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

#import "AcePlatformPlugin.h"
#import "ArkUIXPluginRegistry.h"
#import "BridgePluginManager.h"
#import "BridgePluginManager+internal.h"
#import "InstanceIdGenerator.h"
#import "PluginContext.h"
#import "StageApplication.h"
#import "StageAssetManager.h"
#import "StageConfigurationManager.h"
#import "StageViewController.h"
#import "WindowView.h"

#include "app_main.h"
#include "window_view_adapter.h"

using AppMain = OHOS::AbilityRuntime::Platform::AppMain;
using WindowViwAdapter = OHOS::AbilityRuntime::Platform::WindowViewAdapter;
int32_t CURRENT_STAGE_INSTANCE_Id = 0;
@interface StageViewController () <UITraitEnvironment, WindowViewDelegate> {
    int32_t _instanceId;
    std::string _cInstanceName;
    WindowView *_windowView;
    AcePlatformPlugin *_platformPlugin;
    BridgePluginManager *_bridgePluginManager;
    BOOL _needOnForeground;
    NSMutableArray *_pluginList;
    ArkUIXPluginRegistry *_arkUIXPluginRegistry;
    PluginContext *_pluginContext;
}

@property (nonatomic, strong, readwrite) NSString *instanceName;
@property (nonatomic, copy) NSString *bundleName;
@property (nonatomic, copy) NSString *moduleName;
@property (nonatomic, copy) NSString *abilityName;
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
        _pluginList = [[NSMutableArray alloc] init];
        [self initBridge];
    }
    return self;
}

- (void)initColorMode {
    if (@available(iOS 13.0, *)) {
        UITraitCollection* trait = [UITraitCollection currentTraitCollection];
        [[StageConfigurationManager configurationManager] colorModeUpdate:trait.userInterfaceStyle];
    } else {
        [[StageConfigurationManager configurationManager] colorModeUpdate:UIUserInterfaceStyleLight];
    }
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

- (void)initBridge {
    _bridgePluginManager = [BridgePluginManager innerBridgePluginManager:_instanceId];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    NSLog(@"StageVC->%@ viewDidLoad call.", self);
    [self initColorMode];
    [self initWindowView];
    [self initPlatformPlugin];
    [self initArkUIXPlugin];
    [_windowView createSurfaceNode];

    std::string paramsString = [self getCPPString:self.params.length ? self.params : @""];
    AppMain::GetInstance()->DispatchOnCreate(_cInstanceName, paramsString);
    AppMain::GetInstance()->DispatchOnForeground(_cInstanceName);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [_windowView updateBrightness];
    [_windowView notifyForeground];
    NSLog(@"StageVC->%@ viewDidAppear call.", self);
    if (_needOnForeground) {
        AppMain::GetInstance()->DispatchOnForeground(_cInstanceName);
    }
    _needOnForeground = true;
    if (_platformPlugin) {
        [_platformPlugin notifyLifecycleChanged:false];
    }
    [_windowView notifyFocusChanged:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [UIScreen mainScreen].brightness = _brightness;
    [_windowView notifyBackground];
    NSLog(@"StageVC->%@ viewDidDisappear call.", self);
    AppMain::GetInstance()->DispatchOnBackground(_cInstanceName);
    if (_platformPlugin) {
        [_platformPlugin notifyLifecycleChanged:true];
    }
    [_windowView notifyFocusChanged:NO];
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
    _windowView = nil;
    [_platformPlugin platformRelease];
    _platformPlugin = nil;
    [BridgePluginManager innerUnbridgePluginManager:_instanceId];
    _bridgePluginManager = nil;
    [self deallocArkUIXPlugin];
    AppMain::GetInstance()->DispatchOnDestroy(_cInstanceName);
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

- (void)addPlugin:(NSString *)pluginName {
    if (pluginName == nil) {
        NSLog(@"StageVC->%@ plugin name is nil!", self);
    } else {
        NSLog(@"StageVC->%@ add plugin: %@", self, pluginName);
        [_pluginList addObject:pluginName];
    }
}

- (void)initArkUIXPlugin {
    _pluginContext = [[PluginContext alloc] initPluginContext:[self getBridgeManager]];
    _arkUIXPluginRegistry = [[ArkUIXPluginRegistry alloc] initArkUIXPluginRegistry:_pluginContext];
    [_arkUIXPluginRegistry registryPlugins:_pluginList];
}

- (void)deallocArkUIXPlugin {
    [_pluginList removeAllObjects];
    [_arkUIXPluginRegistry unRegistryAllPlugins];
    _arkUIXPluginRegistry = nil;
    _pluginContext = nil;
}

- (id)getBridgeManager {
    return _bridgePluginManager;
}

#pragma mark - private method
- (void)initPlatformPlugin {
     _platformPlugin = [[AcePlatformPlugin alloc]
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

- (BOOL)processBackPress {
    return [_windowView processBackPressed];
}

#pragma mark - WindowViewDelegate 
- (void)notifyApplicationWillEnterForeground {
    if ([self isTopController]) {
        [_windowView notifyForeground];
        if (_platformPlugin) {
            [_platformPlugin notifyLifecycleChanged:false];
        }
    }
}

- (void)notifyApplicationDidEnterBackground {
    if ([self isTopController]) {
        [_windowView notifyBackground];
        if (_platformPlugin) {
            [_platformPlugin notifyLifecycleChanged:true];
        }
    }
}

- (void)notifyApplicationWillTerminateNotification {
   [_bridgePluginManager platformWillTerminate];
}

- (void)notifyApplicationBecameActive {
    if ([self isTopController]) {
        [_windowView notifyFocusChanged:YES];
    }
}

- (void)notifyApplicationWillResignActive {
    if ([self isTopController]) {
        [_windowView notifyFocusChanged:NO];
    }
}

- (BOOL)prefersStatusBarHidden {
    return self.statusBarHidden;
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if (_windowView) {
        [_windowView pressesBegan:presses withEvent:event];
    }
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if (_windowView) {
        [_windowView pressesEnded:presses withEvent:event];
    }
}

- (void)pressesChanged:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if (_windowView) {
        [_windowView pressesChanged:presses withEvent:event];
    }
}

- (void)pressesCancelled:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if (_windowView) {
        [_windowView pressesCancelled:presses withEvent:event];
    }
}
@end