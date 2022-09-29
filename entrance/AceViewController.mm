/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
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

#import "adapter/ios/entrance/AceViewController.h"

#import "AceCameraResoucePlugin.h"
#import "AceResourceRegisterOC.h"
#import "AceTextureResourcePlugin.h"
#import "AceVideoResourcePlugin.h"

#include "flutter/fml/memory/weak_ptr.h"
#include "flutter/fml/platform/darwin/scoped_nsobject.h"
#include "flutter/lib/ui/window/viewport_metrics.h"
#include "flutter/shell/platform/darwin/ios/framework/Headers/FlutterViewController.h"

#include "adapter/ios/entrance/ace_application_info_impl.h"
#include "adapter/ios/capability/editing/iOSTxtInputManager.h"
#include "adapter/ios/entrance/ace_container.h"
#include "adapter/ios/entrance/ace_resource_register.h"
#include "adapter/ios/entrance/flutter_ace_view.h"
#include "adapter/ios/entrance/capability_registry.h"
#include "adapter/preview/entrance/ace_run_args.h"
#include "core/common/ace_engine.h"
#include "core/common/container.h"
#include "core/event/mouse_event.h"
#include "core/event/touch_event.h"

const int32_t THEME_ID_DEFAULT = 117440515;
int32_t CURRENT_INSTANCE_Id = 0;
#define ASSER_PATH @"js"
#define K_THEME_ID_LIGHT 125829967
#define K_THEME_ID_DARK 125829966
@interface AceViewController ()<IAceOnCallEvent>

@property (retain, nonatomic, readonly) FlutterViewController* flutterVc;
@property (nonatomic, retain) AceResourceRegisterOC *registerOC;
/// plugin
@property (nonatomic, retain) AceVideoResourcePlugin *videoResourcePlugin;
@property (nonatomic, retain) AceCameraResoucePlugin *cameraResourcePlugin;
@property (nonatomic, retain) AceTextureResourcePlugin *textureResourcePlugin;

@end

@implementation AceViewController {
    OHOS::Ace::Platform::FlutterAceView *_aceView;
    int32_t _aceInstanceId;
}

- (instancetype)initWithVersion:(ACE_VERSION)version
                bundleDirectory:(nonnull NSString *)bundleDirectory {
    if (self = [super init]) {
        _version = version;
        _bundleDirectory = [bundleDirectory copy];
    }
    return self;
}

- (instancetype)initWithVersion:(ACE_VERSION)version
                   instanceName:(nonnull NSString *)instanceName {
    NSString *bundleDirectory =
    [[NSBundle mainBundle] pathForResource:instanceName
                                    ofType:nil
                               inDirectory:ASSER_PATH];
    NSAssert(bundleDirectory != nil,
             ([NSString stringWithFormat:@"Can not find the bundle named :%@",
               instanceName]));
    return [self initWithVersion:version bundleDirectory:bundleDirectory];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupNotificationCenterObservers];
    
    [self addSwipeRecognizer];
    [self initAce];
    
    UIScreen *screen = [UIScreen mainScreen];
    CGFloat scale = screen.scale;
    
    [self onLocaleUpdated:nil];
    OHOS::Ace::Platform::AceContainer::SetView(_aceView, scale, screen.bounds.size.width * scale,
                                               screen.bounds.size.height * scale);
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[iOSTxtInputManager shareintance] hideTextInput];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    [_registerOC releaseObject];
}

