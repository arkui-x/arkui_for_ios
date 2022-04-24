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
#include "flutter/shell/platform/darwin/ios/framework/Headers/FlutterViewController.h"
#include "flutter/lib/ui/window/viewport_metrics.h"
#include "ace_container.h"
#include "flutter_ace_view.h"
#include "ace_resource_register.h"

#include "core/common/container.h"

#include "core/event/mouse_event.h"
#include "core/event/touch_event.h"

#include "flutter/fml/memory/weak_ptr.h"
#include "flutter/fml/platform/darwin/scoped_nsobject.h"
#include "adapter/ios/capability/editing/iOSTxtInputManager.h"
#include "adapter/preview/entrance/ace_run_args.h"
#include "frameworks/base/json/json_util.h"
#include "adapter/ios/entrance/capability_registry.h"

#import "AceResourceRegisterOC.h"
#import "AceTextureResourcePlugin.h"
#import "AceVideoResourcePlugin.h"
#import "AceCameraResoucePlugin.h"


int32_t abilityId_ = 0;
const std::string PAGE_URI = "url";
std::map<std::string, std::string> params_;
std::string remotePageUrl_;
std::string remoteData_;
const std::string CONTINUE_PARAMS_KEY = "__remoteData";
const int32_t THEME_ID_DEFAULT = 117440515;

int32_t CURRENT_INSTANCE_Id = 0;

@interface AceViewController ()<IAceOnCallEvent> 

@property(strong, nonatomic, readonly) FlutterViewController* flutterVc;

@end

@implementation AceViewController{
    OHOS::Ace::Platform::FlutterAceView *view_;
    flutter::ViewportMetrics _viewportMetrics;
    AceResourceRegisterOC *_registerOC;    
    int32_t aceInstanceId_;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
    
    [self setupNotificationCenterObservers];
    
    [self addSwipeRecognizer];
    
    static std::once_flag onceFlag;
    std::call_once(onceFlag, []() {
        LOGI("Initialize for current process.");
        OHOS::Ace::Container::UpdateCurrent(OHOS::Ace::INSTANCE_ID_PLATFORM);
        OHOS::Ace::Platform::CapabilityRegistry::Register();
    });

    aceInstanceId_ = [AceViewController genterateInstanceId];
    view_ = new OHOS::Ace::Platform::FlutterAceView(aceInstanceId_); 

    FlutterViewController *controller = [[FlutterViewController alloc] init];
    controller.view.frame = self.view.bounds;
    [self.view addSubview:controller.view];
    _flutterVc = controller;
    
    _registerOC = [[AceResourceRegisterOC alloc] initWithParent:self];
    auto aceResRegister = OHOS::Ace::Referenced::MakeRefPtr<OHOS::Ace::Platform::AceResourceRegister>(_registerOC);
    view_->SetPlatformResRegister(aceResRegister);

    // register with plugins
    [_registerOC registerPlugin:[[AceVideoResourcePlugin alloc] init]];
    [_registerOC registerPlugin:[[AceCameraResoucePlugin alloc] init]];
    [_registerOC registerPlugin:[[AceTextureResourcePlugin alloc] initWithTextures:_flutterVc.engine]];
    
    OHOS::Ace::Platform::FlutterAceView::IdleCallback idleNoticeCallback = [view = view_](int64_t deadline) { view->ProcessIdleEvent(deadline); };
    [controller setIdleCallBack:idleNoticeCallback];

    constexpr char ASSET_PATH_SHARE[] = "share";
    OHOS::Ace::FrontendType frontendType = OHOS::Ace::FrontendType::JS;
    OHOS::Ace::Platform::AceContainer::CreateContainer(aceInstanceId_, frontendType);

    /// 判断本地有没有文件
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"jsdemo"];
    BOOL exist = [[NSFileManager defaultManager] fileExistsAtPath:path];
    NSString *assetsPath = [[NSBundle mainBundle] pathForResource:@"jsdemo" ofType:nil];
    if (exist) {
      assetsPath = path;
    }

    NSString *js_framework = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"strip.native.min.js"];
    exist = [[NSFileManager defaultManager] fileExistsAtPath:js_framework];
    if (exist) {
      OHOS::Ace::Platform::AceContainer::SetJsFrameworkLocalPath(js_framework.UTF8String);
    }

    std::string argurl = assetsPath.UTF8String;
    std::string customurl = OHOS::Ace::Platform::AceContainer::GetCustomAssetPath(argurl);
    OHOS::Ace::Platform::AceContainer::CreateContainer(aceInstanceId_, frontendType);
    OHOS::Ace::Platform::AceContainer::CreateContainer(aceInstanceId_, frontendType);
    OHOS::Ace::Platform::AceContainer::AddAssetPath(aceInstanceId_, "", {argurl, customurl.append(ASSET_PATH_SHARE)});
    OHOS::Ace::Platform::AceContainer::SetResourcesPathAndThemeStyle(aceInstanceId_, "", "", THEME_ID_DEFAULT, OHOS::Ace::ColorMode::LIGHT);
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    UIScreen *screen = [UIScreen mainScreen];
    _viewportMetrics.physical_width = screen.bounds.size.width;
    _viewportMetrics.physical_height = screen.bounds.size.height;
    _viewportMetrics.device_pixel_ratio = screen.scale;
    
    [self updateViewportPadding];
    [self updateViewportMetrics];
    
    CGFloat width = _viewportMetrics.physical_width;
    CGFloat height = _viewportMetrics.physical_height;
    CGFloat scale = _viewportMetrics.device_pixel_ratio;
    OHOS::Ace::Platform::AceContainer::SetView(view_, scale, width*scale, height*scale);
    
    [self runAcePage];
    
    printf("vail viewWillAppear \n");
}

