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

#import "StageViewController.h"

#import <MobileCoreServices/MobileCoreServices.h>
#import <PhotosUI/PhotosUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "AccessibilityWindowView.h"
#import "AcePlatformPlugin.h"
#import "ArkUIXPluginRegistry.h"
#import "BridgePluginManager+internal.h"
#import "BridgePluginManager.h"
#import "InstanceIdGenerator.h"
#import "PluginContext.h"
#import "StageApplication.h"
#import "StageAssetManager.h"
#import "StageConfigurationManager.h"
#import "StageContainerView.h"
#import "StageSecureContainerView.h"
#import "WindowView.h"
#include "app_main.h"
#include "window_view_adapter.h"

#define PHOTO_PICKER_TYPE_IMAGE @"image/*"
#define PHOTO_PICKER_TYPE_VIDEO @"video/*"
#define PHOTO_PICKER_BASE_PATH @"file://%@"
#define BUNDLENAME_FILEPICKER @"com.ohos.filepicker"
#define BUNDLENAME_PHOTOPICKER @"com.ohos.photos"
#define TYPE_STRING @10
#define RESULTCODE_OK 0
#define RESULTCODE_ERROR 1

#define PUBLIC_CONTENT @"public.content"
#define PUBLIC_TEXT @"public.text"
#define PUBLIC_IMAGE @"public.image"
#define PUBLIC_VIDEO @"public.movie"
#define PUBLIC_AUDIO @"public.audio"
#define kOrientationMaskUpdateNotificationName "arkui_x.iosPlatform.setPreferredOrientationNotificationName"
#define kOrientationMaskUpdateNotificationKey "arkui_x.iosPlatform.setPreferredOrientationNotificationKey"

using AppMain = OHOS::AbilityRuntime::Platform::AppMain;
using WindowViwAdapter = OHOS::AbilityRuntime::Platform::WindowViewAdapter;
int32_t CURRENT_STAGE_INSTANCE_Id = 0;
@interface StageViewController () <UITraitEnvironment, WindowViewDelegate, UIDocumentPickerDelegate,
    UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate> {
    int32_t _instanceId;
    std::string _cInstanceName;
    AccessibilityWindowView *_windowView;
    AcePlatformPlugin *_platformPlugin;
    BridgePluginManager *_bridgePluginManager;
    BOOL _needOnForeground;
    NSMutableArray* _pluginList;
    ArkUIXPluginRegistry* _arkUIXPluginRegistry;
    PluginContext* _pluginContext;
    StageContainerView* _stageContainerView;
}

@property(nonatomic, strong, readwrite) NSString* instanceName;
@property(nonatomic, copy) NSString* bundleName;
@property(nonatomic, copy) NSString* moduleName;
@property(nonatomic, copy) NSString* abilityName;
@property(nonatomic, copy) NSString* adapterInstanceName;
@property(nonatomic, assign) NSInteger requestCode;
@property(nonatomic, copy) NSString* adapterBundleName;
@property(nonatomic, copy) NSString* type;
@property(nonatomic, assign) BOOL allowsMultipleSelection;
@property(nonatomic, assign) BOOL isReturnValue;
@property(nonatomic, assign) UIInterfaceOrientationMask interfaceOrientationMask;
@end

@implementation StageViewController

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
        self.homeIndicatorHidden = NO;
        self.interfaceOrientationMask = UIInterfaceOrientationMaskAll;
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(orientationMaskUpdate:)
            name:@(kOrientationMaskUpdateNotificationName) object:nil];
    }
    return self;
}

- (void)orientationMaskUpdate: (NSNotification *)notification {
    NSDictionary *dic = notification.userInfo;
    NSNumber *orientationMask = dic[@(kOrientationMaskUpdateNotificationKey)];
    if (orientationMask == nil || self.interfaceOrientationMask == orientationMask.unsignedIntegerValue) {
        return;
    }
    self.interfaceOrientationMask = orientationMask.unsignedIntegerValue;
    __weak StageViewController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 16.0, *)) {
            [weakSelf setNeedsUpdateOfSupportedInterfaceOrientations];
            NSArray *array = [[[UIApplication sharedApplication] connectedScenes] allObjects];
            UIWindowScene *scene = [array firstObject];
            UIInterfaceOrientationMask OrientationMask = weakSelf.interfaceOrientationMask;
            UIWindowSceneGeometryPreferencesIOS *geometryPreferencesIOS = 
                [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:OrientationMask];
            /* start transform animation */
            [scene requestGeometryUpdateWithPreferences:geometryPreferencesIOS 
                errorHandler:^(NSError * _Nonnull error) {}];
        } else {
            [weakSelf setNewOrientation:weakSelf.interfaceOrientationMask];
        }
    });
}

