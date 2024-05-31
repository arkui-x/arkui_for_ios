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
#ifndef FOUNDATION_ADAPTER_CAPABILITY_TEXTURE_ACETEXTUREDELEGATE_H
#define FOUNDATION_ADAPTER_CAPABILITY_TEXTURE_ACETEXTUREDELEGATE_H

#import <Foundation/Foundation.h>

@protocol AceTextureDelegate <NSObject>

- (void)registerSurfaceWithInstanceId:(int32_t)instanceId textureId:(int64_t)textureId
    textureObject:(void*)textureObject;

- (void)unregisterSurfaceWithInstanceId:(int32_t)instanceId textureId:(int64_t)textureId;

- (void*)getNativeWindowWithInstanceId:(int32_t)instanceId textureId:(int64_t)textureId;

@end

#endif // FOUNDATION_ADAPTER_CAPABILITY_TEXTURE_ACETEXTURE_H
