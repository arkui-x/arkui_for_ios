/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACCESSIBILITY_ACCESSIBILITYNODEINFO_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACCESSIBILITY_ACCESSIBILITYNODEINFO_H

#import <Foundation/Foundation.h>

#import "AccessibilityElement.h"

@interface AccessibilityNodeInfo : NSObject

@property(nonatomic, strong) NSString* nodeLable;
@property(nonatomic, strong) NSString* descriptionInfo;
@property(nonatomic, strong) NSString* componentType;
@property(nonatomic, strong) NSString* accessibilityLevel;
@property(nonatomic, strong) NSMutableArray<NSString*>* childIds;
@property(nonatomic, strong) NSMutableDictionary<NSString*, AccessibilityElement*>* elements_;
@property(nonatomic, assign) float nodeX;
@property(nonatomic, assign) float nodeY;
@property(nonatomic, assign) float nodeWidth;
@property(nonatomic, assign) float nodeHeight;
@property(nonatomic, assign) int64_t parentId;
@property(nonatomic, assign) int32_t pageId;
@property(nonatomic, assign) int64_t elementId;
@property(nonatomic, assign) bool enabled;
@property(nonatomic, assign) bool visible;
@property(nonatomic, assign) bool focusable;
@property(nonatomic, assign) bool focused;
@property(nonatomic, assign) bool isClickable;
@property(nonatomic, assign) bool isLongClickable;
@property(nonatomic, assign) bool isScrollable;
@property(nonatomic, assign) bool hasAccessibilityFocus;
@property(nonatomic, assign) int32_t actionType;

@end
#endif // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACCESSIBILITY_ACCESSIBILITYNODEINFO_H