-(void)runAcePage{
    OHOS::Ace::Platform::AceContainer::RunPage(aceInstanceId_, 1, "", "");
}

- (void)updateViewportMetrics {
    [self.flutterVc.engine updateViewportMetrics:_viewportMetrics];
}

- (void)updateViewportPadding {
  CGFloat scale = [UIScreen mainScreen].scale;
  if (@available(iOS 11, *)) {
    _viewportMetrics.physical_padding_top = self.view.safeAreaInsets.top * scale;
    _viewportMetrics.physical_padding_left = self.view.safeAreaInsets.left * scale;
    _viewportMetrics.physical_padding_right = self.view.safeAreaInsets.right * scale;
    _viewportMetrics.physical_padding_bottom = self.view.safeAreaInsets.bottom * scale;
  } else {
    _viewportMetrics.physical_padding_top = [self statusBarPadding] * scale;
  }
}

- (CGFloat)statusBarPadding {
  UIScreen* screen = self.view.window.screen;
  CGRect statusFrame = [UIApplication sharedApplication].statusBarFrame;
  CGRect viewFrame = [self.view convertRect:self.view.bounds
                          toCoordinateSpace:screen.coordinateSpace];
  CGRect intersection = CGRectIntersection(statusFrame, viewFrame);
  return CGRectIsNull(intersection) ? 0.0 : intersection.size.height;
}

- (void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    printf("vail viewDidLayoutSubviews \n");
}

- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event {
  [self dispatchTouches:touches pointerDataChangeOverride:nullptr];
}

- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event {
  [self dispatchTouches:touches pointerDataChangeOverride:nullptr];
}

- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event {
  [self dispatchTouches:touches pointerDataChangeOverride:nullptr];
}