- (void)setNewOrientation:(UIInterfaceOrientationMask)orientationMask {
    UIInterfaceOrientation currentOrientation = UIInterfaceOrientationUnknown;
    if (@available(iOS 13.0, *)) {
        NSArray *array = [[[UIApplication sharedApplication] connectedScenes] allObjects];
        UIWindowScene *scene = [array firstObject];
        currentOrientation = scene.interfaceOrientation;
    } else {
        currentOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    }
    if (orientationMask & (1 << currentOrientation)) {
        return;
    }
    [UIViewController attemptRotationToDeviceOrientation];
    UIInterfaceOrientation Orientation = UIInterfaceOrientationUnknown;
    if (orientationMask & UIInterfaceOrientationMaskPortrait) {
        Orientation = UIInterfaceOrientationPortrait;
    } else if (orientationMask & UIInterfaceOrientationMaskPortraitUpsideDown) {
        Orientation = UIInterfaceOrientationPortraitUpsideDown;
    } else if (orientationMask & UIInterfaceOrientationMaskLandscapeRight) {
        Orientation = UIInterfaceOrientationLandscapeRight;
    } else if (orientationMask & UIInterfaceOrientationMaskLandscapeLeft) {
        Orientation = UIInterfaceOrientationLandscapeLeft;
    }
    NSNumber *resetOrientationTarget = [NSNumber numberWithInt:UIInterfaceOrientationUnknown];
    [[UIDevice currentDevice] setValue:resetOrientationTarget forKey:@"orientation"];
    NSNumber *orientationTarget = [NSNumber numberWithInt:Orientation];
    [[UIDevice currentDevice] setValue:orientationTarget forKey:@"orientation"];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return self.interfaceOrientationMask;
}

- (BOOL)shouldAutorotate {
    return true;
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
    _windowView = [[AccessibilityWindowView alloc] init];
    [_windowView startBaseDisplayLink];
    _windowView.frame = self.view.bounds;
    _windowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    WindowViwAdapter::GetInstance()->AddWindowView(_cInstanceName, (__bridge void*)_windowView);
    [_stageContainerView addSubview: _windowView];
    [_stageContainerView setMainWindow:_windowView];
}

