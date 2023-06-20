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

#import "AceVideoResourcePlugin.h"
#import "AceSurfacePlugin.h"

#include "adapter/ios/entrance/ace_resource_register.h"
#include "adapter/ios/entrance/ace_platform_plugin.h"

#include "core/common/container_scope.h"

@interface AcePlatformPlugin()<IAceOnCallEvent>
@property (nonatomic, retain) AceResourceRegisterOC* resRegister;
@property (nonatomic, retain) AceVideoResourcePlugin* videoResourcePlugin;
@property (nonatomic, retain) AceSurfacePlugin* aceSurfacePlugin;

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

                _aceSurfacePlugin = [AceSurfacePlugin createRegister:target abilityInstanceId:instanceId];
                [self addResourcePlugin:_aceSurfacePlugin];
            }
        }
    }
    return self;
}

- (void)addResourcePlugin:(AceResourcePlugin *)plugin
{
    if(plugin){
        [_resRegister registerPlugin:plugin];
    }
}

- (void)releaseObject 
{
   [self performSelector:@selector(delayRelease) withObject:nil afterDelay:2.0f];
}

- (void)delayRelease
{
    if (_resRegister) {
        [_resRegister releaseObject];
        [_resRegister release];
    }
    if (_videoResourcePlugin){
        [_videoResourcePlugin release];
    }
     if (_aceSurfacePlugin){
        [_aceSurfacePlugin release];
    }
}

- (void)notifyLifecycleChanged:(BOOL)isBackground
{
    [_resRegister notifyLifecycleChanged:isBackground];
}

#pragma mark IAceOnCallEvent
- (void)onEvent:(NSString *)eventId param:(NSString *)param
{
    NSLog(@"IAceOnCallEvent OC call C++: %@ --- %@",eventId,param);
    auto resRegister = OHOS::Ace::Platform::AcePlatformPlugin::GetResRegister(self.instanceId);
    OHOS::Ace::ContainerScope scope(self.instanceId);
    resRegister->OnEvent([eventId UTF8String], [param UTF8String]);
}

- (void)dealloc
{
    NSLog(@"AcePlatformPlugin dealloc");
}
@end
