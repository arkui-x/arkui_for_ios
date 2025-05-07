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
 
#import "AcePlatformPlugin.h"

#import "AceTextureResourcePlugin.h"
#import "AceTextureDelegate.h"
#import "AceVideoResourcePlugin.h"
#import "AceSurfacePlugin.h"
#import "adapter/ios/capability/web/AceWebResourcePlugin.h"
#import "AcePlatformViewPlugin.h"
#import "AcePlatformViewDelegate.h"

#include "adapter/ios/entrance/ace_resource_register.h"
#include "adapter/ios/entrance/ace_platform_plugin.h"
#include "core/common/container_scope.h"

@interface AcePlatformPlugin()<IAceOnCallEvent, IAceSurface, AceTextureDelegate, AcePlatformViewDelegate>
{
    AceVideoResourcePlugin* _videoResourcePlugin;
    AceSurfacePlugin* _aceSurfacePlugin;
    AceResourceRegisterOC* _resRegister;
    AceWebResourcePlugin* _webResourcePlugin;
    AceTextureResourcePlugin* _textureResourcePlugin;
    AcePlatformViewPlugin* _platformViewPlugin;
}
@property (nonatomic, assign) int32_t instanceId;
@end
@implementation AcePlatformPlugin

- (instancetype)initPlatformPlugin:(id)target
    instanceId:(int32_t)instanceId moduleName:(NSString *_Nonnull)moduleName
{
    self = [super init];
    if (self) {
        if(target){
            self.instanceId = instanceId;
            _resRegister = [[AceResourceRegisterOC alloc] initWithParent:self];
            auto aceResRegister =
                OHOS::Ace::Referenced::MakeRefPtr<OHOS::Ace::Platform::AceResourceRegister>(_resRegister);
            OHOS::Ace::Platform::AcePlatformPlugin::InitResRegister(instanceId,aceResRegister);

            if(moduleName && moduleName.length != 0){
                _videoResourcePlugin = [AceVideoResourcePlugin createRegister:moduleName abilityInstanceId:instanceId];
                [self addResourcePlugin:_videoResourcePlugin];

                _aceSurfacePlugin = [AceSurfacePlugin createRegister:target abilityInstanceId:instanceId delegate:self];
                [self addResourcePlugin:_aceSurfacePlugin];

                _webResourcePlugin = [AceWebResourcePlugin createRegister:target abilityInstanceId:instanceId];
                [self addResourcePlugin:_webResourcePlugin];

                _textureResourcePlugin = [AceTextureResourcePlugin createTexturePluginWithInstanceId:instanceId];
                _textureResourcePlugin.delegate = self;
                [self addResourcePlugin:_textureResourcePlugin];

                _platformViewPlugin = [AcePlatformViewPlugin createRegister:moduleName abilityInstanceId:instanceId];
                _platformViewPlugin.delegate = self;
                [self addResourcePlugin:_platformViewPlugin];
            }
        }
    }
    return self;
}

- (void)addResourcePlugin:(AceResourcePlugin *)plugin
{
    if(plugin && _resRegister){
        [_resRegister registerPlugin:plugin];
    }
}

- (void)notifyLifecycleChanged:(BOOL)isBackground
{
    if(_resRegister){
        [_resRegister notifyLifecycleChanged:isBackground];
    }
}

- (void)platformRelease {
    if (_videoResourcePlugin) {
        [_videoResourcePlugin releaseObject];
        _videoResourcePlugin = nil;
    }
    if (_aceSurfacePlugin) {
        [_aceSurfacePlugin releaseObject];
        _aceSurfacePlugin = nil;
    }
    if (_textureResourcePlugin) {
        [_textureResourcePlugin releaseObject];
        _textureResourcePlugin.delegate = nil;
        _textureResourcePlugin = nil;
    }
    if (_webResourcePlugin) {
        [_webResourcePlugin releaseObject];
        _webResourcePlugin = nil;
    }
    if (_resRegister) {
        [_resRegister releaseObject];
        [_resRegister release];
        _resRegister = nil;
    }
}

#pragma mark IAceOnCallEvent
- (void)onEvent:(NSString *)eventId param:(NSString *)param
{
    auto resRegister = OHOS::Ace::Platform::AcePlatformPlugin::GetResRegister(self.instanceId);
    OHOS::Ace::ContainerScope scope(self.instanceId);
    const char* eventIdcString = [eventId UTF8String];
    const char* paramcString = [param UTF8String];
    resRegister->OnEvent(eventIdcString, paramcString);
}

#pragma mark AceTextureDelegate
- (void)registerSurfaceWithInstanceId:(int32_t)instanceId textureId:(int64_t)textureId
    textureObject:(void*)textureObject
{
    NSLog(@"AceTextureDelegate registerSurface");
    OHOS::Ace::Platform::AcePlatformPlugin::RegisterSurface(instanceId, textureId,textureObject);
}

- (void)unregisterSurfaceWithInstanceId:(int32_t)instanceId textureId:(int64_t)textureId
{
    NSLog(@"AceTextureDelegate unregisterSurface");
    OHOS::Ace::Platform::AcePlatformPlugin::UnregisterSurface(instanceId,textureId);
}

- (void*)getNativeWindowWithInstanceId:(int32_t)instanceId textureId:(int64_t)textureId
{
    NSLog(@"AceTextureDelegate getNativeWindow");
    return OHOS::Ace::Platform::AcePlatformPlugin::GetNativeWindow(instanceId,textureId);
}

#pragma mark IAceSurface
- (uintptr_t)attachNaitveSurface:(CALayer *)layer {
    uintptr_t address = reinterpret_cast<uintptr_t>(layer);
    return address;
}

#pragma mark AcePlatformViewDelegate
- (void)registerBufferWithInstanceId:(int32_t)instanceId textureId:(int64_t)textureId
    texturePixelBuffer:(void*)texturePixelBuffer
{
    // register PixelBuffer address
    OHOS::Ace::Platform::AcePlatformPlugin::RegisterSurface(instanceId, textureId, texturePixelBuffer);
}

- (void)registerContextPtrWithInstanceId:(int32_t)instanceId textureId:(int64_t)textureId
    contextPtr:(void*)contextPtr
{
    OHOS::Ace::Platform::AcePlatformPlugin::RegisterSurface(instanceId, textureId, contextPtr);
}

- (void)unregisterBufferWithInstanceId:(int32_t)instanceId textureId:(int64_t)textureId
{
    OHOS::Ace::Platform::AcePlatformPlugin::UnregisterSurface(instanceId, textureId);
}

- (void)registerPlatformViewFactory:(NSObject<PlatformViewFactory> *)platformViewFactory
{
    if (_platformViewPlugin) {
        [_platformViewPlugin registerPlatformViewFactory:platformViewFactory];
    }
}

- (void)notifyOrientationDidChange
{
    if (_aceSurfacePlugin) {
        [_aceSurfacePlugin notifyOrientationDidChange];
    }
}

- (void)dealloc
{
    NSLog(@"AcePlatformPlugin dealloc");
    [super dealloc];
}
@end