- (void)initAce {
    static std::once_flag onceFlag;
    std::call_once(onceFlag, []() {
        LOGI("Initialize for current process.");
        OHOS::Ace::Container::UpdateCurrent(OHOS::Ace::INSTANCE_ID_PLATFORM);
        OHOS::Ace::Platform::CapabilityRegistry::Register();
    });

    _aceInstanceId = [AceViewController genterateInstanceId];
    _aceView = new OHOS::Ace::Platform::FlutterAceView(_aceInstanceId);

    FlutterViewController *controller = [[FlutterViewController alloc] init];
    [self addChildViewController:controller];
    [controller didMoveToParentViewController:self];
    _flutterVc = controller;
    controller.view.frame = self.view.bounds;
    [self.view addSubview:controller.view];
    
    // alloc resource register
    _registerOC = [[AceResourceRegisterOC alloc] initWithParent:self];
    auto aceResRegister = OHOS::Ace::Referenced::MakeRefPtr<OHOS::Ace::Platform::AceResourceRegister>(_registerOC);
    _aceView->SetPlatformResRegister(aceResRegister);

    // register with plugins
    _videoResourcePlugin = [[AceVideoResourcePlugin alloc] initWithBundleDirectory:self.bundleDirectory];
    _cameraResourcePlugin = [[AceCameraResoucePlugin alloc] init];
    _textureResourcePlugin = [[AceTextureResourcePlugin alloc] initWithTextures:_flutterVc.engine];
    
    [_registerOC registerPlugin: _videoResourcePlugin];
    [_registerOC registerPlugin:_cameraResourcePlugin];
    [_registerOC registerPlugin:_textureResourcePlugin];

    OHOS::Ace::Platform::FlutterAceView::IdleCallback idleNoticeCallback = [view = _aceView](int64_t deadline) { view->ProcessIdleEvent(deadline); };
    [controller setIdleCallBack:idleNoticeCallback];
    
    constexpr char ASSET_PATH_SHARE[] = "share";
    OHOS::Ace::FrontendType frontendType = OHOS::Ace::FrontendType::DECLARATIVE_JS;
    if (_version == ACE_VERSION_JS) {
        frontendType = OHOS::Ace::FrontendType::JS;
    } else if (_version == ACE_VERSION_ETS) {
        frontendType = OHOS::Ace::FrontendType::DECLARATIVE_JS;
    }
    OHOS::Ace::Platform::AceContainer::CreateContainer(_aceInstanceId, frontendType);
    [self initTheme];

    std::string argurl = _bundleDirectory.UTF8String;
    std::string customurl = OHOS::Ace::Platform::AceContainer::GetCustomAssetPath(argurl);
    OHOS::Ace::Platform::AceContainer::AddAssetPath(_aceInstanceId, "", {argurl, customurl.append(ASSET_PATH_SHARE)});
}

- (void)initTheme{
    auto container = OHOS::Ace::AceType::DynamicCast<OHOS::Ace::Platform::AceContainer>(OHOS::Ace::AceEngine::Get().GetContainer(_aceInstanceId));
    if (container) {
        BOOL isDark = [self isDarkMode];

        NSInteger themeId = isDark ? K_THEME_ID_DARK : K_THEME_ID_LIGHT;
        std::string assetPathCStr = std::string([self.bundleDirectory stringByAppendingPathComponent:@"resources"].UTF8String);
        container->UpdateColorMode(isDark ? OHOS::Ace::ColorMode::DARK : OHOS::Ace::ColorMode::LIGHT);
        container->initResourceManager(assetPathCStr, themeId);
    }
}

- (BOOL)isDarkMode{
    __block BOOL isDark = NO;
    if (@available(iOS 13.0, *)) {
        UIColor *color = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            if (@available(iOS 12.0, *)) {
                if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark){
                    isDark = YES;
                    return UIColor.blackColor;
                }else {
                    return UIColor.whiteColor;
                }
            }
            return UIColor.whiteColor;
        }];
        self.view.backgroundColor = color;
    }
    return isDark;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self runAcePage];
}

- (void)dealloc {

    [_registerOC release];

    [_videoResourcePlugin release];
    [_cameraResourcePlugin release];
    [_textureResourcePlugin release];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    OHOS::Ace::Platform::AceContainer::RemoveContainer(_aceInstanceId);
    
    delete _aceView;
    
    [_flutterVc removeFromParentViewController];
    [_flutterVc release];
    
    [super dealloc];
}

-(void)runAcePage{
    OHOS::Ace::Platform::AceContainer::RunPage(_aceInstanceId, 1, "", "");
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self dispatchTouches:touches pointerDataChangeOverride:nullptr];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self dispatchTouches:touches pointerDataChangeOverride:nullptr];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self dispatchTouches:touches pointerDataChangeOverride:nullptr];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self dispatchTouches:touches pointerDataChangeOverride:nullptr];
}

#pragma mark - Touch event handling

static flutter::PointerData::Change PointerDataChangeFromUITouchPhase(UITouchPhase phase) {
    switch (phase) {
        case UITouchPhaseBegan:
            return flutter::PointerData::Change::kDown;
        case UITouchPhaseMoved:
        case UITouchPhaseStationary:
            // There is no EVENT_TYPE_POINTER_STATIONARY. So we just pass a move type
            // with the same coordinates
            return flutter::PointerData::Change::kMove;
        case UITouchPhaseEnded:
            return flutter::PointerData::Change::kUp;
        case UITouchPhaseCancelled:
            return flutter::PointerData::Change::kCancel;
    }
    
    return flutter::PointerData::Change::kCancel;
}

static flutter::PointerData::DeviceKind DeviceKindFromTouchType(UITouch *touch) {
    if (@available(iOS 9, *)) {
        switch (touch.type) {
            case UITouchTypeDirect:
            case UITouchTypeIndirect:
                return flutter::PointerData::DeviceKind::kTouch;
            case UITouchTypeStylus:
                return flutter::PointerData::DeviceKind::kStylus;
        }
    } else {
        return flutter::PointerData::DeviceKind::kTouch;
    }
    
    return flutter::PointerData::DeviceKind::kTouch;
}

