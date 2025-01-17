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

#import <Foundation/Foundation.h>
#import "AccessibilityWindowView.h"

#include "adapter/ios/osal/mock/accessibility_element_info.h"
#include "core/accessibility/accessibility_utils.h"

typedef void (^executeActionMethod)(const int64_t elementId, const int32_t action, NSDictionary* actionDict);
typedef void (^requestUpdateMethod)(const int64_t elementId);
typedef void (^ScribeStateBlock)(bool state);
#define MIN_ELEMENT 0
#define ElEMENTID_DEFAULT -1
#define LEVEL_AUTO @"auto"
#define LEVEL_YES @"yes"
#define LEVEL_NO @"no"
#define LEVEL_NO_HIDE_DESCENDANTS @"no-hide-descendants"
#define COMPONENTTYPE_ROOT @"root"

@interface AccessibilityWindowView () <AccessibilityElementDelegate>

@property(nonatomic, copy) executeActionMethod executeActionCallBack;
@property(nonatomic, copy) requestUpdateMethod requestUpdateCallBack;
@property(nonatomic, copy) ScribeStateBlock scribeStateBlock;
@property(nonatomic, strong) NSMutableDictionary<NSString*, AccessibilityElement*>* isCreateElements;
@property(nonatomic) int64_t focusElementId;
@property(nonatomic) int64_t clearFocusElementId;

typedef enum {
    ACCESSIBILITY_SCROLL_DEFAULT,
    ACCESSIBILITY_SCROLL_UP,
    ACCESSIBILITY_SCROLL_DOWN,
    ACCESSIBILITY_SCROLL_UNKNOWN
} AccessibilityScrollActionType;

@end

@implementation AccessibilityWindowView

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.isCreateElements = [[NSMutableDictionary alloc] init];
        _focusElementId = ElEMENTID_DEFAULT;
        _clearFocusElementId = ElEMENTID_DEFAULT;
    }
    return self;
}

- (void)keyboardWillChangeFrame:(NSNotification*)notification
{
    [super keyboardWillChangeFrame:notification];
    if (self.requestUpdateCallBack) {
        self.requestUpdateCallBack(_focusElementId);
    }
}

- (void)keyboardWillBeHidden:(NSNotification*)notification
{
    [super keyboardWillBeHidden:notification];
    if (self.requestUpdateCallBack) {
        self.requestUpdateCallBack(_clearFocusElementId);
    }
}

- (float)getStatusBarAndNavigationBarHeight
{
    UIWindowScene* windowScene =
        (UIWindowScene*)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
    UIStatusBarManager* statusBarManager = windowScene.statusBarManager;
    CGFloat statusBarHeight = statusBarManager.statusBarFrame.size.height;
    UINavigationBar* navBar = [self getViewController].navigationController.navigationBar;
    if (navBar.hidden) {
        return statusBarHeight;
    }
    CGFloat navigationBarHeight = [self getViewController].navigationController.navigationBar.frame.size.height;
    return statusBarHeight + navigationBarHeight;
}

- (CGRect)getVisibleScreenRect
{
    CGRect visibleScreenRect =
        CGRectMake(0, [self getStatusBarAndNavigationBarHeight], self.bounds.size.width, self.bounds.size.height);
    return visibleScreenRect;
}

- (int)IsViewOffscreenTopOrBottom:(int64_t)elementId
{
    CGRect visibleScreenRect = [self getVisibleScreenRect];
    NSString* key = [NSString stringWithFormat:@"%lld", elementId];
    AccessibilityElement* object = [self.isCreateElements objectForKey:key];
    if (object == nil) {
        return ACCESSIBILITY_SCROLL_UNKNOWN;
    }
    if (CGRectGetMidY(object.accessibilityFrame) < CGRectGetMinY(visibleScreenRect)) {
        return ACCESSIBILITY_SCROLL_UP;
    }
    if (CGRectGetMidY(object.accessibilityFrame) > CGRectGetMaxY(visibleScreenRect)) {
        return ACCESSIBILITY_SCROLL_DOWN;
    }
    return ACCESSIBILITY_SCROLL_DEFAULT;
}

