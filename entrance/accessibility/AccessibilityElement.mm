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

#import "AccessibilityElement.h"

#include "adapter/ios/osal/mock/accessibility_def.h"

#define ELEMENT_INDEX 0
#define ELEMENT_COUNT 0
#define ELEMENT_COUNT_DEFAULT 1

@interface AccessibilityElement ()
@property(nonatomic, strong) AccessibilityElementContainer* container;
- (bool)HasAction:(int32_t)action;
@end

@implementation AccessibilityElement

- (NSString*)accessibilityIdentifier
{
    return [NSString stringWithFormat:@"%lld", self.elementId];
}

- (id)accessibilityContainer
{
    if ((self.children != nil && self.children.count != ELEMENT_COUNT) || self.elementId == self.rootId) {
        if (self.container == nil) {
            self.container = [[AccessibilityElementContainer alloc] initWithAccessibilityElement:self];
        }
        return self.container;
    }

    if (self.parent != nil) {
        return self.parent.accessibilityContainer;
    }

    return nil;
}

- (UIAccessibilityTraits)accessibilityTraits
{
    UIAccessibilityTraits traits = UIAccessibilityTraitNone;
    if (self.componentType == nil) {
        return traits;
    }
    if ([self.componentType isEqualToString:@"Button"]) {
        traits |= UIAccessibilityTraitButton;
    } else if ([self.componentType isEqualToString:@"Text"]) {
        traits |= UIAccessibilityTraitStaticText;
    } else if ([self.componentType isEqualToString:@"TextInput"]) {
        traits |= UIAccessibilityTraitKeyboardKey;
    } else if ([self.componentType isEqualToString:@"Image"]) {
        traits |= UIAccessibilityTraitImage;
    } else if ([self.componentType isEqualToString:@"TabBar"]) {
        traits |= UIAccessibilityTraitTabBar;
    } else if ([self.componentType isEqualToString:@"Slider"]) {
        traits |= UIAccessibilityTraitAdjustable;
    }
    if (self.isScrollable) {
        traits |= UIAccessibilityTraitAllowsDirectInteraction;
    }
    return traits;
}

- (BOOL)isAccessibilityElement
{
    if (self.accessibilityLevel == nil) {
        return NO;
    }
    if (self.elementId == self.rootId || ![self.accessibilityLevel isEqualToString:@"yes"]) {
        return NO;
    }
    return self.isAccessibility;
}

- (BOOL)accessibilityActivate
{
    if (![self HasAction:static_cast<int32_t>(OHOS::Accessibility::ActionType::ACCESSIBILITY_ACTION_CLICK)] ||
        self.accessibilityDelegate_ == nil) {
        return NO;
    }
    if ([self.accessibilityDelegate_ respondsToSelector:@selector(accessibilityActivate:)]) {
        return [self.accessibilityDelegate_ accessibilityActivate:self.elementId];
    }
    return NO;
}

- (BOOL)accessibilityPerformEscape
{
    if (![self HasAction:static_cast<int32_t>(OHOS::Accessibility::ActionType::ACCESSIBILITY_ACTION_BACK)] ||
        self.accessibilityDelegate_ == nil) {
        return NO;
    }
    if ([self.accessibilityDelegate_ respondsToSelector:@selector(accessibilityPerformEscape:)]) {
        return [self.accessibilityDelegate_ accessibilityPerformEscape:self.elementId];
    }
    return NO;
}

- (void)accessibilityElementDidBecomeFocused
{
    if (self.accessibilityDelegate_ == nil) {
        return;
    }
    if ([self.accessibilityDelegate_ respondsToSelector:@selector(accessibilityElementDidBecomeFocused:)]) {
        [self.accessibilityDelegate_ accessibilityElementDidBecomeFocused:self.elementId];
    }
}

- (void)accessibilityElementDidLoseFocus
{
    if (self.accessibilityDelegate_ == nil) {
        return;
    }
    if ([self.accessibilityDelegate_ respondsToSelector:@selector(accessibilityElementDidLoseFocus:)]) {
        [self.accessibilityDelegate_ accessibilityElementDidLoseFocus:self.elementId];
    }
}

- (BOOL)accessibilityScroll:(UIAccessibilityScrollDirection)direction
{
    BOOL hasAction = NO;
    switch (direction) {
        case UIAccessibilityScrollDirectionLeft:
        case UIAccessibilityScrollDirectionUp:
            hasAction = [self
                HasAction:static_cast<int32_t>(OHOS::Accessibility::ActionType::ACCESSIBILITY_ACTION_SCROLL_BACKWARD)];
            break;
        case UIAccessibilityScrollDirectionRight:
        case UIAccessibilityScrollDirectionDown:
            hasAction = [self
                HasAction:static_cast<int32_t>(OHOS::Accessibility::ActionType::ACCESSIBILITY_ACTION_SCROLL_FORWARD)];
            break;
        default:
            break;
    }
    if (!hasAction) {
        return NO;
    }

    if (_isScrollable && self.accessibilityDelegate_ != nil) {
        if ([self.accessibilityDelegate_ respondsToSelector:@selector(accessibilityScroll:)]) {
            [self.accessibilityDelegate_ accessibilityScroll:direction elementId:self.elementId];
        }
        return YES;
    }

    return NO;
}

- (bool)HasAction:(int32_t)action
{
    return (self.actionType & action) ? true : false;
}
@end

@interface AccessibilityElementContainer ()
@property(nonatomic, weak) AccessibilityElement* elementObject;
@end

@implementation AccessibilityElementContainer

- (instancetype)initWithAccessibilityElement:(AccessibilityElement*)element
{
    self = [super initWithAccessibilityContainer:element.accessibilityDelegate_];
    if (self) {
        _elementObject = element;
    }
    return self;
}

- (NSInteger)accessibilityElementCount
{
    if (_elementObject.children == nil) {
        return ELEMENT_COUNT_DEFAULT;
    }
    return _elementObject.children.count + ELEMENT_COUNT_DEFAULT;
}

- (nullable id)accessibilityElementAtIndex:(NSInteger)index
{
    if (index < ELEMENT_INDEX || index >= [self accessibilityElementCount]) {
        return nil;
    }
    if (index == ELEMENT_INDEX) {
        return _elementObject;
    } else if (_elementObject.children != nil) {
        AccessibilityElement* object = [_elementObject.children objectAtIndex:index - ELEMENT_COUNT_DEFAULT];
        if (object.children.count > ELEMENT_COUNT) {
            return object.accessibilityContainer;
        }
        return object;
    }
    return nil;
}

- (NSInteger)indexOfAccessibilityElement:(id)element
{
    if (element == _elementObject) {
        return ELEMENT_INDEX;
    }

    for (size_t i = ELEMENT_INDEX; i < _elementObject.children.count; i++) {
        AccessibilityElement* child = _elementObject.children[i];
        if (child == element || [child accessibilityContainer] == element) {
            return i + ELEMENT_COUNT_DEFAULT;
        }
    }
    return NSNotFound;
}

- (BOOL)isAccessibilityElement
{
    return NO;
}

- (CGRect)accessibilityFrame
{
    return _elementObject.accessibilityFrame;
}

- (id)accessibilityContainer
{
    return (_elementObject.elementId == _elementObject.rootId) ? _elementObject.accessibilityDelegate_
                                                               : _elementObject.parent.accessibilityContainer;
}

- (BOOL)accessibilityScroll:(UIAccessibilityScrollDirection)direction
{
    return [_elementObject accessibilityScroll:direction];
}
@end
