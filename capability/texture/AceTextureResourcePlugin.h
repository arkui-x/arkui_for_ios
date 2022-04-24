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

#import <Foundation/Foundation.h>
#import "AceResourcePlugin.h"
#import "FlutterTexture.h"

NS_ASSUME_NONNULL_BEGIN

@interface AceTextureResourcePlugin : AceResourcePlugin

- (instancetype)initWithTextures:(NSObject<FlutterTextureRegistry> *)textures;

- (id)getObject:(NSString *)id;
- (int64_t)create:(NSDictionary <NSString *, NSString *> *)param;
- (BOOL)release:(NSString *)id;
- (void)releaseObject;
@end

NS_ASSUME_NONNULL_END