- (void)scrollToPage:(int64_t)elementId
{
    if (!self.executeActionCallBack) {
        return;
    }
    AccessibilityElement* scrollElement =
        [self.isCreateElements objectForKey:[NSString stringWithFormat:@"%lld", elementId]];
    while (scrollElement != nil && !scrollElement.isScrollable) {
        scrollElement = scrollElement.parent;
    }
    if (scrollElement != nil) {
        switch ([self IsViewOffscreenTopOrBottom:elementId]) {
            case ACCESSIBILITY_SCROLL_UP:
                self.executeActionCallBack(scrollElement.elementId,
                    OHOS::Accessibility::ActionType::ACCESSIBILITY_ACTION_SCROLL_BACKWARD, nil);
                break;
            case ACCESSIBILITY_SCROLL_DOWN:
                self.executeActionCallBack(
                    scrollElement.elementId, OHOS::Accessibility::ActionType::ACCESSIBILITY_ACTION_SCROLL_FORWARD, nil);
                break;
            default:
                break;
        }
    }
}

- (AccessibilityElement*)CreateObject:(AccessibilityNodeInfo*)node
{
    NSString* key = [NSString stringWithFormat:@"%lld", node.elementId];
    AccessibilityElement* element = [self.isCreateElements objectForKey:key];
    if (element == nil) {
        element = [[AccessibilityElement alloc] initWithAccessibilityContainer:self];
    }
    CGRect rect =
        CGRectMake(node.nodeX, node.nodeY + [self getStatusBarAndNavigationBarHeight], node.nodeWidth, node.nodeHeight);
    if ([node.componentType isEqualToString:COMPONENTTYPE_ROOT]) {
        element.rootId = node.elementId;
    }
    element.accessibilityDelegate_ = self;
    element.elementId = node.elementId;
    element.accessibilityFrame = rect;
    element.accessibilityLabel = node.nodeLable;
    element.accessibilityHint = node.descriptionInfo;
    element.accessibilityLevel = node.accessibilityLevel;
    element.componentType = node.componentType;
    element.isScrollable = node.isScrollable;
    element.actionType = node.actionType;
    [self.isCreateElements setObject:element forKey:key];

    return element;
}

- (BOOL)isAccessibilityEnabled:(AccessibilityNodeInfo*)node allNodeInfo:(NSMutableDictionary*)allNodeInfo
{
    if ([node.componentType isEqualToString:COMPONENTTYPE_ROOT]) {
        return NO;
    }
    if (!node.enabled || !node.visible) {
        return NO;
    }
    NSString* strElementId = [NSString stringWithFormat:@"%lld", node.parentId];
    AccessibilityNodeInfo* parentNode = [allNodeInfo objectForKey:strElementId];
    if (parentNode) {
        if ([node.componentType isEqualToString:@"Calendar"] && [parentNode.componentType isEqualToString:@"Swiper"]) {
            return NO;
        }
    }
    if (node.nodeWidth <= 0 || node.nodeHeight <= 0) {
        return NO;
    }
    if (node.isClickable || node.isLongClickable || node.nodeLable.length > 0 || node.descriptionInfo.length > 0) {
        return YES;
    }
    return NO;
}

- (void)setChildrenNodeInfo:(NSMutableDictionary*)dictNodeInfo
{
    int64_t minElementId = MIN_ELEMENT;
    for (NSString* key in dictNodeInfo) {
        AccessibilityNodeInfo* node = [dictNodeInfo objectForKey:key];
        if ([node.componentType isEqualToString:@"Column"]) {
            NSString* strElementId = [NSString stringWithFormat:@"%lld", node.parentId];
            AccessibilityNodeInfo* parentNode = [dictNodeInfo objectForKey:strElementId];
            if (parentNode && [parentNode.componentType isEqualToString:@"PatternLock"]) {
                node.nodeWidth = parentNode.nodeWidth;
                node.nodeHeight = parentNode.nodeHeight;
            }
        }
        if ([node.componentType isEqualToString:@"NavDestination"]) {
            minElementId = node.elementId;
        }
        AccessibilityElement* element = [self CreateObject:node];
        NSMutableArray* newChildren = [[NSMutableArray alloc] init];
        NSString* strLabel = @"";
        for (NSString* childId in node.childIds) {
            AccessibilityNodeInfo* childNode = [dictNodeInfo objectForKey:childId];
            AccessibilityElement* childElement = [self CreateObject:childNode];
            childElement.parent = element;
            [newChildren addObject:childElement];
            strLabel = [NSString stringWithFormat:@"%@%@", strLabel, childNode.nodeLable];
        }

        element.isAccessibility = [self isAccessibilityEnabled:node allNodeInfo:dictNodeInfo];
        if (node.nodeLable.length <= 0 && node.descriptionInfo.length <= 0) {
            node.nodeLable = strLabel;
        }
        element.children = [newChildren copy];
    }
    for (AccessibilityElement* element in self.isCreateElements.allValues) {
        element.accessibilityLevel = [self getAccessibilityLevel:element];
        if (element.elementId < minElementId) {
            element.isAccessibility = NO;
        }
    }
}