- (void)dispatchTouches:(NSSet *)touches pointerDataChangeOverride:(flutter::PointerData::Change *)overridden_change {
    const CGFloat scale = [UIScreen mainScreen].scale;
    std::unique_ptr<flutter::PointerDataPacket> packet = std::make_unique<flutter::PointerDataPacket>(touches.count);
    
    size_t pointer_index = 0;
    
    for (UITouch *touch in touches) {
        CGPoint windowCoordinates = [touch locationInView:self.view];
        
        flutter::PointerData pointer_data;
        pointer_data.Clear();
        
        constexpr int kMicrosecondsPerSecond = 1000 * 1000;
        pointer_data.time_stamp = touch.timestamp * kMicrosecondsPerSecond;
        
        pointer_data.change = overridden_change != nullptr
        ? *overridden_change
        : PointerDataChangeFromUITouchPhase(touch.phase);
        
        pointer_data.kind = DeviceKindFromTouchType(touch);
        
        pointer_data.device = reinterpret_cast<int64_t>(touch);
        
        pointer_data.physical_x = windowCoordinates.x * scale;
        pointer_data.physical_y = windowCoordinates.y * scale;
        
        NSNumber *deviceKey = [NSNumber numberWithLongLong:pointer_data.device];
        // Track touches that began and not yet stopped so we can flush them
        // if the view controller goes away.
        // switch (pointer_data.change) {
        //   case flutter::PointerData::Change::kDown:
        //     [_ongoingTouches addObject:deviceKey];
        //     break;
        //   case flutter::PointerData::Change::kCancel:
        //   case flutter::PointerData::Change::kUp:
        //     [_ongoingTouches removeObject:deviceKey];
        //     break;
        //   case flutter::PointerData::Change::kHover:
        //   case flutter::PointerData::Change::kMove:
        //     // We're only tracking starts and stops.
        //     break;
        //   case flutter::PointerData::Change::kAdd:
        //   case flutter::PointerData::Change::kRemove:
        //     // We don't use kAdd/kRemove.
        //     break;
        // }
        
        // pressure_min is always 0.0
        if (@available(iOS 9, *)) {
            // These properties were introduced in iOS 9.0.
            pointer_data.pressure = touch.force;
            pointer_data.pressure_max = touch.maximumPossibleForce;
        } else {
            pointer_data.pressure = 1.0;
            pointer_data.pressure_max = 1.0;
        }
        
        // These properties were introduced in iOS 8.0
        pointer_data.radius_major = touch.majorRadius;
        pointer_data.radius_min = touch.majorRadius - touch.majorRadiusTolerance;
        pointer_data.radius_max = touch.majorRadius + touch.majorRadiusTolerance;
        
        // These properties were introduced in iOS 9.1
        if (@available(iOS 9.1, *)) {
            // iOS Documentation: altitudeAngle
            // A value of 0 radians indicates that the stylus is parallel to the surface. The value of
            // this property is Pi/2 when the stylus is perpendicular to the surface.
            //
            // PointerData Documentation: tilt
            // The angle of the stylus, in radians in the range:
            //    0 <= tilt <= pi/2
            // giving the angle of the axis of the stylus, relative to the axis perpendicular to the input
            // surface (thus 0.0 indicates the stylus is orthogonal to the plane of the input surface,
            // while pi/2 indicates that the stylus is flat on that surface).
            //
            // Discussion:
            // The ranges are the same. Origins are swapped.
            pointer_data.tilt = M_PI_2 - touch.altitudeAngle;

            // iOS Documentation: azimuthAngleInView:
            // With the tip of the stylus touching the screen, the value of this property is 0 radians
            // when the cap end of the stylus (that is, the end opposite of the tip) points along the
            // positive x axis of the device's screen. The azimuth angle increases as the user swings the
            // cap end of the stylus in a clockwise direction around the tip.
            //
            // PointerData Documentation: orientation
            // The angle of the stylus, in radians in the range:
            //    -pi < orientation <= pi
            // giving the angle of the axis of the stylus projected onto the input surface, relative to
            // the positive y-axis of that surface (thus 0.0 indicates the stylus, if projected onto that
            // surface, would go from the contact point vertically up in the positive y-axis direction, pi
            // would indicate that the stylus would go down in the negative y-axis direction; pi/4 would
            // indicate that the stylus goes up and to the right, -pi/2 would indicate that the stylus
            // goes to the left, etc).
            //
            // Discussion:
            // Sweep direction is the same. Phase of M_PI_2.
            pointer_data.orientation = [touch azimuthAngleInView:nil] - M_PI_2;
        }
        
        packet->SetPointerData(pointer_index++, pointer_data);
    }
    
    auto container = OHOS::Ace::Platform::AceContainer::GetContainerInstance(_aceInstanceId);
    if (!container) {
        LOGE("container is null");
        return;
    }
    
    auto aceView = static_cast<OHOS::Ace::Platform::FlutterAceView*>(container->GetAceView());
    if (!aceView) {
        LOGE("aceView is null");
        return;
    }
    
    aceView->HandleTouchEvent(packet->data());
}

