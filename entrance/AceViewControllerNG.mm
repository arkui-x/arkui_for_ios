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

#include "flutter/fml/memory/weak_ptr.h"
#include "flutter/fml/message_loop.h"
#include "flutter/fml/platform/darwin/platform_version.h"
#include "flutter/fml/platform/darwin/scoped_nsobject.h"
#include "flutter/runtime/ptrace_check.h"
#include "flutter/shell/common/thread_host.h"

#include "flutter_ace_view.h"
#include "ace_container.h"
#include "adapter/ios/capability/editing/iOSTxtInputManager.h"
#include "adapter/ios/entrance/capability_registry.h"

#include "ace_shell/shell/platform/darwin/ios/framework/Headers/FlutterEngine.h"
#include "ace_shell/shell/platform/darwin/ios/framework/Source/FlutterEngine_Internal.h"
#include "ace_shell/shell/platform/darwin/ios/framework/Source/FlutterView.h"

#import "AceResourceRegisterOC.h"
#import "AceTextureResourcePlugin.h"
#import "AceVideoResourcePlugin.h"
#import "AceCameraResoucePlugin.h"

const std::string PAGE_URI = "url";
std::map <std::string, std::string> params_;
std::string remotePageUrl_;
std::string remoteData_;
const std::string CONTINUE_PARAMS_KEY = "__remoteData";
const int32_t THEME_ID_DEFAULT = 117440515;
int32_t CURRENT_INSTANCE_Id = 0;
NSString * ASSER_PATH  = @"js";

@interface AceViewController () <IAceOnCallEvent>
@end

@implementation AceViewController {
    OHOS::Ace::Platform::FlutterAceView *_aceView;
    flutter::ViewportMetrics _viewportMetrics;
    BOOL _hasLaunch;
    int32_t _aceInstanceId;
    std::unique_ptr <fml::WeakPtrFactory<AceViewController>> _weakFactory;
    fml::scoped_nsobject <FlutterEngine> _engine;
    fml::scoped_nsobject <FlutterView> _flutterView;
    AceResourceRegisterOC *_registerOC;
}

- (instancetype)initWithVersion:(ACE_VERSION)version
                bundleDirectory:(nonnull NSString*)bundleDirectory{
    if (self = [super init]) {
        _version = version;
        _bundleDirectory = bundleDirectory;
        _hasLaunch = NO;
        [self initAce];
    }
    return self;
}

- (instancetype)initWithVersion:(ACE_VERSION)version
                   instanceName:(nonnull NSString *)instanceName{
    NSString * bundleDirectory = [[NSBundle mainBundle] pathForResource:instanceName ofType:nil inDirectory:ASSER_PATH];
    NSAssert(bundleDirectory != nil, ([NSString stringWithFormat:@"Can not find the bundle named :%@", instanceName]));
    return [self initWithVersion:version bundleDirectory:bundleDirectory];
}

#pragma mark - UIViewController lifecycle notifications

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setupNotificationCenterObservers];
}

- (void)viewDidLayoutSubviews {
    [self updateViewSizeChanged];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_hasLaunch == NO) {
        [self updateViewSizeChanged];
        [self onLocaleUpdated:nil];
        OHOS::Ace::Platform::AceContainer::SetView(_aceView, _viewportMetrics.device_pixel_ratio,
                                                   _viewportMetrics.physical_width, _viewportMetrics.physical_height);
        [self runAcePage];
        _hasLaunch = YES;
    }
}

- (void)viewSafeAreaInsetsDidChange {
    [self updateViewportPadding];
    [self updateViewportMetrics];
    [super viewSafeAreaInsetsDidChange];
}