- (NSString*)getAccessibilityLevel:(AccessibilityElement*)element
{
    if ([element.accessibilityLevel isEqualToString:LEVEL_AUTO]) {
        return LEVEL_YES;
    } else if ([element.accessibilityLevel isEqualToString:LEVEL_NO_HIDE_DESCENDANTS]) {
        for (AccessibilityElement* childElement in element.children) {
            if (![element.accessibilityLevel isEqualToString:LEVEL_NO_HIDE_DESCENDANTS]) {
                childElement.accessibilityLevel = LEVEL_NO;
            }
        }
    }
    return element.accessibilityLevel;
}

- (void)UpdateAccessibilityNodes:(NSMutableDictionary*)dictNodeInfo eventType:(size_t)eventType
{
    [self.isCreateElements enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL* stop) {
      int elementId = [(NSString*)key intValue];
      AccessibilityElement* node = (AccessibilityElement*)obj;
      if (![node.componentType isEqualToString:COMPONENTTYPE_ROOT]) {
          [self.isCreateElements removeObjectForKey:(NSString*)key];
      }
    }];
    [self setChildrenNodeInfo:dictNodeInfo];
    for (NSString* key in self.isCreateElements) {
        AccessibilityElement* object = [self.isCreateElements objectForKey:key];
        if (object != nil && [object.componentType isEqualToString:COMPONENTTYPE_ROOT]) {
            self.accessibilityElements = @[ [object accessibilityContainer] ?: [NSNull null] ];
            break;
        }
    }
    NSString* defaultElementId = [NSString stringWithFormat:@"%lld", _focusElementId];
    AccessibilityElement* defaultObject = [self.isCreateElements objectForKey:defaultElementId];
    if (_focusElementId != ElEMENTID_DEFAULT && defaultObject != nil && defaultObject.isAccessibility &&
        [self IsViewOffscreenTopOrBottom:_focusElementId] == ACCESSIBILITY_SCROLL_DEFAULT) {
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, defaultObject);
        return;
    }
    defaultObject = nil;
    for (NSString* key in self.isCreateElements) {
        AccessibilityElement* object = [self.isCreateElements objectForKey:key];
        if (object != nil && [self IsViewOffscreenTopOrBottom:object.elementId] == ACCESSIBILITY_SCROLL_DEFAULT &&
            object.isAccessibility) {
            if (defaultObject == nil ||
                CGRectGetMidY(object.accessibilityFrame) < CGRectGetMinY(defaultObject.accessibilityFrame)) {
                defaultObject = object;
            }
        }
    }
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, defaultObject);
}

- (void)ExecuteAction:(void (^)(const int64_t elementId, const int32_t action, NSDictionary* actionDic))callback
{
    self.executeActionCallBack = callback;
}

- (void)RequestUpdate:(void (^)(const int64_t elementId))callback
{
    self.requestUpdateCallBack = callback;
}

- (bool)SubscribeState:(void (^)(bool state))block
{
    if (block) {
        self.scribeStateBlock = block;
    }
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    if (@available(iOS 11.0, *)) {
        [center addObserver:self
                   selector:@selector(voiceOverStatusChanged:)
                       name:UIAccessibilityVoiceOverStatusDidChangeNotification
                     object:nil];
    } else {
        [center addObserver:self
                   selector:@selector(voiceOverStatusChanged:)
                       name:UIAccessibilityVoiceOverStatusChanged
                     object:nil];
    }
    return UIAccessibilityIsVoiceOverRunning();
}