- (void)addSwipeRecognizer{
     UISwipeGestureRecognizer *recognizer = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(handleSwipeFrom:)];
     [recognizer setDirection:(UISwipeGestureRecognizerDirectionRight)];
     [self.view addGestureRecognizer:recognizer];
}

- (void)handleSwipeFrom:(UISwipeGestureRecognizer *)recognizer{
   if(recognizer.direction == UISwipeGestureRecognizerDirectionDown) {
       NSLog(@"swipe down");
   }
   if(recognizer.direction == UISwipeGestureRecognizerDirectionUp) {
       NSLog(@"swipe up");
   }
   if(recognizer.direction == UISwipeGestureRecognizerDirectionLeft) {
       NSLog(@"swipe left");
   }
   if(recognizer.direction == UISwipeGestureRecognizerDirectionRight) {
       CGPoint pos = [recognizer locationInView:self.view];
       if(pos.x < 20){
          dispatch_async(dispatch_get_main_queue(), ^{
              [[iOSTxtInputManager shareintance] hideTextInput];
          });
          OHOS::Ace::Platform::AceContainer::OnBackPressed(_aceInstanceId);
       }
   }
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
               selector:@selector(onLocaleUpdated:)
                   name:NSCurrentLocaleDidChangeNotification
                 object:nil];

    [center addObserver:self
               selector:@selector(keyboardWillChangeFrame:)
                   name:UIKeyboardWillChangeFrameNotification
                 object:nil];

    [center addObserver:self
               selector:@selector(keyboardWillBeHidden:)
                   name:UIKeyboardWillHideNotification
                 object:nil];           
}

#pragma mark - Application lifecycle notifications

- (void)applicationBecameActive:(NSNotification *)notification {
    OHOS::Ace::Platform::AceContainer::OnActive(_aceInstanceId);
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    OHOS::Ace::Platform::AceContainer::OnInactive(_aceInstanceId);
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    OHOS::Ace::Platform::AceContainer::OnHide(_aceInstanceId);
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    OHOS::Ace::Platform::AceContainer::OnShow(_aceInstanceId);
}

- (void)keyboardWillChangeFrame:(NSNotification*)notification{
    NSDictionary* info = [notification userInfo];
    CGFloat keyboardY = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue].origin.y;

    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenHeight = screenRect.size.height;
    CGFloat scale = [UIScreen mainScreen].scale;

    double duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    bool isEts = [iOSTxtInputManager shareintance].isDeclarative;
    CGFloat inputBoxHeight = [iOSTxtInputManager shareintance].inputBoxY -
                             [iOSTxtInputManager shareintance].inputBoxTopY;
    CGFloat ty = keyboardY - [iOSTxtInputManager shareintance].inputBoxTopY -inputBoxHeight;
    if (isEts) {
        ty = keyboardY - inputBoxHeight - [iOSTxtInputManager shareintance].inputBoxTopY/scale;
    }
    [UIView animateWithDuration:duration animations:^{
        if (ty < 0) {
            self.view.transform = CGAffineTransformMakeTranslation(0, ty);
        }
    }];
}

- (void)keyboardWillBeHidden:(NSNotification*)notification{
    double duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:duration animations:^{
        self.view.transform = CGAffineTransformMakeTranslation(0, 0);
    }];
}

- (void)onLocaleUpdated:(NSNotification*)notification {

    NSLocale *locale = [NSLocale currentLocale];
    const char* languageCode = [locale languageCode] == nullptr ? "" : [locale languageCode].UTF8String;
    const char* countryCode = [locale countryCode] == nullptr ? "" : [locale countryCode].UTF8String;
    const char* scriptCode = [locale scriptCode] == nullptr ? "" : [locale scriptCode].UTF8String;

    OHOS::Ace::AceApplicationInfo::GetInstance().SetLocale(languageCode, countryCode, scriptCode, "");
}

#pragma mark IAceOnCallEvent
- (void)onEvent:(NSString *)eventId param:(NSString *)param {
    _aceView->GetPlatformResRegister()->OnEvent([eventId UTF8String], [param UTF8String]);
}

#pragma mark - Helper
+ (int32_t)genterateInstanceId {
    return CURRENT_INSTANCE_Id++;
}
@end