- (void)initBridge {
    _bridgePluginManager = [BridgePluginManager innerBridgePluginManager:_instanceId];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _stageContainerView = [[StageContainerView alloc]initWithFrame:self.view.bounds];
    if ([self supportWindowPrivacyMode]) {
        self.view = [[StageSecureContainerView alloc]initWithFrame:self.view.bounds];
        [((StageSecureContainerView*)self.view)  addView: _stageContainerView];
    } else {
        self.view = _stageContainerView;
    }
    self.view.isAccessibilityElement = NO;
    _stageContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _stageContainerView.notifyDelegate = self;
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

- (BOOL)supportWindowPrivacyMode {
    return false;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSLog(@"StageVC->%@ viewDidAppear call.", self);
    if (_platformPlugin) {
        [_platformPlugin notifyLifecycleChanged:false];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_bridgePluginManager) {
        [_bridgePluginManager updateCurrentInstanceId:_instanceId];
    }
    if (_needOnForeground) {
        AppMain::GetInstance()->DispatchOnForeground(_cInstanceName);
    }
    _needOnForeground = true;
    [_stageContainerView notifyForeground];
    [_stageContainerView notifyActiveChanged:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    NSLog(@"StageVC->%@ viewDidDisappear call.", self);
    AppMain::GetInstance()->DispatchOnBackground(_cInstanceName);
    if (_platformPlugin) {
        [_platformPlugin notifyLifecycleChanged:true];
    }
    [_stageContainerView notifyBackground];
    [_stageContainerView notifyActiveChanged:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    NSLog(@"StageVC->%@ didReceiveMemoryWarning call.", self);
    if (!self.view) {
    // Ability::OnWindowStageDestroy
    }
}

- (void)destroyData {
    if ([UIDevice currentDevice].systemVersion.floatValue >= 18.0) {
        NSLog(@"iOS 18 StageVC->%@ dealloc destroyData", self);
        [_platformPlugin platformRelease];
        _platformPlugin = nil;
        [_windowView notifySurfaceDestroyed];
        [_windowView notifyWindowDestroyed];
        _windowView = nil;
        _stageContainerView = nil;
        [BridgePluginManager innerUnbridgePluginManager:_instanceId];
        _bridgePluginManager = nil;
        [self deallocArkUIXPlugin];
        AppMain::GetInstance()->DispatchOnDestroy(_cInstanceName);
        [self removeFromParentViewController];
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

- (void)dealloc {
    NSLog(@"StageVC->%@ dealloc", self);
    [_windowView notifySurfaceDestroyed];
    [_windowView notifyWindowDestroyed];
    _windowView = nil;
    _stageContainerView = nil;
    [_platformPlugin platformRelease];
    _platformPlugin = nil;
    [BridgePluginManager innerUnbridgePluginManager:_instanceId];
    _bridgePluginManager = nil;
    [self deallocArkUIXPlugin];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    AppMain::GetInstance()->DispatchOnDestroy(_cInstanceName);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {

    BOOL isSplitScreen = NO;
    if ([UIScreen mainScreen].bounds.size.width != self.view.window.bounds.size.width) {
        isSplitScreen = YES;
    }
    [_windowView notifyTraitCollectionDidChange:isSplitScreen];
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        return;
    }
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            [[StageConfigurationManager configurationManager] colorModeUpdate:self.traitCollection.userInterfaceStyle];
        }
    }
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    UIInterfaceOrientation currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
    [[StageConfigurationManager configurationManager] directionUpdate:currentOrientation];
    [_platformPlugin notifyOrientationDidChange];
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
    _pluginContext = [[PluginContext alloc] initPluginContext:[self getBridgeManager] moduleName:self.moduleName];
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

- (id)getPluginContext {
    return _pluginContext;
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
    if ([controller respondsToSelector:@selector(instanceName)]) {
        NSString *topInstanceName = controller.instanceName;
        if ([self.instanceName isEqualToString:topInstanceName]) {
            return true;
        }
    }
    return false;
}

- (BOOL)processBackPress {
    return [_windowView processBackPressed];
}

#pragma mark - WindowViewDelegate 
- (void)notifyApplicationWillEnterForeground {
    if ([self isTopController]) {
        if (_platformPlugin) {
            [_platformPlugin notifyLifecycleChanged:false];
        }
    }
}

- (void)notifyApplicationDidEnterBackground {
    if ([self isTopController]) {
        if (_platformPlugin) {
            [_platformPlugin notifyLifecycleChanged:true];
        }
    }
}

- (void)notifyApplicationWillTerminateNotification {
   [_bridgePluginManager platformWillTerminate];
}

- (BOOL)prefersStatusBarHidden {
    return self.statusBarHidden;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return self.statusBarStyle;
}

- (UIStatusBarAnimation)prefersStatusBarUpdateAnimation {
    if (self.statusBarAnimation) {
        return UIStatusBarAnimationFade;
    } else {
        return UIStatusBarAnimationNone;
    }
}
- (BOOL)prefersHomeIndicatorAutoHidden {
    return self.homeIndicatorHidden;
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

- (void)registerPlatformViewFactory:(NSObject<PlatformViewFactory> *)platformViewFactory{
    if (_platformPlugin) {
        [_platformPlugin registerPlatformViewFactory:platformViewFactory];
    }
}

- (int32_t)startAbilityForResult:(NSDictionary*)dicParams isReturnValue:(BOOL)isReturnValue
{
    self.adapterBundleName = dicParams[@"bundleName"];
    self.type = dicParams[@"type"];
    self.isReturnValue = isReturnValue;
    self.allowsMultipleSelection = NO;
    NSString* params = dicParams[@"wantJsonStr"];
    if (params != nil && params.length > 0) {
        NSData* jsonData = [params dataUsingEncoding:NSUTF8StringEncoding];
        NSError* error = nil;
        NSDictionary* jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (error) {
            return OHOS::ERR_INVALID_VALUE;
        }
        NSArray* paramsArray = jsonObject[@"params"];
        for (NSDictionary* paramDict in paramsArray) {
            NSString* key = paramDict[@"key"];
            NSString* value = paramDict[@"value"];
            if ([key isEqualToString:@"uri"] && [value isEqualToString:@"multipleselect"]) {
                self.allowsMultipleSelection = YES;
                break;
            } else {
                self.allowsMultipleSelection = NO;
            }
        }
    }
    NSString* bundleName = dicParams[@"bundleName"];
    NSString* instanceName = dicParams[@"instanceName"];
    NSInteger requestCode = [dicParams[@"requestCode"] integerValue];
    if ([bundleName isEqualToString:BUNDLENAME_FILEPICKER]) {
        [self selectDocumentWithInstanceName:instanceName requestCode:requestCode];
    } else if ([bundleName isEqualToString:BUNDLENAME_PHOTOPICKER]) {
        [self selectPhotoWithInstanceName:instanceName requestCode:requestCode];
    } else {
        return OHOS::ERR_INVALID_VALUE;
    }
    return OHOS::ERR_OK;
}

- (void)selectDocumentWithInstanceName:(NSString*)instanceName requestCode:(NSInteger)requestCode
{
    self.adapterInstanceName = instanceName;
    self.requestCode = requestCode;
    NSArray* documentTypes = [self convertToUTIType:self.type];
    UIDocumentPickerViewController* picker =
        [[UIDocumentPickerViewController alloc] initWithDocumentTypes:documentTypes inMode:UIDocumentPickerModeOpen];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFullScreen;
    if (self.allowsMultipleSelection) {
        picker.allowsMultipleSelection = YES;
    } else {
        picker.allowsMultipleSelection = NO;
    }
    [self presentViewController:picker animated:YES completion:nil];
}

- (NSArray<NSString *> *)convertToUTIType:(NSString *)inputString {
    if ([self isBlankString:inputString] || inputString.length <= 0) {
        return @[ PUBLIC_CONTENT ];
    }

    NSString *utiFromExt = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(
        kUTTagClassFilenameExtension,
        (__bridge CFStringRef)inputString,
        NULL
    );
    if (![utiFromExt hasPrefix:@"dyn."] && utiFromExt) {
        return @[utiFromExt];
    }

    NSString *utiFromMime = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(
        kUTTagClassMIMEType,
        (__bridge CFStringRef)inputString,
        NULL
    );
    if (![utiFromMime hasPrefix:@"dyn."] && utiFromMime) {
        return @[utiFromMime];
    }
    NSDictionary *utiMapping = @{
        @"image/*": @[PUBLIC_IMAGE],
        @"video/*": @[PUBLIC_VIDEO],
        @"audio/*": @[PUBLIC_AUDIO],
        @"text/*": @[PUBLIC_TEXT],
        @"application/*": @[PUBLIC_CONTENT]
    };
    if ([utiMapping.allKeys containsObject:inputString]) {
        return utiMapping[inputString];
    }
    return @[ PUBLIC_CONTENT ];
}

- (BOOL)isBlankString:(NSString*)string
{
    if (string == nil || string == NULL) {
        return YES;
    }
    if (![string isKindOfClass:[NSString class]]) {
        return YES;
    }
    if ([[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) {
        return YES;
    }
    return NO;
}

- (void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls
{
    if (self.isReturnValue) {
        [self selectDocumentPickerData:urls];
    }
}

- (void)selectDocumentPickerData:(NSArray<NSURL*>*)urls
{
    NSMutableArray* uris = [NSMutableArray array];
    for (NSURL* url in urls) {
        BOOL fileUrlAuthozied = [url startAccessingSecurityScopedResource];
        if (!fileUrlAuthozied) {
            [self selectDataParseToJsonString:uris errorCode:RESULTCODE_ERROR];
            break;
        }
        NSFileCoordinator* fileCoordinator = [[NSFileCoordinator alloc] init];
        NSError* error = nil;
        [fileCoordinator coordinateReadingItemAtURL:url
                                            options:0
                                              error:&error
                                         byAccessor:^(NSURL* newURL) {
                                           [uris addObject:newURL.absoluteString];
                                           if (uris.count == urls.count) {
                                               [self selectDataParseToJsonString:uris errorCode:RESULTCODE_OK];
                                           }
                                         }];

        [url stopAccessingSecurityScopedResource];
        if (error) {
            [self selectDataParseToJsonString:uris errorCode:RESULTCODE_ERROR];
            break;
        }
    }
}

- (void)selectDataParseToJsonString:(NSArray<NSString*>*)uris errorCode:(int)errorCode
{
    std::string instanceName = [self.adapterInstanceName UTF8String];
    NSMutableArray* dictArray = [[NSMutableArray alloc] init];
    NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
    if ([self.adapterBundleName isEqualToString:BUNDLENAME_FILEPICKER]) {
        [dictionary setObject:@"ability.params.stream" forKey:@"key"];
    } else if ([self.adapterBundleName isEqualToString:BUNDLENAME_PHOTOPICKER]) {
        [dictionary setObject:@"select-item-list" forKey:@"key"];
    }
    [dictionary setObject:TYPE_STRING forKey:@"type"];

    NSError* error = nil;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:uris options:NSJSONWritingPrettyPrinted error:&error];
    if (!error) {
        NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [dictionary setObject:jsonString forKey:@"value"];
    }
    [dictArray addObject:dictionary];
    NSDictionary* resultDic = @{ @"params" : dictArray };

    NSError* resultError = nil;
    NSData* resultJsonData = [NSJSONSerialization dataWithJSONObject:resultDic
                                                             options:NSJSONWritingPrettyPrinted
                                                               error:&resultError];
    if (resultError != nil) {
        AppMain::GetInstance()->DispatchOnAbilityResult(instanceName, self.requestCode, errorCode, "");
        return;
    }
    NSString* resultJsonStr = [[NSString alloc] initWithData:resultJsonData encoding:NSUTF8StringEncoding];
    std::string resultJsonStrPath = [resultJsonStr UTF8String];
    AppMain::GetInstance()->DispatchOnAbilityResult(instanceName, self.requestCode, errorCode, resultJsonStrPath);
}

#pragma mark - UIImagePickerController
- (void)presentPhotoPickerVC
{
    if (@available(iOS 14, *)) {
        PHPickerConfiguration* config = [[PHPickerConfiguration alloc] init];
        if (self.allowsMultipleSelection) {
            config.selectionLimit = 0;
        } else {
            config.selectionLimit = 1;
        }
        NSString* type = self.type;
        if ([type isEqualToString:PHOTO_PICKER_TYPE_IMAGE]) {
            config.filter = [PHPickerFilter imagesFilter];
        } else if ([type isEqualToString:PHOTO_PICKER_TYPE_VIDEO]) {
            config.filter = [PHPickerFilter videosFilter];
        } else {
            config.filter = [PHPickerFilter
                anyFilterMatchingSubfilters:@[ PHPickerFilter.imagesFilter, PHPickerFilter.videosFilter ]];
        }
        PHPickerViewController* phPickerVC = [[PHPickerViewController alloc] initWithConfiguration:config];
        phPickerVC.modalPresentationStyle = UIModalPresentationFullScreen;
        phPickerVC.delegate = self;
        [self presentViewController:phPickerVC animated:YES completion:nil];
    } else {
        UIImagePickerController* imagePickerVC = [[UIImagePickerController alloc] init];
        imagePickerVC.delegate = self;
        NSString* type = self.type;
        if ([type isEqualToString:PHOTO_PICKER_TYPE_IMAGE]) {
            imagePickerVC.mediaTypes = @[ (NSString*)kUTTypeImage ];
        } else if ([type isEqualToString:PHOTO_PICKER_TYPE_VIDEO]) {
            imagePickerVC.mediaTypes = @[ (NSString*)kUTTypeMovie ];
        } else {
            imagePickerVC.mediaTypes = @[ (NSString*)kUTTypeImage, (NSString*)kUTTypeMovie ];
        }
        imagePickerVC.modalPresentationStyle = UIModalPresentationFullScreen;
        [self presentViewController:imagePickerVC animated:YES completion:nil];
    }
}

- (void)selectPhotoWithInstanceName:(NSString*)instanceName requestCode:(NSInteger)requestCode
{
    self.adapterInstanceName = instanceName;
    self.requestCode = requestCode;
    BOOL isAuthorize = [self checkPhotoPermission];
    if (isAuthorize) {
        [self presentPhotoPickerVC];
    } else {
        [self requestAlbumAuthorization];
    }
}

- (void)imagePickerController:(UIImagePickerController*)picker
    didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id>*)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (self.isReturnValue) {
        [self selectImagePickerData:info];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController*)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)selectImagePickerData:(NSDictionary<UIImagePickerControllerInfoKey, id>*)info
{
    NSString* type = (NSString*)[info objectForKey:UIImagePickerControllerMediaType];
    NSURL* mediaUrl = [info objectForKey:[self getImagePickerType:type]];
    if (mediaUrl == nil) {
        [self selectDataParseToJsonString:@[ @"" ] errorCode:RESULTCODE_ERROR];
        return;
    }
    NSString* pickerUrlString = [[NSString alloc] initWithFormat:PHOTO_PICKER_BASE_PATH, [mediaUrl path]];
    [self selectDataParseToJsonString:@[ pickerUrlString ] errorCode:RESULTCODE_OK];
}

- (NSString*)getImagePickerType:(NSString*)type
{
    if ([type isEqualToString:(NSString*)kUTTypeImage]) {
        return UIImagePickerControllerImageURL;
    } else if ([type isEqualToString:(NSString*)kUTTypeMovie]) {
        return UIImagePickerControllerMediaURL;
    } else {
        return @"";
    }
}

#pragma mark - PHPickerViewControllerDelegate
- (void)picker:(PHPickerViewController*)picker
    didFinishPicking:(nonnull NSArray<PHPickerResult*>*)results API_AVAILABLE(ios(14))
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (self.isReturnValue) {
        [self selectPhPickerData:results];
    }
}

- (void)selectPhPickerData:(nonnull NSArray<PHPickerResult*>*)results
{
    NSMutableArray* uriArray = [[NSMutableArray alloc] init];
    __block int errorCode = RESULTCODE_OK;
    for (int i = 0; i < results.count; i++) {
        PHPickerResult* result = results[i];
        NSString* strType = @"";
        if ([result.itemProvider hasItemConformingToTypeIdentifier:UTTypeImage.identifier]) {
            strType = UTTypeImage.identifier;
        } else if ([result.itemProvider hasItemConformingToTypeIdentifier:UTTypeMovie.identifier]) {
            strType = UTTypeMovie.identifier;
        }

        [result.itemProvider
            loadFileRepresentationForTypeIdentifier:strType
                                  completionHandler:^(NSURL* _Nullable url, NSError* _Nullable error) {
                                    int resultCode = [self saveResultData:uriArray url:url error:error];
                                    if (resultCode == RESULTCODE_ERROR) {
                                        errorCode = RESULTCODE_ERROR;
                                    }
                                    if (uriArray.count >= results.count) {
                                        [self selectDataParseToJsonString:uriArray errorCode:errorCode];
                                    }
                                  }];
    }
}

- (int)saveResultData:(NSMutableArray*)uriArray url:(NSURL*)url error:(NSError*)error
{
    if (error || url == nil) {
        [uriArray addObject:@""];
        return RESULTCODE_ERROR;
    }
    NSString* cachePath = [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), [url lastPathComponent]];
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:cachePath]) {
        [fileManager removeItemAtPath:cachePath error:nil];
    }
    NSData* data = [NSData dataWithContentsOfFile:[url path]];
    BOOL success = [data writeToFile:cachePath atomically:YES];
    if (success) {
        cachePath = [NSString stringWithFormat:PHOTO_PICKER_BASE_PATH, cachePath];
        [uriArray addObject:cachePath];
        return RESULTCODE_OK;
    }
    [uriArray addObject:@""];
    return RESULTCODE_ERROR;
}

- (void)requestAlbumAuthorization
{
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
      if (status == PHAuthorizationStatusAuthorized) {
          [self presentPhotoPickerInMainQueue];
          return;
      }
      if (@available(iOS 14, *) && status == PHAuthorizationStatusLimited) {
          [self presentPhotoPickerInMainQueue];
      }
    }];
}

- (void)presentPhotoPickerInMainQueue
{
    dispatch_async(dispatch_get_main_queue(), ^{
      [self presentPhotoPickerVC];
    });
}

- (BOOL)checkPhotoPermission
{
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusAuthorized) {
        return YES;
    }
    if (@available(iOS 14, *) && status == PHAuthorizationStatusLimited) {
        return YES;
    }
    return NO;
}

- (void)setPrivacyMode:(BOOL)privacyMode {
    if (![self supportWindowPrivacyMode]) {
        return;
    }
    if (_privacyMode != privacyMode) {
        _privacyMode = privacyMode;
        ((StageSecureContainerView*)self.view).secureTextEntry = privacyMode;
    }
}

- (UIView *)getWindowView {
    return _windowView;
}
@end