- (void)UnSubscribeState
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setFocus:(int64_t)elementId
{
    NSString* key = [NSString stringWithFormat:@"%lld", elementId];
    AccessibilityElement* object = [self.isCreateElements objectForKey:key];
    if (object == nil) {
        return;
    }
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, object);
}

- (void)SendAccessibilityEvent:(int64_t)elementId eventType:(size_t)eventType
{
    switch (eventType) {
        case static_cast<size_t>(OHOS::Ace::AccessibilityEventType::FOCUS):
            [self setFocus:elementId];
            break;
        default:
            break;
    }
}

- (BOOL)isAccessibilityElement
{
    return NO;
}

- (void)voiceOverStatusChanged:(NSNotification*)notification
{
    if (self.scribeStateBlock) {
        bool state = UIAccessibilityIsVoiceOverRunning();
        self.scribeStateBlock(state);
    }
}

- (BOOL)accessibilityScroll:(UIAccessibilityScrollDirection)direction elementId:(int64_t)elementId
{
    if (!self.executeActionCallBack) {
        return NO;
    }
    switch (direction) {
        case UIAccessibilityScrollDirectionLeft:
        case UIAccessibilityScrollDirectionUp:
            self.executeActionCallBack(
                elementId, OHOS::Accessibility::ActionType::ACCESSIBILITY_ACTION_SCROLL_BACKWARD, nil);
            break;
        case UIAccessibilityScrollDirectionRight:
        case UIAccessibilityScrollDirectionDown:
            self.executeActionCallBack(
                elementId, OHOS::Accessibility::ActionType::ACCESSIBILITY_ACTION_SCROLL_FORWARD, nil);
            break;
        case UIAccessibilityScrollDirectionNext:
            break;
        case UIAccessibilityScrollDirectionPrevious:
            break;
        default:
            break;
    }
    return NO;
}

- (BOOL)accessibilityActivate:(int64_t)elementId
{
    if (self.executeActionCallBack) {
        self.executeActionCallBack(elementId, OHOS::Accessibility::ActionType::ACCESSIBILITY_ACTION_CLICK, nil);
    }
    return YES;
}

- (BOOL)accessibilityPerformEscape:(int64_t)elementId
{
    if (self.executeActionCallBack) {
        self.executeActionCallBack(elementId, OHOS::Accessibility::ActionType::ACCESSIBILITY_ACTION_BACK, nil);
    }
    return YES;
}

- (void)accessibilityElementDidBecomeFocused:(int64_t)elementId
{
    if (!self.executeActionCallBack) {
        return;
    }
    _focusElementId = elementId;
    if (_clearFocusElementId != ElEMENTID_DEFAULT && _clearFocusElementId != elementId) {
        self.executeActionCallBack(
            _clearFocusElementId, OHOS::Accessibility::ActionType::ACCESSIBILITY_ACTION_CLEAR_ACCESSIBILITY_FOCUS, nil);
        _clearFocusElementId = ElEMENTID_DEFAULT;
    }
    self.executeActionCallBack(
        elementId, OHOS::Accessibility::ActionType::ACCESSIBILITY_ACTION_ACCESSIBILITY_FOCUS, nil);
    [self scrollToPage:elementId];
}

- (void)accessibilityElementDidLoseFocus:(int64_t)elementId
{
    _clearFocusElementId = elementId;
}

- (void)UpdateAccessibilityNodesWithElementId:(AccessibilityNodeInfo*)nodeInfo
{
    NSString* key = [NSString stringWithFormat:@"%lld", nodeInfo.elementId];
    AccessibilityElement* element = [self.isCreateElements objectForKey:key];
    if (element) {
        CGRect rect = CGRectMake(nodeInfo.nodeX, nodeInfo.nodeY + [self getStatusBarAndNavigationBarHeight],
            nodeInfo.nodeWidth, nodeInfo.nodeHeight);
        element.accessibilityFrame = rect;
        element.accessibilityLabel = nodeInfo.nodeLable;
        element.accessibilityHint = nodeInfo.descriptionInfo;
        element.componentType = nodeInfo.componentType;
        element.isScrollable = nodeInfo.isScrollable;
        element.actionType = nodeInfo.actionType;
    }
}
@end
