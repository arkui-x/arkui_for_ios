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
#import "AceAccessibilityBridge.h"
#import "AccessibilityNodeInfo.h"
#import "AccessibilityWindowView.h"

#include "foundation/arkui/ace_engine/adapter/ios/entrance/virtual_rs_window.h"

std::shared_ptr<AccessibilityManagerImpl::InteractionOperation> callback = nil;

bool ExecuteActionOC(
    const int windowId, const std::shared_ptr<AccessibilityManagerImpl::InteractionOperation>& interactionOperation)
{
    std::shared_ptr<OHOS::Rosen::Window> window = OHOS::Rosen::Window::FindWindow(windowId);
    CHECK_NULL_RETURN(window, false);
    callback = interactionOperation;
    AccessibilityWindowView* windowView = window->GetWindowView();
    [windowView ExecuteAction:^(const int64_t elementId, const int32_t action, NSDictionary* actionDict) {
      std::map<std::string, std::string> arguments;
      NSArray* keys = [actionDict allKeys];
      for (id key in keys) {
          NSString* value = actionDict[key];
          arguments[[key UTF8String]] = [value UTF8String];
      }
      if (callback) {
          callback->ExecuteAction(elementId, action, arguments);
      }
    }];

    [windowView RequestUpdate:^(const int64_t elementId) {
      if (callback) {
          callback->RequestUpdate(elementId);
      }
    }];
    return true;
}

int32_t GetAccessibilityElementActionTypes(const OHOS::Accessibility::AccessibilityElementInfo& info)
{
    int32_t actionType = 0;
    for (OHOS::Accessibility::AccessibleAction action : info.GetActionList()) {
        actionType |= static_cast<int32_t>(action.GetActionType());
    }
    return actionType;
}

void updateNodeInfoWithElementId(NSMutableDictionary<NSString*, AccessibilityNodeInfo*>* dictNodeInfo, int windowId)
{
    std::shared_ptr<OHOS::Rosen::Window> window = OHOS::Rosen::Window::FindWindow(windowId);
    CHECK_NULL_VOID(window);
    AccessibilityWindowView* windowView = window->GetWindowView();
    for (AccessibilityNodeInfo* nodeInfo in dictNodeInfo.allValues) {
        [windowView UpdateAccessibilityNodesWithElementId:nodeInfo];
    }
}