- (void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event {
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

static flutter::PointerData::DeviceKind DeviceKindFromTouchType(UITouch* touch) {
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

- (void)dispatchTouches:(NSSet*)touches
  pointerDataChangeOverride:(flutter::PointerData::Change*)overridden_change{
  const CGFloat scale = [UIScreen mainScreen].scale;
  std::unique_ptr<flutter::PointerDataPacket> packet = std::make_unique<flutter::PointerDataPacket>(touches.count);

  size_t pointer_index = 0;

  for (UITouch* touch in touches) {
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

    NSNumber* deviceKey = [NSNumber numberWithLongLong:pointer_data.device];
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

//   [_engine.get() dispatchPointerDataPacket:std::move(packet)];

  auto container = OHOS::Ace::Platform::AceContainer::GetContainerInstance(aceInstanceId_);
  if (!container) {
        LOGE("container is null");
        return;
    }

    auto aceView = container->GetAceView();
    if (!aceView) {
        LOGE("aceView is null");
        return;
    }

    std::promise<bool> touchPromise;
    std::future<bool> touchFuture = touchPromise.get_future();
    //container->GetTaskExecutor()->PostTask([aceView, &packet, &touchPromise]() {
         bool isHandled = aceView->HandleTouchEvent(packet->data());
         touchPromise.set_value(isHandled);
    //}, OHOS::Ace::TaskExecutor::TaskType::PLATFORM);
    
    touchFuture.get();
    
    //aceView->HandleTouchEvent(std::move(packet));
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
          OHOS::Ace::Platform::AceContainer::OnBackPressed(aceInstanceId_);
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
               selector:@selector(keyboardWillChangeFrame:)
                   name:UIKeyboardWillChangeFrameNotification
                 object:nil];

    [center addObserver:self
               selector:@selector(keyboardWillBeHidden:)
                   name:UIKeyboardWillHideNotification
                 object:nil];
    
    
}

#pragma mark - Application lifecycle notifications

- (void)applicationBecameActive:(NSNotification*)notification {
    NSLog(@"vail applicationBecameActive");
    OHOS::Ace::Platform::AceContainer::OnActive(aceInstanceId_);
    //if (_viewportMetrics.physical_width)
    //[self surfaceUpdated:YES];
    //[[_engine.get() lifecycleChannel] sendMessage:@"AppLifecycleState.resumed"];
}

- (void)applicationWillResignActive:(NSNotification*)notification {
    NSLog(@"vail applicationWillResignActive");
   OHOS::Ace::Platform::AceContainer::OnInactive(aceInstanceId_);
  //[self surfaceUpdated:NO];
  //[[_engine.get() lifecycleChannel] sendMessage:@"AppLifecycleState.inactive"];
}

- (void)applicationDidEnterBackground:(NSNotification*)notification {
  NSLog(@"vail applicationDidEnterBackground");
  OHOS::Ace::Platform::AceContainer::OnHide(aceInstanceId_);
  std::string data = OHOS::Ace::Platform::AceContainer::OnSaveData(aceInstanceId_);
  if (data == "false") {
      printf("vail save data is null \n");
  }

  auto json = OHOS::Ace::JsonUtil::ParseJsonString(data);
  if (!json) {
      printf("vail parseJson is null \n");
  }

  params_.clear();
  if (json->Contains(PAGE_URI)) {
    std::string param = json->GetString(PAGE_URI);
    params_[PAGE_URI] = param;
  }

  if (json->Contains(CONTINUE_PARAMS_KEY)) {
     std::string params = json->GetObject(CONTINUE_PARAMS_KEY)->ToString();
     params_[CONTINUE_PARAMS_KEY] = params;
  }
    
  //[[_engine.get() lifecycleChannel] sendMessage:@"AppLifecycleState.paused"];
}

- (void)applicationWillEnterForeground:(NSNotification*)notification {
    NSLog(@"vail applicationWillEnterForeground");
    OHOS::Ace::Platform::AceContainer::OnShow(aceInstanceId_);
    if(params_.count(PAGE_URI) > 0){
        remotePageUrl_ = params_[PAGE_URI];
    }

    if(params_.count(CONTINUE_PARAMS_KEY)>0){
        remoteData_ = params_[CONTINUE_PARAMS_KEY];
    }
    //[[_engine.get() lifecycleChannel] sendMessage:@"AppLifecycleState.inactive"];
}

- (void)keyboardWillChangeFrame:(NSNotification*)notification {
  NSDictionary* info = [notification userInfo];
  CGFloat bottom = CGRectGetHeight([[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue]);
  CGFloat scale = [UIScreen mainScreen].scale;
  _viewportMetrics.physical_view_inset_bottom = bottom * scale;
  [self updateViewportMetrics];
}

- (void)keyboardWillBeHidden:(NSNotification*)notification {
  _viewportMetrics.physical_view_inset_bottom = 0;
  [self updateViewportMetrics];
}

#pragma mark IAceOnCallEvent
- (void)onEvent:(NSString *)eventId param:(NSString *)param{
  view_->GetPlatformResRegister()->OnEvent([eventId UTF8String], [param UTF8String]);
}

#pragma mark - Helper
+(int32_t)genterateInstanceId{
    return CURRENT_INSTANCE_Id++;
}
@end
