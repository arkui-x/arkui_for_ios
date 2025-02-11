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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACCESSIBILITY_ACCESSIBILITYELEMENT_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACCESSIBILITY_ACCESSIBILITYELEMENT_H

#import <UIKit/UIKit.h>

@protocol AccessibilityElementDelegate <NSObject>

@optional

- (BOOL)accessibilityActivate:(int64_t)elementId;
- (BOOL)accessibilityScroll:(UIAccessibilityScrollDirection)direction elementId:(int64_t)elementId;
- (BOOL)accessibilityPerformEscape:(int64_t)elementId;
- (void)accessibilityElementDidBecomeFocused:(int64_t)elementId;
- (void)accessibilityElementDidLoseFocus:(int64_t)elementId;

@end

@interface AccessibilityElement : UIAccessibilityElement

@property(nonatomic, weak) id<AccessibilityElementDelegate> accessibilityDelegate_;
@property(nonatomic, copy) NSMutableArray<AccessibilityElement*>* children;
@property(nonatomic, weak) AccessibilityElement* parent;
@property(nonatomic, strong) NSString* componentType;
@property(nonatomic, strong) NSString* accessibilityLevel;
@property(nonatomic, assign) int64_t rootId;
@property(nonatomic, assign) int64_t elementId;
@property(nonatomic, assign) bool isAccessibility;
@property(nonatomic, assign) bool isScrollable;
@property(nonatomic, assign) int32_t actionType;
@property(nonatomic, assign) int32_t pageId;

@end

@interface AccessibilityElementContainer : UIAccessibilityElement

- (instancetype)initWithAccessibilityContainer:(id)container NS_UNAVAILABLE;
- (instancetype)initWithAccessibilityElement:(AccessibilityElement*)element;

@end
#endif // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACCESSIBILITY_ACCESSIBILITYELEMENT_H
