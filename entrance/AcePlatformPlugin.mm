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

#import "AceCameraResoucePlugin.h"
#import "AceVideoResourcePlugin.h"

#include "adapter/ios/entrance/ace_resource_register.h"
#include "adapter/ios/entrance/ace_plaform_plugin.h"
@interface AcePlatformPlugin()

@property (nonatomic, strong) AceCameraResoucePlugin* cameraResourcePlugin;
@property (nonatomic, strong) AceVideoResourcePlugin* videoResourcePlugin;
@property (nonatomic, strong) AceResourceRegisterOC* resRegister;
@end
@implementation AcePlatformPlugin

- (instancetype)initPlatformPlugin:(id)target
    instanceId:(int32_t)instanceId bundleDirectory:(NSString *_Nonnull)bundleDir
{
    self = [super init];
    if (self) {
        if(target){
            _resRegister = [[AceResourceRegisterOC alloc] initWithParent:target];
            auto aceResRegister =
                OHOS::Ace::Referenced::MakeRefPtr<OHOS::Ace::Platform::AceResourceRegister>(_resRegister);
            OHOS::Ace::Platform::AcePlatformPlugin::InitResRegister(instanceId,aceResRegister);
   
            if(bundleDir && bundleDir.length != 0){
                _videoResourcePlugin = [[AceVideoResourcePlugin alloc] initWithBundleDirectory:bundleDir];
                [self addResourcePlugin:_videoResourcePlugin];
            }
            _cameraResourcePlugin = [[AceCameraResoucePlugin alloc] init];
            [self addResourcePlugin:_cameraResourcePlugin];
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
    [_resRegister releaseObject];
}

- (void)releasePlugins 
{
}

@end