AccessibilityNodeInfo* SetAccessibilityNodeInfo(
    OHOS::Accessibility::AccessibilityElementInfo info, std::shared_ptr<OHOS::Rosen::Window> window)
{
    AccessibilityNodeInfo* aiModel = [[AccessibilityNodeInfo alloc] init];
    CHECK_NULL_RETURN(window, aiModel);
    std::string accessibilityText = info.GetAccessibilityText();
    NSString* text = [NSString stringWithCString:accessibilityText.c_str() encoding:NSUTF8StringEncoding];
    text = [text stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (text.length == 0) {
        text = [NSString stringWithCString:info.GetContent().c_str() encoding:NSUTF8StringEncoding];
    }
    text = [text stringByReplacingOccurrencesOfString:@"." withString:@"点"];
    NSString* hint = [NSString stringWithCString:info.GetHint().c_str() encoding:NSUTF8StringEncoding];
    NSString* description = 
        [NSString stringWithCString:info.GetDescriptionInfo().c_str() encoding:NSUTF8StringEncoding];
    NSString* descriptionInfo = [NSString stringWithFormat:@"%@ %@", hint, description];
    descriptionInfo = [descriptionInfo stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSString* componentType = [NSString stringWithCString:info.GetComponentType().c_str()
                                                 encoding:NSUTF8StringEncoding];
    int32_t left = info.GetRectInScreen().GetLeftTopXScreenPostion();
    int32_t top = info.GetRectInScreen().GetLeftTopYScreenPostion();
    int32_t width =
        info.GetRectInScreen().GetRightBottomXScreenPostion() - info.GetRectInScreen().GetLeftTopXScreenPostion();
    int32_t height =
        info.GetRectInScreen().GetRightBottomYScreenPostion() - info.GetRectInScreen().GetLeftTopYScreenPostion();
    std::vector<int64_t> childIds = info.GetChildIds();
    NSMutableArray<NSString*>* childIdArray = [NSMutableArray arrayWithCapacity:childIds.size()];
    for (int64_t childId : childIds) {
        [childIdArray addObject:[NSString stringWithFormat:@"%lld", childId]];
    }
    const CGFloat scale = [UIScreen mainScreen].scale;

    aiModel.nodeLable = text;
    aiModel.componentType = componentType;
    aiModel.descriptionInfo = descriptionInfo;
    aiModel.nodeX = left / scale + window->GetRect().posX_;
    aiModel.nodeY = top / scale + window->GetRect().posY_;
    aiModel.nodeWidth = width / scale;
    aiModel.nodeHeight = height / scale;
    aiModel.parentId = info.GetParentNodeId();
    aiModel.pageId = info.GetPageId();
    aiModel.childIds = childIdArray;
    aiModel.elementId = info.GetAccessibilityId();
    aiModel.actionType = GetAccessibilityElementActionTypes(info);
    return aiModel;
}

AccessibilityNodeInfo* SetAccessibilityNodePermission(
    AccessibilityNodeInfo* aiModel, OHOS::Accessibility::AccessibilityElementInfo info)
{
    NSString* strAccessibilityLevel = [NSString stringWithFormat:@"%s", info.GetAccessibilityLevel().c_str()];

    aiModel.accessibilityLevel = strAccessibilityLevel;
    aiModel.enabled = info.IsEnabled();
    aiModel.visible = info.IsVisible();
    aiModel.focusable = info.IsFocusable();
    aiModel.focused = info.IsFocused();
    aiModel.isClickable = info.IsClickable();
    aiModel.isLongClickable = info.IsLongClickable();
    aiModel.isScrollable = info.IsScrollable();
    aiModel.hasAccessibilityFocus = info.HasAccessibilityFocus();
    return aiModel;
}

void UpdateNodesOC(
    const std::list<OHOS::Accessibility::AccessibilityElementInfo>& infos, const int windowId, const size_t eventType)
{
    std::shared_ptr<OHOS::Rosen::Window> window = OHOS::Rosen::Window::FindWindow(windowId);
    CHECK_NULL_VOID(window);
    AccessibilityWindowView* windowView = window->GetWindowView();
    NSMutableDictionary<NSString*, AccessibilityNodeInfo*>* dictNodeInfo = [[NSMutableDictionary alloc] init];
    for (auto info : infos) {
        AccessibilityNodeInfo* modelInfo = SetAccessibilityNodeInfo(info, window);
        AccessibilityNodeInfo* modelNode = SetAccessibilityNodePermission(modelInfo, info);
        NSString* key = [NSString stringWithFormat:@"%lld", modelNode.elementId];
        [dictNodeInfo setObject:modelNode forKey:key];
    }
    
    switch (eventType) {
        case static_cast<size_t>(OHOS::Ace::AccessibilityEventType::TEXT_CHANGE):
            updateNodeInfoWithElementId(dictNodeInfo, windowId);
            break;
        default:
            [windowView UpdateAccessibilityNodes:dictNodeInfo eventType:eventType];
            break;
    }
}

bool SubscribeState(
    const int windowId, const std::shared_ptr<AccessibilityManagerImpl::AccessibilityStateObserver>& stateObserver)
{
    std::shared_ptr<OHOS::Rosen::Window> window = OHOS::Rosen::Window::FindWindow(windowId);
    CHECK_NULL_RETURN(window, false);
    AccessibilityWindowView* windowView = window->GetWindowView();
    bool ret = [windowView SubscribeState:^(bool state) {
      if (stateObserver) {
          stateObserver->OnStateChanged(state);
      }
    }];
    return ret;
}

void UnSubscribeState(const int windowId)
{
    std::shared_ptr<OHOS::Rosen::Window> window = OHOS::Rosen::Window::FindWindow(windowId);
    CHECK_NULL_VOID(window);
    AccessibilityWindowView* windowView = window->GetWindowView();
    [windowView UnSubscribeState];
}

void SendAccessibilityEventOC(const int64_t elementId, const int windowId, const size_t eventType)
{
    std::shared_ptr<OHOS::Rosen::Window> window = OHOS::Rosen::Window::FindWindow(windowId);
    CHECK_NULL_VOID(window);
    AccessibilityWindowView* windowView = window->GetWindowView();
    [windowView SendAccessibilityEvent:elementId eventType:eventType];
}

void AnnounceForAccessibilityOC(const std::string& text)
{
    NSString* announceText = [NSString stringWithCString:text.c_str() encoding:NSUTF8StringEncoding];
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(200 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            NSDictionary *attributes = @{UIAccessibilitySpeechAttributeQueueAnnouncement: @(YES)};
            NSAttributedString *announcement =
                [[NSAttributedString alloc] initWithString:announceText attributes:attributes];
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, announcement);
        });
    });
}