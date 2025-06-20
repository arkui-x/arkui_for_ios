/*
 * Copyright (c) 2025-2025 Huawei Device Co., Ltd.
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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_STAGE_SECURE_CONTAINER_VIEW_H
#define FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_STAGE_SECURE_CONTAINER_VIEW_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface StageSecureContainerView : UITextField
// please user this function instead of addSubview
- (void)addView:(UIView *)window;
@end

NS_ASSUME_NONNULL_END
#endif // FOUNDATION_ACE_ADAPTER_IOS_STAGE_ABILITY_STAGE_SECURE_CONTAINER_VIEW_H