- (void)dealloc {
  [_engine.get() notifyViewControllerDeallocated];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

#pragma mark - Handle view resizing

- (void)updateViewportMetrics {}

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

- (void)updateViewSizeChanged {
    CGSize viewSize = self.view.bounds.size;
    CGFloat scale = [UIScreen mainScreen].scale;

    _viewportMetrics.device_pixel_ratio = scale;
    _viewportMetrics.physical_width = viewSize.width * scale;
    _viewportMetrics.physical_height = viewSize.height * scale;

    [self updateViewportPadding];
    [self updateViewportMetrics];
}

- (CGFloat)statusBarPadding {
    UIScreen *screen = self.view.window.screen;
    CGRect statusFrame = [UIApplication sharedApplication].statusBarFrame;
    CGRect viewFrame = [self.view convertRect:self.view.bounds
                            toCoordinateSpace:screen.coordinateSpace];
    CGRect intersection = CGRectIntersection(statusFrame, viewFrame);
    return CGRectIsNull(intersection) ? 0.0 : intersection.size.height;
}

#pragma mark - Helper
+ (int32_t)generateInstanceId {
    return CURRENT_INSTANCE_Id++;
}
#pragma mark - Application lifecycle notifications

- (void)applicationBecameActive:(NSNotification *)notification {
    NSLog(@"vail applicationBecameActive");
    OHOS::Ace::Platform::AceContainer::OnActive(_aceInstanceId);
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    NSLog(@"vail applicationWillResignActive");
    OHOS::Ace::Platform::AceContainer::OnInactive(_aceInstanceId);
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    NSLog(@"vail applicationDidEnterBackground");
    OHOS::Ace::Platform::AceContainer::OnHide(_aceInstanceId);
    std::string data = OHOS::Ace::Platform::AceContainer::OnSaveData(_aceInstanceId);
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
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    NSLog(@"vail applicationWillEnterForeground");
    OHOS::Ace::Platform::AceContainer::OnShow(_aceInstanceId);
    if (params_.count(PAGE_URI) > 0) {
        remotePageUrl_ = params_[PAGE_URI];
    }

    if (params_.count(CONTINUE_PARAMS_KEY) > 0) {
        remoteData_ = params_[CONTINUE_PARAMS_KEY];
    }
}

- (void)keyboardWillChangeFrame:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGFloat bottom = CGRectGetHeight([[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue]);
    CGFloat scale = [UIScreen mainScreen].scale;
    _viewportMetrics.physical_view_inset_bottom = bottom * scale;
    [self updateViewportMetrics];
}

- (void)keyboardWillBeHidden:(NSNotification *)notification {
    _viewportMetrics.physical_view_inset_bottom = 0;
    [self updateViewportMetrics];
}

- (void)onLocaleUpdated:(NSNotification*)notification {

    NSLocale *locale = [NSLocale currentLocale];
    const char* languageCode = [locale languageCode] == nullptr ? "" : [locale languageCode].UTF8String;
    const char* countryCode = [locale countryCode] == nullptr ? "" : [locale countryCode].UTF8String;
    const char* scriptCode = [locale scriptCode] == nullptr ? "" : [locale scriptCode].UTF8String;

    OHOS::Ace::AceApplicationInfo::GetInstance().SetLocale(languageCode, countryCode, scriptCode, "");
}

- (void)setupNotificationCenterObservers {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
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
    [center addObserver:self
               selector:@selector(onLocaleUpdated:)
                   name:NSCurrentLocaleDidChangeNotification
                 object:nil];
}


#pragma mark - Ace Methods

- (void)initAce {
    static std::once_flag onceFlag;
    std::call_once(onceFlag, []() {
        LOGI("Initialize for current process.");
        OHOS::Ace::Container::UpdateCurrent(OHOS::Ace::INSTANCE_ID_PLATFORM);
        OHOS::Ace::Platform::CapabilityRegistry::Register();
    });

    _aceInstanceId = [AceViewController generateInstanceId];
    _aceView = new OHOS::Ace::Platform::FlutterAceView(_aceInstanceId);

    [self initFlutterEngine:_aceInstanceId];

    _registerOC = [[AceResourceRegisterOC alloc] initWithParent:self];
    auto aceResRegister = OHOS::Ace::Referenced::MakeRefPtr<OHOS::Ace::Platform::AceResourceRegister>(_registerOC);
    _aceView->SetPlatformResRegister(aceResRegister);

    // register with plugins
    [_registerOC registerPlugin:[[AceVideoResourcePlugin alloc] init]];
    [_registerOC registerPlugin:[[AceCameraResoucePlugin alloc] init]];
    [_registerOC registerPlugin:[[AceTextureResourcePlugin alloc] initWithTextures:_engine.get()]];

    OHOS::Ace::Platform::FlutterAceView::IdleCallback idleNoticeCallback = [view = _aceView](int64_t deadline) {
        view->ProcessIdleEvent(deadline);

    };
    [self setIdleCallBack:idleNoticeCallback];

    constexpr char ASSET_PATH_SHARE[] = "share";
    OHOS::Ace::FrontendType frontendType = OHOS::Ace::FrontendType::DECLARATIVE_JS;
    if (_version == ACE_VERSION_JS) {
        frontendType = OHOS::Ace::FrontendType::JS;
    } else if (_version == ACE_VERSION_ETS) {
        frontendType = OHOS::Ace::FrontendType::DECLARATIVE_JS;
    }
    OHOS::Ace::Platform::AceContainer::CreateContainer(_aceInstanceId, frontendType);

    std::string argurl = _bundleDirectory.UTF8String;
    std::string customurl = OHOS::Ace::Platform::AceContainer::GetCustomAssetPath(argurl);
    OHOS::Ace::Platform::AceContainer::AddAssetPath(_aceInstanceId, "", {argurl, customurl.append(ASSET_PATH_SHARE)});
}

- (void)runAcePage {
    OHOS::Ace::Platform::AceContainer::RunPage(_aceInstanceId, 1, "", "");
}


#pragma mark - Touch event handling

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

// Touch time to be recovered
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

- (void) dispatchTouches:(NSSet *)touches
pointerDataChangeOverride:(flutter::PointerData::Change *)overridden_change {
   const CGFloat scale = [UIScreen mainScreen].scale;
   std::unique_ptr <flutter::PointerDataPacket> packet = std::make_unique<flutter::PointerDataPacket>(touches.count);

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



#pragma mark IAceOnCallEvent

- (void)onEvent:(NSString *)eventId param:(NSString *)param {
    _aceView->GetPlatformResRegister()->OnEvent([eventId UTF8String], [param UTF8String]);
}


#pragma mark - FlutterViewController

- (void)setIdleCallBack:(std::function<void(int64_t)>)idleCallback {
    flutter::ace::Shell &shell = [_engine.get() shell];
    auto platform_view = shell.GetPlatformView();
    if (!platform_view) {
        return;
    }
}

- (void)initFlutterEngine:(int32_t)instanceId {
    _weakFactory = std::make_unique < fml::WeakPtrFactory < AceViewController >> (self);

    _engine.reset([[FlutterEngine alloc] initWithName:@"io.flutter"
                               allowHeadlessExecution:NO]);
    _flutterView.reset([[FlutterView alloc] initWithDelegate:_engine opaque:YES]);
    [_engine.get() createShell:nil libraryURI:nil instanceId:instanceId];

    // loadview
    self.view = _flutterView.get();
    self.view.multipleTouchEnabled = YES;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [_engine.get() launchEngine:nil libraryURI:nil];

    [_engine.get() setViewController:self];

    [self surfaceUpdated:YES];
    flutter::ace::Shell &shell = [_engine.get() shell];
    fml::TimeDelta waitTime =
#if FLUTTER_RUNTIME_MODE == FLUTTER_RUNTIME_MODE_DEBUG
            fml::TimeDelta::FromMilliseconds(200);
#else
    fml::TimeDelta::FromMilliseconds(100);
#endif
    if (shell.WaitForFirstFrame(waitTime).code() == fml::StatusCode::kDeadlineExceeded) {
        FML_LOG(INFO) << "Timeout waiting for the first frame to render.  This may happen in "
                      << "unoptimized builds.  If this is a release build, you should load a less "
                      << "complex frame to avoid the timeout.";
    }
}


// Weak references provided for external use
- (fml::WeakPtr <AceViewController>)getWeakPtr {
    return _weakFactory->GetWeakPtr();
}

- (void)installFirstFrameCallback {
    if (!_engine) {
        return;
    }

    fml::WeakPtr<flutter::ace::PlatformViewIOS> weakPlatformView = [_engine.get() platformView];
    if (!weakPlatformView) {
        return;
    }

    // Start on the platform thread.
    weakPlatformView->SetNextFrameCallback([weakSelf = [self getWeakPtr],
                                                   platformTaskRunner = [_engine.get() platformTaskRunner],
                                                   RasterTaskRunner = [_engine.get() RasterTaskRunner]]() {
        FML_DCHECK(RasterTaskRunner->RunsTasksOnCurrentThread());
        // Get callback on raster thread and jump back to platform thread.
        platformTaskRunner->PostTask([weakSelf]() {
            fml::scoped_nsobject<AceViewController> aceViewController(
                    [(AceViewController*)weakSelf.get() retain]);
            if (aceViewController) {
                [aceViewController callViewRenderedCallback];
            }
        });
    });
}

- (void)surfaceUpdated:(BOOL)appeared {
    if (appeared) {
        [self installFirstFrameCallback];
        [_engine.get() platformViewsController]->SetFlutterView(_flutterView.get());
        [_engine.get() platformViewsController]->SetFlutterViewController(self);
        [_engine.get() platformView]->NotifyCreated();
    } else {
        [_engine.get() platformView]->NotifyDestroyed();
        [_engine.get() platformViewsController]->SetFlutterView(nullptr);
        [_engine.get() platformViewsController]->SetFlutterViewController(nullptr);
    }
}


- (flutter::ace::FlutterPlatformViewsController *)platformViewsController {
    return [_engine.get() platformViewsController];
}

#pragma mark - Properties

- (void)setFlutterViewDidRenderCallback:(void (^)(void))callback {}
#pragma mark - Managing launch views

- (void)callViewRenderedCallback {}
@end
