/*
 * Copyright (c) 2023-2025 Huawei Device Co., Ltd.
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

#include "adapter/ios/osal/accessibility_manager_impl.h"

#include <algorithm>
#include <variant>

#include "adapter/ios/entrance/accessibility/AceAccessibilityBridge.h"

using namespace OHOS::Accessibility;
using namespace std;

namespace OHOS::Ace::Framework {

constexpr int32_t INVALID_PARENT_ID = -2100000;
constexpr int32_t ELEMENT_MOVE_BIT = 40;
constexpr int32_t CONT_SPLIT_ID = -1;
constexpr int64_t MAX_ELEMENT_ID = 0xFFFFFFFFFF;
constexpr int32_t ROOT_DECOR_BASE = 3100000;
constexpr int32_t ROOT_STACK_BASE = 1100000;
constexpr int32_t CARD_NODE_ID_RATION = 10000;
constexpr int32_t CARD_ROOT_NODE_ID_RATION = 1000;
constexpr int32_t CARD_BASE = 100000;
constexpr int32_t DELAY_SEND_EVENT_MILLISECOND = 20;
constexpr int MAX_TIME = 500;
const char STRING_DIR_FORWARD[] = "forward";
const char STRING_DIR_BACKWARD[] = "backward";
const char ACCESSIBILITY_FOCUSED_EVENT[] = "accessibilityfocus";
const char ACCESSIBILITY_CLEAR_FOCUS_EVENT[] = "accessibilityclearfocus";
const char SCROLL_END_EVENT[] = "scrollend";
const char SIDEBARCONTAINER_TAG[] = "SideBarContainer";
const char LIST_TAG[] = "List";

const std::string ACTION_ARGU_SCROLL_STUB = "scrolltype";

struct ActionTable {
    AceAction aceAction;
    ActionType action;
};

AccessibilityManagerImpl::~AccessibilityManagerImpl()
{
    UnSubscribeStateObserver();
    DeregisterInteractionOperation();
}

struct AccessibilityActionParam {
    RefPtr<NG::AccessibilityProperty> accessibilityProperty;
    std::string setTextArgument = "";
    int32_t setSelectionStart = DEFAULT_SELECTION;
    int32_t setSelectionEnd = DEFAULT_SELECTION;
    bool setSelectionDir = false;
    int32_t setCursorIndex = DEFAULT_ElEMENTID;
    TextMoveUnit moveUnit = TextMoveUnit::STEP_CHARACTER;
    AccessibilityScrollType scrollType = AccessibilityScrollType::SCROLL_DEFAULT;
};

const std::map<Accessibility::ActionType, std::function<bool(const AccessibilityActionParam& param)>> ACTIONS = {
    { ActionType::ACCESSIBILITY_ACTION_SCROLL_FORWARD,
        [](const AccessibilityActionParam& param) {
            return param.accessibilityProperty->ActActionScrollForward(param.scrollType);
        } },
    { ActionType::ACCESSIBILITY_ACTION_SCROLL_BACKWARD,
        [](const AccessibilityActionParam& param) {
            return param.accessibilityProperty->ActActionScrollBackward(param.scrollType);
        } },
    { ActionType::ACCESSIBILITY_ACTION_SET_TEXT,
        [](const AccessibilityActionParam& param) {
            return param.accessibilityProperty->ActActionSetText(param.setTextArgument);
        } },
    { ActionType::ACCESSIBILITY_ACTION_SET_SELECTION,
        [](const AccessibilityActionParam& param) {
            return param.accessibilityProperty->ActActionSetSelection(
                param.setSelectionStart, param.setSelectionEnd, param.setSelectionDir);
        } },
    { ActionType::ACCESSIBILITY_ACTION_COPY,
        [](const AccessibilityActionParam& param) { return param.accessibilityProperty->ActActionCopy(); } },
    { ActionType::ACCESSIBILITY_ACTION_CUT,
        [](const AccessibilityActionParam& param) { return param.accessibilityProperty->ActActionCut(); } },
    { ActionType::ACCESSIBILITY_ACTION_PASTE,
        [](const AccessibilityActionParam& param) { return param.accessibilityProperty->ActActionPaste(); } },
    { ActionType::ACCESSIBILITY_ACTION_CLICK,
        [](const AccessibilityActionParam& param) { return param.accessibilityProperty->ActActionClick(); } },
    { ActionType::ACCESSIBILITY_ACTION_LONG_CLICK,
        [](const AccessibilityActionParam& param) { return param.accessibilityProperty->ActActionLongClick(); } },
    { ActionType::ACCESSIBILITY_ACTION_SELECT,
        [](const AccessibilityActionParam& param) { return param.accessibilityProperty->ActActionSelect(); } },
    { ActionType::ACCESSIBILITY_ACTION_CLEAR_SELECTION,
        [](const AccessibilityActionParam& param) { return param.accessibilityProperty->ActActionClearSelection(); } },
    { ActionType::ACCESSIBILITY_ACTION_NEXT_TEXT,
        [](const AccessibilityActionParam& param) {
            return param.accessibilityProperty->ActActionMoveText(static_cast<int32_t>(param.moveUnit), true);
        } },
    { ActionType::ACCESSIBILITY_ACTION_PREVIOUS_TEXT,
        [](const AccessibilityActionParam& param) {
            return param.accessibilityProperty->ActActionMoveText(static_cast<int32_t>(param.moveUnit), false);
        } },
    { ActionType::ACCESSIBILITY_ACTION_SET_CURSOR_POSITION,
        [](const AccessibilityActionParam& param) {
            return param.accessibilityProperty->ActActionSetIndex(static_cast<int32_t>(param.setCursorIndex));
        } },
};

RefPtr<AccessibilityNodeManager> AccessibilityNodeManager::Create()
{
    return AceType::MakeRefPtr<AccessibilityManagerImpl>();
}

RefPtr<NG::FrameNode> GetInspectorById(const RefPtr<NG::FrameNode>& root, int32_t id)
{
    CHECK_NULL_RETURN(root, nullptr);
    std::queue<RefPtr<NG::UINode>> nodes;
    nodes.push(root);
    RefPtr<NG::FrameNode> frameNode;
    while (!nodes.empty()) {
        auto current = nodes.front();
        nodes.pop();
        frameNode = AceType::DynamicCast<NG::FrameNode>(current);
        if (frameNode != nullptr) {
            if (id == frameNode->GetAccessibilityId()) {
                return frameNode;
            }
        }
        const auto& children = current->GetChildren();
        for (const auto& child : children) {
            nodes.push(child);
        }
    }
    return nullptr;
}

void GetFrameNodeChildren(const RefPtr<NG::UINode>& uiNode, std::vector<int32_t>& children, int32_t pageId)
{
    auto frameNode = AceType::DynamicCast<NG::FrameNode>(uiNode);
    if (frameNode != nullptr) {
        if (!frameNode->IsFirstVirtualNode()) {
            CHECK_NULL_VOID(frameNode->IsActive());
        }
        if (uiNode->GetTag() == "stage") {
        } else if (uiNode->GetTag() == "page") {
            if (uiNode->GetPageId() != pageId) {
                return;
            }
        } else if (!frameNode->IsInternal() || frameNode->IsFirstVirtualNode()) {
            children.emplace_back(uiNode->GetAccessibilityId());
            return;
        }

        auto accessibilityProperty = frameNode->GetAccessibilityProperty<NG::AccessibilityProperty>();
        CHECK_NULL_VOID(accessibilityProperty);
        auto uiVirtualNode = accessibilityProperty->GetAccessibilityVirtualNode();
        if (uiVirtualNode != nullptr) {
            auto virtualNode = AceType::DynamicCast<NG::FrameNode>(uiVirtualNode);
            if (virtualNode != nullptr) {
                GetFrameNodeChildren(virtualNode, children, pageId);
                return;
            }
        }
    }

    for (const auto& frameChild : uiNode->GetChildren(true)) {
        GetFrameNodeChildren(frameChild, children, pageId);
    }
}

void DumpTreeNG(const RefPtr<NG::FrameNode>& parent, int32_t depth, NodeId nodeID, int32_t pageId)
{
    auto node = GetInspectorById(parent, nodeID);
    if (!node) {
        DumpLog::GetInstance().Print("Error: failed to get accessibility node with ID " + std::to_string(nodeID));
        return;
    }

    if (!node->IsActive()) {
        return;
    }

    NG::RectF rect = node->GetTransformRectRelativeToWindow();
    DumpLog::GetInstance().AddDesc("ID: " + std::to_string(node->GetAccessibilityId()));
    DumpLog::GetInstance().AddDesc("compid: " + node->GetInspectorId().value_or(""));
    DumpLog::GetInstance().AddDesc("text: " + node->GetAccessibilityProperty<NG::AccessibilityProperty>()->GetText());
    DumpLog::GetInstance().AddDesc("top: " + std::to_string(rect.Top()));
    DumpLog::GetInstance().AddDesc("left: " + std::to_string(rect.Left()));
    DumpLog::GetInstance().AddDesc("width: " + std::to_string(rect.Width()));
    DumpLog::GetInstance().AddDesc("height: " + std::to_string(rect.Height()));
    DumpLog::GetInstance().AddDesc("visible: " + std::to_string(node->IsVisible()));
    auto gestureEventHub = node->GetEventHub<NG::EventHub>()->GetGestureEventHub();
    DumpLog::GetInstance().AddDesc(
        "clickable: " + std::to_string(gestureEventHub ? gestureEventHub->IsAccessibilityClickable() : false));
    DumpLog::GetInstance().AddDesc(
        "checkable: " + std::to_string(node->GetAccessibilityProperty<NG::AccessibilityProperty>()->IsCheckable()));

    std::vector<int32_t> children;
    for (const auto& item : node->GetChildren()) {
        GetFrameNodeChildren(item, children, pageId);
    }
    DumpLog::GetInstance().Print(depth, node->GetTag(), children.size());

    for (auto nodeId : children) {
        DumpTreeNG(node, depth + 1, nodeId, pageId);
    }
}

int64_t GetParentId(const RefPtr<NG::UINode>& uiNode)
{
    if (AceType::InstanceOf<NG::FrameNode>(uiNode)) {
        if (AceType::DynamicCast<NG::FrameNode>(uiNode)->IsFirstVirtualNode()) {
            auto weakNode = AceType::DynamicCast<NG::FrameNode>(uiNode)->GetVirtualNodeParent();
            auto refNode = weakNode.Upgrade();
            return refNode == nullptr ? INVALID_PARENT_ID : refNode->GetAccessibilityId();
        }
    }
    auto parent = uiNode->GetParent();
    while (parent) {
        if (AceType::InstanceOf<NG::FrameNode>(parent)) {
            if ((parent->GetTag() == V2::PAGE_ETS_TAG) || (parent->GetTag() == V2::STAGE_ETS_TAG) ||
                AceType::DynamicCast<NG::FrameNode>(parent)->CheckAccessibilityLevelNo()) {
                parent = parent->GetParent();
                continue;
            }
            return parent->GetAccessibilityId();
        }
        parent = parent->GetParent();
    }
    return INVALID_PARENT_ID;
}

int64_t ConvertToCardAccessibilityId(int64_t nodeId, int64_t cardId, int64_t rootNodeId)
{
    int64_t result = DEFAULT_ID;
    if (nodeId == rootNodeId + ROOT_STACK_BASE) {
        result = cardId * CARD_BASE + (static_cast<int64_t>(nodeId / CARD_BASE)) * CARD_ROOT_NODE_ID_RATION +
                 nodeId % CARD_BASE;
    } else {
        result = cardId * CARD_BASE + (static_cast<int64_t>(nodeId / DOM_ROOT_NODE_ID_BASE)) * CARD_NODE_ID_RATION +
                 nodeId % DOM_ROOT_NODE_ID_BASE;
    }
    return result;
}

inline std::string ChildernToString(const RefPtr<NG::FrameNode>& frameNode, int32_t pageId)
{
    std::string ids;
    std::vector<int32_t> children;
    for (const auto& item : frameNode->GetChildren()) {
        GetFrameNodeChildren(item, children, pageId);
    }
    for (auto child : children) {
        if (!ids.empty()) {
            ids.append(",");
        }
        ids.append(std::to_string(child));
    }
    return ids;
}

inline std::string BoolToString(bool tag)
{
    return tag ? "true" : "false";
}

inline bool IsPopupSupported(const RefPtr<NG::FrameNode>& frameNode, const RefPtr<NG::PipelineContext>& pipeline)
{
    CHECK_NULL_RETURN(pipeline, false);
    auto overlayManager = pipeline->GetOverlayManager();
    if (overlayManager) {
        return overlayManager->HasPopupInfo(frameNode->GetId());
    }
    return false;
}

inline bool IsPopupSupported(const RefPtr<NG::PipelineContext>& pipeline, int64_t nodeId)
{
    CHECK_NULL_RETURN(pipeline, false);
    auto overlayManager = pipeline->GetOverlayManager();
    if (overlayManager) {
        return overlayManager->HasPopupInfo(nodeId);
    }
    return false;
}

bool FindFrameNodeByAccessibilityId(int64_t id, const std::list<RefPtr<NG::UINode>>& children,
    std::queue<NG::UINode*>& nodes, RefPtr<NG::FrameNode>& result)
{
    NG::FrameNode* frameNode = nullptr;
    for (const auto& child : children) {
        frameNode = AceType::DynamicCast<NG::FrameNode>(Referenced::RawPtr(child));
        if (frameNode != nullptr && !frameNode->CheckAccessibilityLevelNo()) {
            if (frameNode->GetAccessibilityId() == id) {
                result = AceType::DynamicCast<NG::FrameNode>(child);
                return true;
            }
        }
        nodes.push(Referenced::RawPtr(child));
    }
    return false;
}

RefPtr<NG::FrameNode> GetFramenodeByAccessibilityId(const RefPtr<NG::FrameNode>& root, int64_t id)
{
    CHECK_NULL_RETURN(root, nullptr);
    if (root->GetAccessibilityId() == id) {
        return root;
    }

    std::queue<NG::UINode*> nodes;
    nodes.push(Referenced::RawPtr(root));
    NG::UINode* virtualNode = nullptr;
    RefPtr<NG::FrameNode> frameNodeResult = nullptr;

    while (!nodes.empty()) {
        auto current = nodes.front();
        nodes.pop();
        if (current->HasVirtualNodeAccessibilityProperty()) {
            auto fnode = AceType::DynamicCast<NG::FrameNode>(current);
            auto property = fnode->GetAccessibilityProperty<NG::AccessibilityProperty>();
            const auto& children = std::list<RefPtr<NG::UINode>> { property->GetAccessibilityVirtualNode() };
            if (FindFrameNodeByAccessibilityId(id, children, nodes, frameNodeResult)) {
                return frameNodeResult;
            }
        } else {
            const auto& children = current->GetChildren(true);
            if (FindFrameNodeByAccessibilityId(id, children, nodes, frameNodeResult)) {
                return frameNodeResult;
            }
        }
    }
    return nullptr;
}

inline std::string ConvertInputTypeToString(int32_t inputType)
{
    static std::vector<std::string> sInputTypes { "default", "text", "email", "date", "time", "number", "password" };
    if (inputType < 0 || inputType >= static_cast<int32_t>(sInputTypes.size())) {
        return "none";
    }
    return sInputTypes[inputType];
}

// execute action
bool RequestFocus(RefPtr<NG::FrameNode>& frameNode)
{
    auto focusHub = frameNode->GetFocusHub();
    CHECK_NULL_RETURN(focusHub, false);
    return focusHub->RequestFocusImmediately();
}

bool LostFocus(const RefPtr<NG::FrameNode>& frameNode)
{
    CHECK_NULL_RETURN(frameNode, false);
    auto focusHub = frameNode->GetFocusHub();
    CHECK_NULL_RETURN(focusHub, false);
    focusHub->LostFocus();
    return true;
}

bool ActClick(RefPtr<NG::FrameNode>& frameNode)
{
    auto gesture = frameNode->GetEventHub<NG::EventHub>()->GetGestureEventHub();
    CHECK_NULL_RETURN(gesture, false);
    return gesture->ActClick();
}

bool ActLongClick(RefPtr<NG::FrameNode>& frameNode)
{
    auto gesture = frameNode->GetEventHub<NG::EventHub>()->GetGestureEventHub();
    CHECK_NULL_RETURN(gesture, false);
    return gesture->ActLongClick();
}

void ClearAccessibilityFocus(const RefPtr<NG::FrameNode>& root, int64_t focusNodeId)
{
    auto oldFocusNode = GetFramenodeByAccessibilityId(root, focusNodeId);
    CHECK_NULL_VOID(oldFocusNode);
    if (oldFocusNode->GetTag() != V2::WEB_CORE_TAG) {
        oldFocusNode->GetRenderContext()->UpdateAccessibilityFocus(false);
    }
}

bool ActAccessibilityFocus(int64_t elementId, RefPtr<NG::FrameNode>& frameNode, RefPtr<NG::PipelineContext>& context,
    int64_t& currentFocusNodeId, bool isNeedClear)
{
    CHECK_NULL_RETURN(frameNode, false);
    if (isNeedClear) {
        if (elementId != currentFocusNodeId) {
            return false;
        }
        currentFocusNodeId = DEFAULT_ElEMENTID;
        return true;
    }
    if (elementId == currentFocusNodeId) {
        return false;
    }
    Framework::ClearAccessibilityFocus(context->GetRootElement(), currentFocusNodeId);
    currentFocusNodeId = frameNode->GetAccessibilityId();
    auto accessibilityProperty = frameNode->GetAccessibilityProperty<NG::AccessibilityProperty>();
    CHECK_NULL_RETURN(accessibilityProperty, false);
    accessibilityProperty->OnAccessibilityFocusCallback(true);
    return true;
}

void stringToLower(std::string& str)
{
    std::transform(str.begin(), str.end(), str.begin(), [](char& c) { return std::tolower(c); });
}

bool conversionDirection(std::string dir)
{
    stringToLower(dir);
    return dir.compare(STRING_DIR_FORWARD) == DEFAULT_ID ? true : false;
}

static std::string ConvertActionTypeToString(AceAction action)
{
    switch (action) {
        case AceAction::ACTION_NONE:
            return "none";
        case AceAction::GLOBAL_ACTION_BACK:
            return "back";
        case AceAction::CUSTOM_ACTION:
            return "custom action";
        case AceAction::ACTION_CLICK:
            return "click";
        case AceAction::ACTION_LONG_CLICK:
            return "long click";
        case AceAction::ACTION_SCROLL_FORWARD:
            return "scroll forward";
        case AceAction::ACTION_SCROLL_BACKWARD:
            return "scroll backward";
        case AceAction::ACTION_FOCUS:
            return "focus";
        default:
            return "not support";
    }
}

static void DumpCommonPropertyNG(
    const RefPtr<NG::FrameNode>& frameNode, const RefPtr<PipelineBase>& pipeline, int32_t pageId)
{
    CHECK_NULL_VOID(frameNode);
    auto gestureEventHub = frameNode->GetEventHub<NG::EventHub>()->GetGestureEventHub();
    DumpLog::GetInstance().AddDesc("ID: ", frameNode->GetAccessibilityId());
    DumpLog::GetInstance().AddDesc("parent ID: ", GetParentId(frameNode));
    DumpLog::GetInstance().AddDesc("child IDs: ", ChildernToString(frameNode, pageId));
    DumpLog::GetInstance().AddDesc("component type: ", frameNode->GetTag());
    DumpLog::GetInstance().AddDesc(
        "enabled: ", BoolToString(frameNode->GetFocusHub() ? frameNode->GetFocusHub()->IsEnabled() : true));
    DumpLog::GetInstance().AddDesc(
        "focusable: ", BoolToString(frameNode->GetFocusHub() ? frameNode->GetFocusHub()->IsFocusable() : false));
    DumpLog::GetInstance().AddDesc(
        "focused: ", BoolToString(frameNode->GetFocusHub() ? frameNode->GetFocusHub()->IsCurrentFocus() : false));
    DumpLog::GetInstance().AddDesc("visible: ", BoolToString(frameNode->IsVisible()));
    if (frameNode->IsVisible()) {
        NG::RectF rect;
        if (frameNode->IsActive()) {
            rect = frameNode->GetTransformRectRelativeToWindow();
        }
        DumpLog::GetInstance().AddDesc("rect: ", rect.ToString());
    }
    DumpLog::GetInstance().AddDesc("inspector key: ", frameNode->GetInspectorId().value_or(""));
    DumpLog::GetInstance().AddDesc("bundle name: ", AceApplicationInfo::GetInstance().GetPackageName());
    DumpLog::GetInstance().AddDesc("page id: " + std::to_string(pageId));
    DumpLog::GetInstance().AddDesc(
        "clickable: ", BoolToString(gestureEventHub ? gestureEventHub->IsAccessibilityClickable() : false));
    DumpLog::GetInstance().AddDesc(
        "long clickable: ", BoolToString(gestureEventHub ? gestureEventHub->IsAccessibilityLongClickable() : false));
    DumpLog::GetInstance().AddDesc("popup supported: ",
        BoolToString(IsPopupSupported(frameNode, AceType::DynamicCast<NG::PipelineContext>(pipeline))));
}

static void DumpAccessibilityPropertyNG(const RefPtr<NG::FrameNode>& frameNode)
{
    CHECK_NULL_VOID(frameNode);
    auto accessibilityProperty = frameNode->GetAccessibilityProperty<NG::AccessibilityProperty>();
    CHECK_NULL_VOID(accessibilityProperty);
    DumpLog::GetInstance().AddDesc("text: ", accessibilityProperty->GetText());
    DumpLog::GetInstance().AddDesc("checked: ", BoolToString(accessibilityProperty->IsChecked()));
    DumpLog::GetInstance().AddDesc("selected: ", BoolToString(accessibilityProperty->IsSelected()));
    DumpLog::GetInstance().AddDesc("checkable: ", BoolToString(accessibilityProperty->IsCheckable()));
    DumpLog::GetInstance().AddDesc("scrollable: ", BoolToString(accessibilityProperty->IsScrollable()));
    DumpLog::GetInstance().AddDesc("accessibility hint: ", BoolToString(accessibilityProperty->IsHint()));
    DumpLog::GetInstance().AddDesc("hint text: ", accessibilityProperty->GetHintText());
    DumpLog::GetInstance().AddDesc("error text: ", accessibilityProperty->GetErrorText());
    DumpLog::GetInstance().AddDesc("max text length: ", accessibilityProperty->GetTextLengthLimit());
    DumpLog::GetInstance().AddDesc("text selection start: ", accessibilityProperty->GetTextSelectionStart());
    DumpLog::GetInstance().AddDesc("text selection end: ", accessibilityProperty->GetTextSelectionEnd());
    DumpLog::GetInstance().AddDesc("is multi line: ", BoolToString(accessibilityProperty->IsMultiLine()));
    DumpLog::GetInstance().AddDesc("is password: ", BoolToString(accessibilityProperty->IsPassword()));
    DumpLog::GetInstance().AddDesc(
        "text input type: ", ConvertInputTypeToString(static_cast<int32_t>(accessibilityProperty->GetTextInputType())));
    DumpLog::GetInstance().AddDesc("min value: ", accessibilityProperty->GetAccessibilityValue().min);
    DumpLog::GetInstance().AddDesc("max value: ", accessibilityProperty->GetAccessibilityValue().max);
    DumpLog::GetInstance().AddDesc("current value: ", accessibilityProperty->GetAccessibilityValue().current);
    DumpLog::GetInstance().AddDesc("gird info rows: ", accessibilityProperty->GetCollectionInfo().rows);
    DumpLog::GetInstance().AddDesc("gird info columns: ", accessibilityProperty->GetCollectionInfo().columns);
    DumpLog::GetInstance().AddDesc("gird info select mode: ", accessibilityProperty->GetCollectionInfo().selectMode);
    DumpLog::GetInstance().AddDesc("gird item info, row: ", accessibilityProperty->GetCollectionItemInfo().row);
    DumpLog::GetInstance().AddDesc("gird item info, column: ", accessibilityProperty->GetCollectionItemInfo().column);
    DumpLog::GetInstance().AddDesc("gird item info, rowSpan: ", accessibilityProperty->GetCollectionItemInfo().rowSpan);
    DumpLog::GetInstance().AddDesc(
        "gird item info, columnSpan: ", accessibilityProperty->GetCollectionItemInfo().columnSpan);
    DumpLog::GetInstance().AddDesc(
        "gird item info, is heading: ", accessibilityProperty->GetCollectionItemInfo().heading);
    DumpLog::GetInstance().AddDesc("gird item info, selected: ", BoolToString(accessibilityProperty->IsSelected()));
    DumpLog::GetInstance().AddDesc("current index: ", accessibilityProperty->GetCurrentIndex());
    DumpLog::GetInstance().AddDesc("begin index: ", accessibilityProperty->GetBeginIndex());
    DumpLog::GetInstance().AddDesc("end index: ", accessibilityProperty->GetEndIndex());
    DumpLog::GetInstance().AddDesc("collection item counts: ", accessibilityProperty->GetCollectionItemCounts());
    DumpLog::GetInstance().AddDesc("editable: ", BoolToString(accessibilityProperty->IsEditable()));
    DumpLog::GetInstance().AddDesc("deletable: ", accessibilityProperty->IsDeletable());
    DumpLog::GetInstance().AddDesc("content invalid: ", BoolToString(accessibilityProperty->GetContentInvalid()));

    std::string actionForDump;
    accessibilityProperty->ResetSupportAction();
    auto gestureEventHub = frameNode->GetEventHub<NG::EventHub>()->GetGestureEventHub();
    if (gestureEventHub) {
        if (gestureEventHub->IsAccessibilityClickable()) {
            accessibilityProperty->AddSupportAction(AceAction::ACTION_CLICK);
        }
        if (gestureEventHub->IsAccessibilityLongClickable()) {
            accessibilityProperty->AddSupportAction(AceAction::ACTION_LONG_CLICK);
        }
    }
    if (frameNode->GetFocusHub() ? frameNode->GetFocusHub()->IsFocusable() : false) {
        if (frameNode->GetFocusHub() ? frameNode->GetFocusHub()->IsCurrentFocus() : false) {
            accessibilityProperty->AddSupportAction(AceAction::ACTION_CLEAR_FOCUS);
        } else {
            accessibilityProperty->AddSupportAction(AceAction::ACTION_FOCUS);
        }
    }
    auto supportAceActions = accessibilityProperty->GetSupportAction();
    for (auto item : supportAceActions) {
        if (!actionForDump.empty()) {
            actionForDump.append(",");
        }
        actionForDump.append(ConvertActionTypeToString(item));
        actionForDump.append(": ");
        actionForDump.append(std::to_string(static_cast<int32_t>(item)));
    }
    DumpLog::GetInstance().AddDesc("support action: ", actionForDump);
}

void AccessibilityManagerImpl::DumpTree(int32_t depth, int64_t nodeID, bool isDumpSimplify)
{
    DumpLog::GetInstance().Print("Dump Accessiability Tree:");
    auto pipeline = context_.Upgrade();
    CHECK_NULL_VOID(pipeline);
    auto ngPipeline = AceType::DynamicCast<NG::PipelineContext>(pipeline);
    auto rootNode = ngPipeline->GetRootElement();
    CHECK_NULL_VOID(rootNode);
    nodeID = rootNode->GetAccessibilityId();
    auto stageManager = ngPipeline->GetStageManager();
    CHECK_NULL_VOID(stageManager);
    auto page = stageManager->GetLastPage();
    CHECK_NULL_VOID(page);
    auto pageId = page->GetPageId();
    DumpTreeNG(rootNode, depth, nodeID, pageId);
}

ActionType ConvertAceAction(AceAction aceAction)
{
    static const ActionTable actionTable[] = {
        { AceAction::ACTION_CLICK, ActionType::ACCESSIBILITY_ACTION_CLICK },
        { AceAction::ACTION_LONG_CLICK, ActionType::ACCESSIBILITY_ACTION_LONG_CLICK },
        { AceAction::ACTION_SCROLL_FORWARD, ActionType::ACCESSIBILITY_ACTION_SCROLL_FORWARD },
        { AceAction::ACTION_SCROLL_BACKWARD, ActionType::ACCESSIBILITY_ACTION_SCROLL_BACKWARD },
        { AceAction::ACTION_FOCUS, ActionType::ACCESSIBILITY_ACTION_FOCUS },
        { AceAction::ACTION_CLEAR_FOCUS, ActionType::ACCESSIBILITY_ACTION_CLEAR_FOCUS },
        { AceAction::ACTION_ACCESSIBILITY_FOCUS, ActionType::ACCESSIBILITY_ACTION_ACCESSIBILITY_FOCUS },
        { AceAction::ACTION_CLEAR_ACCESSIBILITY_FOCUS, ActionType::ACCESSIBILITY_ACTION_CLEAR_ACCESSIBILITY_FOCUS },
        { AceAction::ACTION_NEXT_AT_MOVEMENT_GRANULARITY, ActionType::ACCESSIBILITY_ACTION_NEXT_TEXT },
        { AceAction::ACTION_PREVIOUS_AT_MOVEMENT_GRANULARITY, ActionType::ACCESSIBILITY_ACTION_PREVIOUS_TEXT },
        { AceAction::ACTION_SET_TEXT, ActionType::ACCESSIBILITY_ACTION_SET_TEXT },
        { AceAction::ACTION_COPY, ActionType::ACCESSIBILITY_ACTION_COPY },
        { AceAction::ACTION_PASTE, ActionType::ACCESSIBILITY_ACTION_PASTE },
        { AceAction::ACTION_CUT, ActionType::ACCESSIBILITY_ACTION_CUT },
        { AceAction::ACTION_SELECT, ActionType::ACCESSIBILITY_ACTION_SELECT },
        { AceAction::ACTION_CLEAR_SELECTION, ActionType::ACCESSIBILITY_ACTION_CLEAR_SELECTION },
        { AceAction::ACTION_SET_SELECTION, ActionType::ACCESSIBILITY_ACTION_SET_SELECTION },
        { AceAction::ACTION_SET_CURSOR_POSITION, ActionType::ACCESSIBILITY_ACTION_SET_CURSOR_POSITION },
    };
    for (const auto& item : actionTable) {
        if (aceAction == item.aceAction) {
            return item.action;
        }
    }
    return ActionType::ACCESSIBILITY_ACTION_INVALID;
}

static void GetChildFromNode(const RefPtr<NG::UINode>& uiNode, std::vector<int32_t>& children, int32_t pageId,
    OHOS::Ace::Platform::ComponentInfo& parentComponent)
{
    if (AceType::InstanceOf<NG::FrameNode>(uiNode)) {
        if (uiNode->GetTag() == "stage") {
        } else if (uiNode->GetTag() == "page") {
            if (uiNode->GetPageId() != pageId) {
                return;
            }
        } else {
            auto frameNode = AceType::DynamicCast<NG::FrameNode>(uiNode);
            CHECK_NULL_VOID(frameNode);
            if (!frameNode->IsInternal()) {
                children.emplace_back(uiNode->GetAccessibilityId());
                parentComponent.children.emplace_back();
                return;
            }
        }
    }

    for (const auto& frameChild : uiNode->GetChildren()) {
        GetChildFromNode(frameChild, children, pageId, parentComponent);
    }
}
static OHOS::Ace::Platform::ComponentInfo SetComponentInfo(const RefPtr<NG::FrameNode>& node)
{
    OHOS::Ace::Platform::ComponentInfo componentInfo;
    NG::RectF rect = node->GetTransformRectRelativeToWindow();
    componentInfo.compid = node->GetInspectorId().value_or("");
    componentInfo.text = node->GetAccessibilityProperty<NG::AccessibilityProperty>()->GetText();
    componentInfo.top = rect.Top();
    componentInfo.width = rect.Width();
    componentInfo.left = rect.Left();
    componentInfo.height = rect.Height();
    auto gestureEventHub = node->GetEventHub<NG::EventHub>()->GetGestureEventHub();
    componentInfo.clickable = gestureEventHub ? gestureEventHub->IsAccessibilityClickable() : false;
    auto accessibilityProperty = node->GetAccessibilityProperty<NG::AccessibilityProperty>();
    componentInfo.checked = accessibilityProperty->IsChecked();
    componentInfo.selected = accessibilityProperty->IsSelected();
    componentInfo.checkable = accessibilityProperty->IsCheckable();
    componentInfo.scrollable = accessibilityProperty->IsScrollable();
    componentInfo.enabled = node->GetFocusHub() ? node->GetFocusHub()->IsEnabled() : true;
    componentInfo.focused = node->GetFocusHub() ? node->GetFocusHub()->IsCurrentFocus() : false;
    componentInfo.longClickable = gestureEventHub ? gestureEventHub->IsAccessibilityLongClickable() : false;
    componentInfo.type = node->GetTag();
    return componentInfo;
}

void GetComponents(OHOS::Ace::Platform::ComponentInfo& parentComponent, const RefPtr<NG::FrameNode>& parent,
    NodeId nodeID, int32_t pageId)
{
    auto node = GetInspectorById(parent, nodeID);
    if (!node) {
        return;
    }
    if (!node->IsActive()) {
        return;
    }
    parentComponent = SetComponentInfo(node);

    std::vector<int32_t> children;
    for (const auto& item : node->GetChildren()) {
        GetChildFromNode(item, children, pageId, parentComponent);
    }
    for (int index = DEFAULT_ID; index < children.size(); index++) {
        GetComponents(parentComponent.children[index], node, children[index], pageId);
    }
}

bool AccessibilityManagerImpl::GetAllComponents(NodeId nodeID, OHOS::Ace::Platform::ComponentInfo& rootComponent)
{
    auto pipeline = context_.Upgrade();
    CHECK_NULL_RETURN(pipeline, false);
    auto ngPipeline = AceType::DynamicCast<NG::PipelineContext>(pipeline);
    auto rootNode = ngPipeline->GetRootElement();
    CHECK_NULL_RETURN(rootNode, false);
    nodeID = rootNode->GetAccessibilityId();
    auto stageManager = ngPipeline->GetStageManager();
    CHECK_NULL_RETURN(stageManager, false);
    auto page = stageManager->GetLastPage();
    CHECK_NULL_RETURN(page, false);
    auto pageId = page->GetPageId();
    GetComponents(rootComponent, rootNode, nodeID, pageId);
    return true;
}

void AccessibilityManagerImpl::DumpProperty(const std::vector<std::string>& params)
{
    DumpLog::GetInstance().Print("Dump Accessiability Property:");
    auto pipeline = context_.Upgrade();
    CHECK_NULL_VOID(pipeline);

    RefPtr<NG::FrameNode> frameNode;
    auto nodeID = StringUtils::StringToInt(params[1]);
    auto ngPipeline = FindPipelineByElementId(nodeID, frameNode);
    CHECK_NULL_VOID(ngPipeline);
    CHECK_NULL_VOID(frameNode);

    int32_t pageId = DEFAULT_ID;
    if (ngPipeline->GetWindowId() == pipeline->GetWindowId()) {
        auto stageManager = ngPipeline->GetStageManager();
        CHECK_NULL_VOID(stageManager);
        auto page = stageManager->GetLastPage();
        CHECK_NULL_VOID(page);
        pageId = page->GetPageId();
    }

    DumpCommonPropertyNG(frameNode, pipeline, pageId);

    DumpAccessibilityPropertyNG(frameNode);
    DumpLog::GetInstance().Print(0, frameNode->GetTag(), frameNode->GetChildren().size());
}

void AccessibilityManagerImpl::DumpHandleEvent(const std::vector<std::string>& params)
{
    DumpLog::GetInstance().Print("Dump Accessiability Execute Action");
    auto pipeline = context_.Upgrade();
    CHECK_NULL_VOID(pipeline);
    int32_t nodeId = StringUtils::StringToInt(params[EVENT_DUMP_ID_INDEX]);
    auto action = static_cast<AceAction>(StringUtils::StringToInt(params[EVENT_DUMP_ACTION_INDEX]));

    if (AceType::InstanceOf<NG::PipelineContext>(pipeline)) {
        RefPtr<NG::FrameNode> node;
        pipeline = FindPipelineByElementId(nodeId, node);
        CHECK_NULL_VOID(pipeline);
        CHECK_NULL_VOID(node);
        pipeline->GetTaskExecutor()->PostTask(
            [weak = WeakClaim(this), action, nodeId, pipeline]() {
                auto accessibilityManager = weak.Upgrade();
                CHECK_NULL_VOID(accessibilityManager);
                accessibilityManager->ExecuteActionNG(nodeId, action, pipeline);
            },
            TaskExecutor::TaskType::UI, "ArkUI-XAccessibilityManagerImplDumpHandleEvent");
        return;
    }
}

bool AccessibilityManagerImpl::ExecuteActionNG(int32_t elementId, AceAction action, const RefPtr<PipelineBase>& context)
{
    bool result = false;
    auto ngPipeline = AceType::DynamicCast<NG::PipelineContext>(context);
    CHECK_NULL_RETURN(ngPipeline, result);
    ContainerScope instance(ngPipeline->GetInstanceId());
    auto frameNode = GetInspectorById(ngPipeline->GetRootElement(), elementId);
    CHECK_NULL_RETURN(frameNode, result);

    switch (action) {
        case AceAction::ACTION_FOCUS: {
            result = RequestFocus(frameNode);
            break;
        }
        case AceAction::ACTION_CLICK: {
            result = ActClick(frameNode);
            break;
        }
        case AceAction::ACTION_LONG_CLICK: {
            result = ActLongClick(frameNode);
            break;
        }
        case AceAction::ACTION_SCROLL_BACKWARD:
        case AceAction::ACTION_SCROLL_FORWARD:
            return true;
        default:
            break;
    }

    return result;
}

RefPtr<NG::FrameNode> AccessibilityManagerImpl::FindNodeFromPipeline(
    const WeakPtr<PipelineBase>& context, const int32_t elementId)
{
    auto pipeline = context.Upgrade();
    CHECK_NULL_RETURN(pipeline, nullptr);

    auto ngPipeline = AceType::DynamicCast<NG::PipelineContext>(pipeline);
    auto rootNode = ngPipeline->GetRootElement();
    CHECK_NULL_RETURN(rootNode, nullptr);

    NodeId nodeId = elementId;
    if (elementId == DEFAULT_ElEMENTID) {
        nodeId = rootNode->GetAccessibilityId();
    }

    RefPtr<NG::FrameNode> node = GetInspectorById(rootNode, nodeId);
    if (node) {
        return node;
    }
    return nullptr;
}

RefPtr<NG::PipelineContext> AccessibilityManagerImpl::FindPipelineByElementId(
    const int32_t elementId, RefPtr<NG::FrameNode>& node)
{
    node = FindNodeFromPipeline(context_, elementId);
    if (node) {
        auto context = AceType::DynamicCast<NG::PipelineContext>(context_.Upgrade());
        return context;
    }
    for (auto subContext : GetSubPipelineContexts()) {
        node = FindNodeFromPipeline(subContext, elementId);
        if (node) {
            auto context = AceType::DynamicCast<NG::PipelineContext>(subContext.Upgrade());
            return context;
        }
    }
    return nullptr;
}

bool AccessibilityManagerImpl::ExecuteActionNG(int64_t elementId,
    const std::map<std::string, std::string>& actionArguments, ActionType action, const RefPtr<PipelineBase>& context,
    int64_t uiExtensionOffset)
{
    bool result = false;
    auto ngPipeline = AceType::DynamicCast<NG::PipelineContext>(context);
    CHECK_NULL_RETURN(ngPipeline, result);

    ContainerScope instance(ngPipeline->GetInstanceId());
    auto frameNode = GetFramenodeByAccessibilityId(ngPipeline->GetRootElement(), elementId);

    if (!frameNode && elementId == lastElementId_) {
        frameNode = lastFrameNode_.Upgrade();
    }
    CHECK_NULL_RETURN(frameNode, result);

    auto enabled = frameNode->GetFocusHub() ? frameNode->GetFocusHub()->IsEnabled() : true;
    if (!enabled && action != ActionType::ACCESSIBILITY_ACTION_ACCESSIBILITY_FOCUS &&
        action != ActionType::ACCESSIBILITY_ACTION_CLEAR_ACCESSIBILITY_FOCUS) {
        return result;
    }
    result = ConvertActionTypeToBoolen(action, frameNode, elementId, ngPipeline);
    if (!result) {
        auto accessibilityProperty = frameNode->GetAccessibilityProperty<NG::AccessibilityProperty>();
        CHECK_NULL_RETURN(accessibilityProperty, false);
        result = ActAccessibilityAction(action, actionArguments, accessibilityProperty);
    }
    return result;
}

inline RangeInfo ConvertAccessibilityValue(const AccessibilityValue& value)
{
    return RangeInfo(value.min, value.max, value.current);
}

void GetTreeIdAndElementIdBySplitElementId(const int64_t elementId, int64_t& splitElementId, int32_t& splitTreeId)
{
    if (elementId <= CONT_SPLIT_ID) {
        splitTreeId = CONT_SPLIT_ID;
        splitElementId = CONT_SPLIT_ID;
        return;
    }
    splitTreeId = (static_cast<uint64_t>(elementId) >> ELEMENT_MOVE_BIT);
    splitElementId = MAX_ELEMENT_ID & elementId;
}

bool IsExtensionComponent(const RefPtr<NG::UINode>& node)
{
    return node &&
           (node->GetTag() == V2::UI_EXTENSION_COMPONENT_ETS_TAG || node->GetTag() == V2::EMBEDDED_COMPONENT_ETS_TAG ||
               node->GetTag() == V2::ISOLATED_COMPONENT_ETS_TAG);
}

bool IsUIExtensionShowPlaceholder(const RefPtr<NG::UINode>& node)
{
    CHECK_NULL_RETURN(node, true);
    if (node->GetTag() == V2::ISOLATED_COMPONENT_ETS_TAG) {
        return false;
    }
#ifdef WINDOW_SCENE_SUPPORTED
    auto pipeline = node->GetContextRefPtr();
    CHECK_NULL_RETURN(pipeline, true);
    auto manager = pipeline->GetUIExtensionManager();
    CHECK_NULL_RETURN(manager, true);
    return manager->IsShowPlaceholder(node->GetId());
#endif
    return true;
}

void AccessibilityManagerImpl::InitializeCallback()
{
    if (IsRegister()) {
        return;
    }

    auto pipelineContext = GetPipelineContext().Upgrade();
    CHECK_NULL_VOID(pipelineContext);
    windowId_ = pipelineContext->GetWindowId();
    bool isEnabled = false;
    auto container = Container::Current();
    if (!container) {
        LOGE("container is null");
        return;
    }
    auto executor = container->GetTaskExecutor();
    RefPtr<Environment> environment = Platform::EnvironmentProxyImpl::GetInstance()->GetEnvironment(executor);
    if (environment) {
        std::string val = environment->GetAccessibilityEnabled();
        if (val == "true") {
            isEnabled = true;
        }
    }
    AceApplicationInfo::GetInstance().SetAccessibilityEnabled(isEnabled);
    if (pipelineContext->IsFormRender() || pipelineContext->IsJsCard() || pipelineContext->IsJsPlugin()) {
        return;
    }

    SubscribeStateObserver();
    if (isEnabled) {
        RegisterInteractionOperation(windowId_);
    }
}

void SetAccessibilityFocusAction(AccessibilityElementInfo& nodeInfo, const char* tag)
{
    if (nodeInfo.HasAccessibilityFocus()) {
        AccessibleAction action(ACCESSIBILITY_ACTION_CLEAR_ACCESSIBILITY_FOCUS, tag);
        nodeInfo.AddAction(action);
    } else {
        AccessibleAction action(ACCESSIBILITY_ACTION_ACCESSIBILITY_FOCUS, tag);
        nodeInfo.AddAction(action);
    }
}

void UpdateSupportAction(const RefPtr<NG::FrameNode>& node, AccessibilityElementInfo& nodeInfo)
{
    CHECK_NULL_VOID(node);
    if (nodeInfo.IsFocusable()) {
        if (nodeInfo.IsFocused()) {
            AccessibleAction action(ACCESSIBILITY_ACTION_CLEAR_FOCUS, "ace");
            nodeInfo.AddAction(action);
        } else {
            AccessibleAction action(ACCESSIBILITY_ACTION_FOCUS, "ace");
            nodeInfo.AddAction(action);
        }
    }

    auto eventHub = node->GetEventHub<NG::EventHub>();
    CHECK_NULL_VOID(eventHub);
    auto gestureEventHub = eventHub->GetGestureEventHub();
    CHECK_NULL_VOID(gestureEventHub);
    nodeInfo.SetClickable(gestureEventHub->IsAccessibilityClickable());
    if (gestureEventHub->IsAccessibilityClickable()) {
        AccessibleAction action(ACCESSIBILITY_ACTION_CLICK, "ace");
        nodeInfo.AddAction(action);
    }
    nodeInfo.SetLongClickable(gestureEventHub->IsAccessibilityLongClickable());
    if (gestureEventHub->IsAccessibilityLongClickable()) {
        AccessibleAction action(ACCESSIBILITY_ACTION_LONG_CLICK, "ace");
        nodeInfo.AddAction(action);
    }
}

void UpdateChildrenOfAccessibilityElementInfo(
    const RefPtr<NG::FrameNode>& node, const CommonProperty& commonProperty, AccessibilityElementInfo& nodeInfo)
{
    if (!IsExtensionComponent(node) || IsUIExtensionShowPlaceholder(node)) {
        std::vector<int32_t> children;
        for (const auto& item : node->GetChildren(true)) {
            GetFrameNodeChildren(item, children, commonProperty.pageId);
        }
        auto accessibilityProperty = node->GetAccessibilityProperty<NG::AccessibilityProperty>();
        auto uiVirtualNode = accessibilityProperty->GetAccessibilityVirtualNode();
        if (uiVirtualNode != nullptr) {
            auto virtualNode = AceType::DynamicCast<NG::FrameNode>(uiVirtualNode);
            if (virtualNode != nullptr) {
                children.clear();
                GetFrameNodeChildren(virtualNode, children, commonProperty.pageId);
            }
        }
        for (const auto& child : children) {
            nodeInfo.AddChild(child);
        }
    }
}

bool AccessibilityManagerImpl::SubscribeStateObserver()
{
    if (!stateObserver_) {
        stateObserver_ = std::make_shared<AccessibilityStateObserver>();
    }
    stateObserver_->SetAccessibilityManager(WeakClaim(this));
    stateObserver_->SetPipeline(context_);
    return SubscribeState(windowId_, stateObserver_);
}

void AccessibilityManagerImpl::UnSubscribeStateObserver()
{
    UnSubscribeState(windowId_);
}

void AccessibilityManagerImpl::AccessibilityStateObserver::OnStateChanged(const bool state)
{
    auto pipelineRef = pipeline_.Upgrade();
    CHECK_NULL_VOID(pipelineRef);
    pipelineRef->GetTaskExecutor()->PostTask(
        [weak = accessibilityManager_, state]() {
            auto jsAccessibilityManager = weak.Upgrade();
            CHECK_NULL_VOID(jsAccessibilityManager);
            if (state) {
                jsAccessibilityManager->RegisterInteractionOperation(jsAccessibilityManager->GetWindowId());
                jsAccessibilityManager->UpdateElementInfosByAccessibilityId(DEFAULT_ElEMENTID,
                    jsAccessibilityManager->GetWindowId(), static_cast<size_t>(AccessibilityEventType::PAGE_CHANGE));
            } else {
                jsAccessibilityManager->DeregisterInteractionOperation();
            }
            AceApplicationInfo::GetInstance().SetAccessibilityEnabled(state);
        },
        TaskExecutor::TaskType::UI, "ArkUIAccessibilityStateChanged");
}

void AccessibilityManagerImpl::RegisterInteractionOperation(int windowId)
{
    if (IsRegister()) {
        return;
    }
    auto interactionOperation = std::make_shared<InteractionOperation>(windowId);
    interactionOperation->SetHandler(WeakClaim(this));
    bool retReg = ExecuteActionOC(windowId, interactionOperation);
    RefPtr<PipelineBase> context;
    for (auto subContext : GetSubPipelineContexts()) {
        context = subContext.Upgrade();
        CHECK_NULL_VOID(context);
        interactionOperation = std::make_shared<InteractionOperation>(context->GetWindowId());
        interactionOperation->SetHandler(WeakClaim(this));
        retReg = ExecuteActionOC(context->GetWindowId(), interactionOperation);
    }
    Register(retReg);
}

void AccessibilityManagerImpl::DeregisterInteractionOperation() {}

void AccessibilityManagerImpl::ProcessAccessibilityEvent(
    const AccessibilityEvent& accessibilityEvent, bool needAsync, size_t eventType)
{
    RefPtr<NG::FrameNode> node;
    RefPtr<NG::PipelineContext> ngPipeline = FindPipelineByElementId(accessibilityEvent.nodeId, node);
    CHECK_NULL_VOID(ngPipeline);
    CHECK_NULL_VOID(node);
    windowId_ = ngPipeline->GetWindowId();
    int64_t elementId = DEFAULT_ElEMENTID;
    if (eventType == static_cast<size_t>(OHOS::Ace::AccessibilityEventType::TEXT_CHANGE)) {
        elementId = accessibilityEvent.nodeId;
    }
    UpdateElementInfos(elementId, node, needAsync, eventType);
}

void AccessibilityManagerImpl::UpdateElementInfos(
    const int64_t elementId, RefPtr<NG::FrameNode> node, bool needAsync, size_t eventType)
{
    int64_t splitElementId = AccessibilityElementInfo::UNDEFINED_ACCESSIBILITY_ID;
    int32_t splitTreeId = AccessibilityElementInfo::UNDEFINED_TREE_ID;
    GetTreeIdAndElementIdBySplitElementId(elementId, splitElementId, splitTreeId);
    auto context = GetPipelineContext().Upgrade();
    CHECK_NULL_VOID(context);
    auto windowId = context->GetWindowId();

    if (!needAsync) {
        UpdateElementInfosByAccessibilityId(splitElementId, windowId, eventType);
        return;
    }

    context->GetTaskExecutor()->PostDelayedTask(
        [weak = WeakClaim(this), splitElementId, windowId, node, eventType]() {
            auto accessibilityManager = weak.Upgrade();
            CHECK_NULL_VOID(accessibilityManager);
            CHECK_NULL_VOID(node);
            while (!node->IsLayoutComplete()) {
                std::this_thread::yield();
            }
            accessibilityManager->UpdateElementInfosByAccessibilityId(splitElementId, windowId, eventType);
        },
        TaskExecutor::TaskType::UI, MAX_TIME, "ArkUIAccessibilitySearchElementInfoById");
}

void AccessibilityManagerImpl::SendAccessibilityAsyncEvent(const AccessibilityEvent& accessibilityEvent)
{
    switch (accessibilityEvent.type) {
        case AccessibilityEventType::PAGE_OPEN:
        case AccessibilityEventType::PAGE_CLOSE:
        case AccessibilityEventType::CHANGE:
        case AccessibilityEventType::PAGE_CHANGE:
        case AccessibilityEventType::ELEMENT_INFO_CHANGE:
        case AccessibilityEventType::TEXT_CHANGE:
        case AccessibilityEventType::COMPONENT_CHANGE:
        case AccessibilityEventType::SCROLL_END:
            ProcessAccessibilityEvent(accessibilityEvent, true, static_cast<size_t>(accessibilityEvent.type));
            break;
        case AccessibilityEventType::REQUEST_FOCUS:
            SendAccessibilityEventOC(accessibilityEvent.nodeId, static_cast<int>(accessibilityEvent.windowId),
                static_cast<size_t>(accessibilityEvent.type));
            break;
        case AccessibilityEventType::FOCUS:
            SendAccessibilityEventOC(
                accessibilityEvent.nodeId, static_cast<int>(windowId_), static_cast<size_t>(accessibilityEvent.type));
            break;
        case AccessibilityEventType::ANNOUNCE_FOR_ACCESSIBILITY:
            AnnounceForAccessibilityOC(accessibilityEvent.textAnnouncedForAccessibility);
            break;
        default:
            break;
    }
}

void ConvertExtensionAccessibilityId(AccessibilityElementInfo& info, const RefPtr<NG::FrameNode>& extensionNode,
    int64_t uiExtensionOffset, AccessibilityElementInfo& parentInfo)
{
    CHECK_NULL_VOID(extensionNode);
    auto extensionAbilityId = extensionNode->WrapExtensionAbilityId(uiExtensionOffset, info.GetAccessibilityId());
    info.SetAccessibilityId(extensionAbilityId);
    auto parentNodeId = extensionNode->WrapExtensionAbilityId(uiExtensionOffset, info.GetParentNodeId());
    info.SetParent(parentNodeId);
    auto childIds = info.GetChildIds();
    for (auto& child : childIds) {
        info.RemoveChild(child);
        info.AddChild(extensionNode->WrapExtensionAbilityId(uiExtensionOffset, child));
    }
    if (info.GetComponentType() == V2::ROOT_ETS_TAG) {
        for (auto& child : info.GetChildIds()) {
            parentInfo.AddChild(child);
        }
    }
}

void ConvertExtensionAccessibilityNodeId(std::list<AccessibilityElementInfo>& infos,
    const RefPtr<NG::FrameNode>& extensionNode, int64_t uiExtensionOffset, AccessibilityElementInfo& parentInfo)
{
    CHECK_NULL_VOID(extensionNode);
    for (auto& accessibilityElementInfo : infos) {
        ConvertExtensionAccessibilityId(accessibilityElementInfo, extensionNode, uiExtensionOffset, parentInfo);
    }
    for (auto& accessibilityElementInfo : infos) {
        if (std::find(parentInfo.GetChildIds().begin(), parentInfo.GetChildIds().end(),
                accessibilityElementInfo.GetAccessibilityId()) != parentInfo.GetChildIds().end()) {
            accessibilityElementInfo.SetParent(extensionNode->GetAccessibilityId());
        }
    }
}

std::list<AccessibilityElementInfo> SearchExtensionElementInfoByAccessibilityIdNG(
    int64_t elementId, int32_t mode, const RefPtr<NG::FrameNode>& node, int64_t offset)
{
    std::list<AccessibilityElementInfo> extensionElementInfo;
    if (NG::UI_EXTENSION_OFFSET_MIN < (offset + 1)) {
        node->SearchExtensionElementInfoByAccessibilityIdNG(
            elementId, mode, offset / NG::UI_EXTENSION_ID_FACTOR, extensionElementInfo);
    }
    return extensionElementInfo;
}

void SearchExtensionElementInfoNG(const SearchParameter& searchParam, const RefPtr<NG::FrameNode>& node,
    std::list<Accessibility::AccessibilityElementInfo>& infos, Accessibility::AccessibilityElementInfo& parentInfo)
{
    auto extensionElementInfos = SearchExtensionElementInfoByAccessibilityIdNG(
        searchParam.nodeId, searchParam.mode, node, searchParam.uiExtensionOffset);
    if (extensionElementInfos.size() > 0) {
        auto rootParentId = extensionElementInfos.front().GetParentNodeId();
        ConvertExtensionAccessibilityNodeId(extensionElementInfos, node, searchParam.uiExtensionOffset, parentInfo);
        if (rootParentId == NG::UI_EXTENSION_ROOT_ID) {
            extensionElementInfos.front().SetParent(node->GetAccessibilityId());
        }
        if (parentInfo.GetComponentType() == V2::ISOLATED_COMPONENT_ETS_TAG) {
            auto windowId = parentInfo.GetWindowId();
            for (auto& info : extensionElementInfos) {
                info.SetWindowId(windowId);
            }
        }
        for (auto& info : extensionElementInfos) {
            infos.push_back(info);
        }
    }
}

bool AccessibilityManagerImpl::ConvertActionTypeToBoolen(
    ActionType action, RefPtr<NG::FrameNode>& frameNode, int64_t elementId, RefPtr<NG::PipelineContext>& context)
{
    bool result = false;
    switch (action) {
        case ActionType::ACCESSIBILITY_ACTION_FOCUS: {
            result = RequestFocus(frameNode);
            break;
        }
        case ActionType::ACCESSIBILITY_ACTION_CLEAR_FOCUS: {
            result = LostFocus(frameNode);
            break;
        }
        case ActionType::ACCESSIBILITY_ACTION_CLICK: {
            result = ActClick(frameNode);
            break;
        }
        case ActionType::ACCESSIBILITY_ACTION_LONG_CLICK: {
            result = ActLongClick(frameNode);
            break;
        }
        case ActionType::ACCESSIBILITY_ACTION_ACCESSIBILITY_FOCUS: {
            SaveLast(elementId, frameNode);
            result = ActAccessibilityFocus(elementId, frameNode, context, currentFocusNodeId_, false);
            break;
        }
        case ActionType::ACCESSIBILITY_ACTION_CLEAR_ACCESSIBILITY_FOCUS: {
            SaveLast(elementId, frameNode);
            result = ActAccessibilityFocus(elementId, frameNode, context, currentFocusNodeId_, true);
            break;
        }
        default:
            break;
    }
    return result;
}

void SetSelectionAction(const std::map<std::string, std::string>& actionArguments, AccessibilityActionParam& param)
{
    int start = DEFAULT_SELECTION;
    int end = DEFAULT_SELECTION;
    std::string dir = STRING_DIR_BACKWARD;
    auto iter = actionArguments.find(ACTION_ARGU_SELECT_TEXT_START);
    if (iter != actionArguments.end()) {
        std::stringstream str_start;
        str_start << iter->second;
        str_start >> start;
    }
    iter = actionArguments.find(ACTION_ARGU_SELECT_TEXT_END);
    if (iter != actionArguments.end()) {
        std::stringstream str_end;
        str_end << iter->second;
        str_end >> end;
    }
    iter = actionArguments.find(ACTION_ARGU_SELECT_TEXT_INFORWARD);
    if (iter != actionArguments.end()) {
        dir = iter->second;
    }
    param.setSelectionStart = start;
    param.setSelectionEnd = end;
    param.setSelectionDir = conversionDirection(dir);
}

void SetTextAction(const std::map<std::string, std::string>& actionArguments, AccessibilityActionParam& param)
{
    auto iter = actionArguments.find(ACTION_ARGU_SET_TEXT);
    if (iter != actionArguments.end()) {
        param.setTextArgument = iter->second;
    }
}

void SetMoveTextAction(const std::map<std::string, std::string>& actionArguments, AccessibilityActionParam& param)
{
    int moveUnit = TextMoveUnit::STEP_CHARACTER;
    auto iter = actionArguments.find(ACTION_ARGU_MOVE_UNIT);
    if (iter != actionArguments.end()) {
        std::stringstream str_moveUnit;
        str_moveUnit << iter->second;
        str_moveUnit >> moveUnit;
    }
    param.moveUnit = static_cast<TextMoveUnit>(moveUnit);
}

void SetCursorPositionAction(const std::map<std::string, std::string>& actionArguments, AccessibilityActionParam& param)
{
    auto iter = actionArguments.find(ACTION_ARGU_SET_OFFSET);
    int32_t position = DEFAULT_SELECTION;
    if (iter != actionArguments.end()) {
        std::stringstream strPosition;
        strPosition << iter->second;
        strPosition >> position;
    }
    param.setCursorIndex = position;
}

void SetScrollAction(const std::map<std::string, std::string>& actionArguments, AccessibilityActionParam& param)
{
    int32_t scrollType = static_cast<int32_t>(AccessibilityScrollType::SCROLL_DEFAULT);
    auto iter = actionArguments.find(ACTION_ARGU_SCROLL_STUB);
    if (iter != actionArguments.end()) {
        std::stringstream strScrollType;
        strScrollType << iter->second;
        strScrollType >> scrollType;
    }
    if ((scrollType < static_cast<int32_t>(AccessibilityScrollType::SCROLL_DEFAULT)) ||
        (scrollType > static_cast<int32_t>(AccessibilityScrollType::SCROLL_MAX_TYPE))) {
        scrollType = static_cast<int32_t>(AccessibilityScrollType::SCROLL_DEFAULT);
    }
    param.scrollType = static_cast<AccessibilityScrollType>(scrollType);
}

bool AccessibilityManagerImpl::ActAccessibilityAction(Accessibility::ActionType action,
    const std::map<std::string, std::string> actionArguments, RefPtr<NG::AccessibilityProperty> accessibilityProperty)
{
    AccessibilityActionParam param;
    switch (action) {
        case ActionType::ACCESSIBILITY_ACTION_SET_SELECTION:
            SetSelectionAction(actionArguments, param);
            break;
        case ActionType::ACCESSIBILITY_ACTION_SET_TEXT:
            SetTextAction(actionArguments, param);
            break;
        case ActionType::ACCESSIBILITY_ACTION_NEXT_TEXT:
        case ActionType::ACCESSIBILITY_ACTION_PREVIOUS_TEXT:
            SetMoveTextAction(actionArguments, param);
            break;
        case ActionType::ACCESSIBILITY_ACTION_SET_CURSOR_POSITION:
            SetCursorPositionAction(actionArguments, param);
            break;
        case ActionType::ACCESSIBILITY_ACTION_SCROLL_FORWARD:
        case ActionType::ACCESSIBILITY_ACTION_SCROLL_BACKWARD:
            SetScrollAction(actionArguments, param);
            break;
        default:
            break;
    }
    auto accessibiltyAction = ACTIONS.find(action);
    if (accessibiltyAction != ACTIONS.end()) {
        param.accessibilityProperty = accessibilityProperty;
        return accessibiltyAction->second(param);
    }
    return false;
}

bool AccessibilityManagerImpl::ClearCurrentFocus()
{
    auto currentFocusNode = GetAccessibilityNodeFromPage(currentFocusNodeId_);
    CHECK_NULL_RETURN(currentFocusNode, false);
    currentFocusNodeId_ = DEFAULT_ElEMENTID;
    currentFocusNode->SetFocusedState(false);
    currentFocusNode->SetAccessibilityFocusedState(false);
    return currentFocusNode->ActionAccessibilityFocus(false);
}

bool AccessibilityManagerImpl::RequestAccessibilityFocus(const RefPtr<AccessibilityNode>& node)
{
    CHECK_NULL_RETURN(node, false);
    auto requestNodeId = node->GetNodeId();
    if (currentFocusNodeId_ == requestNodeId) {
        return false;
    }
    ClearCurrentFocus();
    currentFocusNodeId_ = requestNodeId;
    node->SetAccessibilityFocusedState(true);
    return node->ActionAccessibilityFocus(true);
}

bool AccessibilityManagerImpl::ClearAccessibilityFocus(const RefPtr<AccessibilityNode>& node)
{
    CHECK_NULL_RETURN(node, false);
    auto requestNodeId = node->GetNodeId();
    if (currentFocusNodeId_ != requestNodeId) {
        return false;
    }

    currentFocusNodeId_ = DEFAULT_ElEMENTID;
    node->SetAccessibilityFocusedState(false);
    return node->ActionAccessibilityFocus(false);
}

bool HandleClickAction(const RefPtr<AccessibilityNode>& node, const RefPtr<PipelineContext>& context)
{
    CHECK_NULL_RETURN(node, false);
    node->SetClicked(true);
    if (!node->GetClickEventMarker().IsEmpty()) {
#ifndef NG_BUILD
        context->SendEventToFrontend(node->GetClickEventMarker());
#endif
        node->ActionClick();
        return true;
    }
    return node->ActionClick();
}

bool HandleLongClickAction(const RefPtr<AccessibilityNode>& node, const RefPtr<PipelineContext>& context)
{
    CHECK_NULL_RETURN(node, false);
    if (!node->GetLongPressEventMarker().IsEmpty()) {
#ifndef NG_BUILD
        context->SendEventToFrontend(node->GetLongPressEventMarker());
#endif
        node->ActionLongClick();
        return true;
    }
    return node->ActionLongClick();
}

bool HandleSetTextAction(const RefPtr<AccessibilityNode>& node, const RefPtr<PipelineContext>& context,
    const std::map<std::string, std::string>& actionArguments)
{
    CHECK_NULL_RETURN(node, false);
    if (!node->GetSetTextEventMarker().IsEmpty()) {
#ifndef NG_BUILD
        context->SendEventToFrontend(node->GetSetTextEventMarker());
#endif
        node->ActionSetText(actionArguments.find(ACTION_ARGU_SET_TEXT)->second);
        return true;
    }
    return node->ActionSetText(actionArguments.find(ACTION_ARGU_SET_TEXT)->second);
}

bool HandleFocusAction(const RefPtr<AccessibilityNode>& node, const RefPtr<PipelineContext>& context)
{
    CHECK_NULL_RETURN(node, false);
#ifndef NG_BUILD
    context->AccessibilityRequestFocus(std::to_string(node->GetNodeId()));
#endif
    if (!node->GetFocusEventMarker().IsEmpty()) {
#ifndef NG_BUILD
        context->SendEventToFrontend(node->GetFocusEventMarker());
#endif
        node->ActionFocus();
        return true;
    }
    return node->ActionFocus();
}

bool AccessibilityManagerImpl::AccessibilityActionEvent(const ActionType& action,
    const std::map<std::string, std::string>& actionArguments, const RefPtr<AccessibilityNode>& node,
    const RefPtr<PipelineContext>& context)
{
    if (!node || !context) {
        return false;
    }
    ContainerScope scope(context->GetInstanceId());
    switch (action) {
        case ActionType::ACCESSIBILITY_ACTION_CLICK:
            return HandleClickAction(node, context);
        case ActionType::ACCESSIBILITY_ACTION_LONG_CLICK:
            return HandleLongClickAction(node, context);
        case ActionType::ACCESSIBILITY_ACTION_SET_TEXT:
            return HandleSetTextAction(node, context, actionArguments);
        case ActionType::ACCESSIBILITY_ACTION_FOCUS:
            return HandleFocusAction(node, context);
        case ActionType::ACCESSIBILITY_ACTION_ACCESSIBILITY_FOCUS:
            return RequestAccessibilityFocus(node);
        case ActionType::ACCESSIBILITY_ACTION_CLEAR_ACCESSIBILITY_FOCUS:
            return ClearAccessibilityFocus(node);
        case ActionType::ACCESSIBILITY_ACTION_SCROLL_FORWARD:
            return node->ActionScrollForward();
        case ActionType::ACCESSIBILITY_ACTION_SCROLL_BACKWARD:
            return node->ActionScrollBackward();
        default:
            return false;
    }
}

bool IsUserCheckedOrSelected(const RefPtr<NG::FrameNode> frameNode)
{
    CHECK_NULL_RETURN(frameNode, false);
    auto accessibilityProperty = frameNode->GetAccessibilityProperty<NG::AccessibilityProperty>();
    CHECK_NULL_RETURN(accessibilityProperty, false);
    if (accessibilityProperty->HasUserCheckedType() || accessibilityProperty->HasUserSelected()) {
        return true;
    }
    return false;
}

void AccessibilityManagerImpl::SendEventToAccessibilityWithNode(
    const AccessibilityEvent& accessibilityEvent, const RefPtr<AceType>& node, const RefPtr<PipelineBase>& context)
{
    CHECK_NULL_VOID(context);
    auto delayTime = GetDelayTimeBeforeSendEvent(accessibilityEvent, node);
    if ((delayTime > 0) && context) {
        context->GetTaskExecutor()->PostDelayedTask(
            [weak = WeakClaim(this), accessibilityEvent, node, context] {
                auto AccessibilityManager = weak.Upgrade();
                CHECK_NULL_VOID(AccessibilityManager);
                AccessibilityManager->SendEventToAccessibilityWithNodeInner(accessibilityEvent, node, context);
            },
            TaskExecutor::TaskType::UI, delayTime, "ArkUIAccessibilitySendSyncEventWithDelay");
        return;
    }
    SendEventToAccessibilityWithNodeInner(accessibilityEvent, node, context);
}

void AccessibilityManagerImpl::SendEventToAccessibilityWithNodeInner(
    const AccessibilityEvent& accessibilityEvent, const RefPtr<AceType>& node, const RefPtr<PipelineBase>& context)
{
    CHECK_NULL_VOID(context);
    int32_t windowId = static_cast<int32_t>(context->GetFocusWindowId());
    if (windowId == DEFAULT_ID) {
        return;
    }
    if (!AceType::InstanceOf<NG::FrameNode>(node)) {
        return;
    }
    auto frameNode = AceType::DynamicCast<NG::FrameNode>(node);
    CHECK_NULL_VOID(frameNode);
    auto ngPipeline = AceType::DynamicCast<NG::PipelineContext>(context);
    CHECK_NULL_VOID(ngPipeline);

    if ((!frameNode->IsActive()) || frameNode->CheckAccessibilityLevelNo()) {
        return;
    }
    ProcessAccessibilityEvent(accessibilityEvent, false, static_cast<size_t>(accessibilityEvent.type));
}

int64_t AccessibilityManagerImpl::GetDelayTimeBeforeSendEvent(
    const AccessibilityEvent& accessibilityEvent, const RefPtr<AceType>& node)
{
    if (accessibilityEvent.type != AccessibilityEventType::CLICK) {
        return 0;
    }

    auto frameNode = AceType::DynamicCast<NG::FrameNode>(node);
    if (frameNode) {
        if (IsUserCheckedOrSelected(frameNode)) {
            return DELAY_SEND_EVENT_MILLISECOND;
        }
    } else {
        auto context = GetPipelineContext().Upgrade();
        CHECK_NULL_RETURN(context, 0);
        if (!AceType::InstanceOf<NG::PipelineContext>(context)) {
            return 0;
        }
        RefPtr<NG::FrameNode> findeNode;
        auto ngPipeline = FindPipelineByElementId(accessibilityEvent.nodeId, findeNode);
        if ((findeNode) && IsUserCheckedOrSelected(findeNode)) {
            return DELAY_SEND_EVENT_MILLISECOND;
        }
    }
    return 0;
}

void AccessibilityManagerImpl::SendActionEvent(const Accessibility::ActionType& action, int64_t nodeId)
{
    static std::unordered_map<Accessibility::ActionType, std::string> actionToStr {
        { Accessibility::ActionType::ACCESSIBILITY_ACTION_CLICK, DOM_CLICK },
        { Accessibility::ActionType::ACCESSIBILITY_ACTION_LONG_CLICK, DOM_LONG_PRESS },
        { Accessibility::ActionType::ACCESSIBILITY_ACTION_FOCUS, DOM_FOCUS },
        { Accessibility::ActionType::ACCESSIBILITY_ACTION_ACCESSIBILITY_FOCUS, ACCESSIBILITY_FOCUSED_EVENT },
        { Accessibility::ActionType::ACCESSIBILITY_ACTION_CLEAR_ACCESSIBILITY_FOCUS, ACCESSIBILITY_CLEAR_FOCUS_EVENT },
        { Accessibility::ActionType::ACCESSIBILITY_ACTION_SCROLL_FORWARD, SCROLL_END_EVENT },
        { Accessibility::ActionType::ACCESSIBILITY_ACTION_SCROLL_BACKWARD, SCROLL_END_EVENT },
    };
    if (actionToStr.find(action) == actionToStr.end()) {
        return;
    }
    AccessibilityEvent accessibilityEvent;
    accessibilityEvent.eventType = actionToStr[action];
    accessibilityEvent.nodeId = static_cast<int64_t>(nodeId);
    SendAccessibilityAsyncEvent(accessibilityEvent);
}

void AccessibilityManagerImpl::InteractionOperation::ExecuteAction(
    const int64_t elementId, const int32_t action, const std::map<std::string, std::string>& actionArguments)
{
    int64_t splitElementId = AccessibilityElementInfo::UNDEFINED_ACCESSIBILITY_ID;
    int32_t splitTreeId = AccessibilityElementInfo::UNDEFINED_TREE_ID;
    GetTreeIdAndElementIdBySplitElementId(elementId, splitElementId, splitTreeId);
    auto jsAccessibilityManager = GetHandler().Upgrade();
    CHECK_NULL_VOID(jsAccessibilityManager);
    auto context = jsAccessibilityManager->GetPipelineContext().Upgrade();
    CHECK_NULL_VOID(context);
    auto actionInfo = static_cast<ActionType>(action);
    ActionParam param { actionInfo, actionArguments };
    auto windowId = windowId_;
    context->GetTaskExecutor()->PostTask(
        [weak = GetHandler(), splitElementId, param, windowId] {
            auto jsAccessibilityManager = weak.Upgrade();
            CHECK_NULL_VOID(jsAccessibilityManager);
            ACE_SCOPED_TRACE("ExecuteAction");
            jsAccessibilityManager->ExecuteAction(splitElementId, param, windowId);
        },
        TaskExecutor::TaskType::UI, "ArkUIAccessibilityExecuteAction");
}

void AccessibilityManagerImpl::InteractionOperation::RequestUpdate(const int64_t elementId)
{
    auto jsAccessibilityManager = GetHandler().Upgrade();
    CHECK_NULL_VOID(jsAccessibilityManager);
    auto context = jsAccessibilityManager->GetPipelineContext().Upgrade();
    CHECK_NULL_VOID(context);
    auto windowId = windowId_;
    context->GetTaskExecutor()->PostTask(
        [weak = GetHandler(), elementId, windowId] {
            auto jsAccessibilityManager = weak.Upgrade();
            CHECK_NULL_VOID(jsAccessibilityManager);
            ACE_SCOPED_TRACE("RequestUpdate");
            jsAccessibilityManager->RequestUpdate(elementId, windowId);
        },
        TaskExecutor::TaskType::UI, "ArkUIAccessibilityExecuteAction");
}

void AccessibilityManagerImpl::ExecuteAction(const int64_t elementId, const ActionParam& param, const int32_t windowId)
{
    auto action = param.action;
    auto actionArguments = param.actionArguments;

    bool actionResult = false;
    auto context = GetPipelineByWindowId(windowId);
    if (!context) {
        return;
    }

    if (AceType::InstanceOf<NG::PipelineContext>(context)) {
        actionResult = ExecuteActionNG(elementId, actionArguments, action, context, NG::UI_EXTENSION_OFFSET_MAX);
    } else {
        auto node = GetAccessibilityNodeFromPage(elementId);
        if (!node) {
            return;
        }

        actionResult =
            AccessibilityActionEvent(action, actionArguments, node, AceType::DynamicCast<PipelineContext>(context));
    }
    if (actionResult && AceType::InstanceOf<PipelineContext>(context)) {
        SendActionEvent(action, elementId);
    }
}

void AccessibilityManagerImpl::RequestUpdate(const int64_t elementId, const int32_t windowId)
{
    AccessibilityEvent accessibilityEvent;
    accessibilityEvent.nodeId = static_cast<int64_t>(elementId);
    ProcessAccessibilityEvent(accessibilityEvent, false, static_cast<size_t>(accessibilityEvent.type));
}

void AccessibilityManagerImpl::UpdateElementInfosByAccessibilityId(
    int64_t elementId, int32_t windowId, size_t eventType)
{
    std::lock_guard<std::mutex> lock(ocNodeUpdateMutex_);
    std::list<AccessibilityElementInfo> infos;
    auto pipeline = GetPipelineByWindowId(windowId);
    CHECK_NULL_VOID(pipeline);
    auto ngPipeline = AceType::DynamicCast<NG::PipelineContext>(pipeline);
    CHECK_NULL_VOID(ngPipeline);
    int32_t mode = DEFAULT_ID;
    SearchElementInfoByAccessibilityIdNG(elementId, mode, infos, pipeline, NG::UI_EXTENSION_OFFSET_MAX);
    UpdateNodesOC(infos, windowId, eventType);
}

RefPtr<NG::PipelineContext> AccessibilityManagerImpl::GetPipelineByWindowId(uint32_t windowId)
{
    auto mainPipeline = AceType::DynamicCast<NG::PipelineContext>(context_.Upgrade());
    if (mainPipeline != nullptr && mainPipeline->GetWindowId() == windowId) {
        return mainPipeline;
    }
    for (auto subPipelineWeak : GetSubPipelineContexts()) {
        auto subContextNG = AceType::DynamicCast<NG::PipelineContext>(subPipelineWeak.Upgrade());
        if (subContextNG != nullptr && subContextNG->GetWindowId() == windowId) {
            return subContextNG;
        }
    }
    if (GetWindowId() == windowId) {
        return mainPipeline;
    }
    return nullptr;
}

RefPtr<PipelineBase> AccessibilityManagerImpl::GetPipelineByWindowId(const int32_t windowId)
{
    auto context = context_.Upgrade();
    CHECK_NULL_RETURN(context, nullptr);
    if (AceType::InstanceOf<NG::PipelineContext>(context)) {
        CHECK_NULL_RETURN(context, nullptr);
        if (context->GetWindowId() == static_cast<uint32_t>(windowId)) {
            return context;
        }
        if (GetWindowId() == static_cast<uint32_t>(windowId)) {
            return context;
        }
        for (auto& subContext : GetSubPipelineContexts()) {
            context = subContext.Upgrade();
            CHECK_NULL_RETURN(context, nullptr);
            if (context->GetWindowId() == static_cast<uint32_t>(windowId)) {
                return context;
            }
        }
        return nullptr;
    } else {
        return context;
    }
}

void AccessibilityManagerImpl::SetAccessibilityGroupSpecific(RefPtr<OHOS::Ace::NG::FrameNode> node)
{
    CHECK_NULL_VOID(node);
    auto parent = node->GetParentFrameNode();
    CHECK_NULL_VOID(parent);

    if (parent->GetTag() == V2::TAB_BAR_ETS_TAG || node->GetTag() == "SelectMenuButton" ||
        node->GetTag() == V2::OPTION_ETS_TAG) {
        auto accessibilityProperty = node->GetAccessibilityProperty<NG::AccessibilityProperty>();
        CHECK_NULL_VOID(accessibilityProperty);
        accessibilityProperty->SetAccessibilityGroup(true);
    }
}

void AccessibilityManagerImpl::SearchElementInfoByAccessibilityIdNG(int64_t elementId, int32_t mode,
    std::list<AccessibilityElementInfo>& infos, const RefPtr<PipelineBase>& context, int64_t uiExtensionOffset)
{
    auto mainContext = context_.Upgrade();
    CHECK_NULL_VOID(mainContext);

    auto ngPipeline = AceType::DynamicCast<NG::PipelineContext>(context);
    CHECK_NULL_VOID(ngPipeline);
    auto rootNode = ngPipeline->GetRootElement();
    CHECK_NULL_VOID(rootNode);

    AccessibilityElementInfo nodeInfo;
    int64_t nodeId = elementId;
    if (elementId == DEFAULT_ElEMENTID) {
        nodeId = rootNode->GetAccessibilityId();
    }

    CommonProperty commonProperty;
    GenerateCommonProperty(ngPipeline, commonProperty, mainContext);
    auto node = GetFramenodeByAccessibilityId(rootNode, nodeId);

    CHECK_NULL_VOID(node);
    SetAccessibilityGroupSpecific(node);
    UpdateAccessibilityElementInfo(node, commonProperty, nodeInfo, ngPipeline);
    if (IsExtensionComponent(node) && !IsUIExtensionShowPlaceholder(node)) {
        SearchParameter param { DEFAULT_ElEMENTID, "", mode, uiExtensionOffset };
        SearchExtensionElementInfoNG(param, node, infos, nodeInfo);
    }

    infos.push_back(nodeInfo);
    if ((infos.size() > 0) && (uiExtensionOffset != NG::UI_EXTENSION_OFFSET_MAX) &&
        (infos.front().GetComponentType() != V2::ROOT_ETS_TAG) &&
        (infos.front().GetParentNodeId() == rootNode->GetAccessibilityId())) {
        infos.front().SetParent(NG::UI_EXTENSION_ROOT_ID);
    }
    for (auto childId : nodeInfo.GetChildIds()) {
        SearchElementInfoByAccessibilityIdNG(childId, mode, infos, context, uiExtensionOffset);
    }
}

std::string AccessibilityManagerImpl::GetPagePath()
{
    auto context = context_.Upgrade();
    CHECK_NULL_RETURN(context, "");
    auto frontend = context->GetFrontend();
    CHECK_NULL_RETURN(frontend, "");
    ContainerScope scope(context->GetInstanceId());
    return frontend->GetPagePath();
}

void AccessibilityManagerImpl::GenerateCommonProperty(
    const RefPtr<PipelineBase>& context, CommonProperty& output, const RefPtr<PipelineBase>& mainContext)
{
    auto ngPipeline = AceType::DynamicCast<NG::PipelineContext>(context);
    CHECK_NULL_VOID(ngPipeline);
    auto stageManager = ngPipeline->GetStageManager();
    CHECK_NULL_VOID(stageManager);
    if (!ngPipeline->IsFormRender()) {
        output.windowId = static_cast<int32_t>(ngPipeline->GetFocusWindowId());
    } else {
        output.windowId = static_cast<int32_t>(GetWindowId());
    }

    output.windowLeft = GetWindowLeft(ngPipeline->GetWindowId());
    output.windowTop = GetWindowTop(ngPipeline->GetWindowId());

    auto page = stageManager->GetLastPageWithTransition();
    if (page != nullptr) {
        output.pageId = page->GetPageId();
        output.pagePath = GetPagePath();
    }
    if (context->GetWindowId() != mainContext->GetWindowId()) {
        output.pageId = DEFAULT_ID;
        output.pagePath = "";
    }
}

RefPtr<NG::FrameNode> AccessibilityManagerImpl::GetFramenodeByAccessibilityId(
    const RefPtr<NG::FrameNode>& root, int64_t id)
{
    CHECK_NULL_RETURN(root, nullptr);
    if (root->GetAccessibilityId() == id) {
        return root;
    }
    std::queue<NG::UINode*> nodes;
    nodes.push(Referenced::RawPtr(root));
    NG::UINode* virtualNode = nullptr;
    RefPtr<NG::FrameNode> frameNodeResult = nullptr;

    while (!nodes.empty()) {
        auto current = nodes.front();
        nodes.pop();
        if (current->HasVirtualNodeAccessibilityProperty()) {
            auto fnode = AceType::DynamicCast<NG::FrameNode>(current);
            auto property = fnode->GetAccessibilityProperty<NG::AccessibilityProperty>();
            const auto& children = std::list<RefPtr<NG::UINode>> { property->GetAccessibilityVirtualNode() };
            if (FindFrameNodeByAccessibilityId(id, children, nodes, frameNodeResult)) {
                return frameNodeResult;
            }
        } else {
            const auto& children = current->GetChildren(true);
            if (FindFrameNodeByAccessibilityId(id, children, nodes, frameNodeResult)) {
                return frameNodeResult;
            }
        }
    }
    return nullptr;
}

void AccessibilityManagerImpl::UpdateAccessibilityElementInfo(const RefPtr<NG::FrameNode>& node,
    const CommonProperty& commonProperty, AccessibilityElementInfo& nodeInfo,
    const RefPtr<NG::PipelineContext>& ngPipeline)
{
    CHECK_NULL_VOID(node);
    nodeInfo.SetParent(GetParentId(node));
    auto accessibilityProperty = node->GetAccessibilityProperty<NG::AccessibilityProperty>();
    CHECK_NULL_VOID(accessibilityProperty);
    if (!accessibilityProperty->IsAccessibilityGroup() || node->GetTag() == "root") {
        UpdateChildrenOfAccessibilityElementInfo(node, commonProperty, nodeInfo);
    }
    nodeInfo.SetAccessibilityId(node->GetAccessibilityId());
    nodeInfo.SetComponentType(node->GetTag());
    nodeInfo.SetEnabled(node->GetFocusHub() ? node->GetFocusHub()->IsEnabled() : true);
    nodeInfo.SetFocused(node->GetFocusHub() ? node->GetFocusHub()->IsCurrentFocus() : false);
    nodeInfo.SetAccessibilityFocus(node->GetRenderContext()->GetAccessibilityFocus().value_or(false));
    nodeInfo.SetInspectorKey(node->GetInspectorId().value_or(""));
    nodeInfo.SetVisible(node->IsVisible());
    if (node->IsAccessibilityVirtualNode()) {
        auto rect = node->GetVirtualNodeTransformRectRelativeToWindow();
        auto left = rect.Left() + commonProperty.windowLeft;
        auto top = rect.Top() + commonProperty.windowTop;
        auto right = rect.Right() + commonProperty.windowLeft;
        auto bottom = rect.Bottom() + commonProperty.windowTop;
        Accessibility::Rect bounds { left, top, right, bottom };
        nodeInfo.SetRectInScreen(bounds);
    } else if (node->IsVisible()) {
        auto rect = node->GetTransformRectRelativeToWindow();
        auto left = rect.Left() + commonProperty.windowLeft;
        auto top = rect.Top() + commonProperty.windowTop;
        auto right = rect.Right() + commonProperty.windowLeft;
        auto bottom = rect.Bottom() + commonProperty.windowTop;
        Accessibility::Rect bounds { left, top, right, bottom };
        nodeInfo.SetRectInScreen(bounds);
    }
    nodeInfo.SetWindowId(commonProperty.windowId);
    nodeInfo.SetPageId(node->GetPageId());
    nodeInfo.SetPagePath(commonProperty.pagePath);
    nodeInfo.SetBundleName(AceApplicationInfo::GetInstance().GetPackageName());
    if (nodeInfo.IsEnabled()) {
        nodeInfo.SetFocusable(node->GetFocusHub() ? node->GetFocusHub()->IsFocusable() : false);
        nodeInfo.SetPopupSupported(IsPopupSupported(ngPipeline, node->GetId()));
    }
    nodeInfo.SetComponentResourceId(node->GetInspectorId().value_or(""));
    UpdateAccessibilityElementInfo(node, nodeInfo);
}

void UpdateBasicAccessibilityInfo(const RefPtr<NG::FrameNode>& node, AccessibilityElementInfo& nodeInfo,
    const RefPtr<NG::AccessibilityProperty>& accessibilityProperty)
{
    CHECK_NULL_VOID(accessibilityProperty);
    if (accessibilityProperty->HasAccessibilityRole()) {
        nodeInfo.SetComponentType(accessibilityProperty->GetAccessibilityRole());
    }
    nodeInfo.SetAccessibilityId(node->GetAccessibilityId());
    nodeInfo.SetParent(GetParentId(node));
    nodeInfo.SetComponentType(node->GetTag());
    nodeInfo.SetEnabled(node->GetFocusHub() ? node->GetFocusHub()->IsEnabled() : true);
    nodeInfo.SetFocused(node->GetFocusHub() ? node->GetFocusHub()->IsCurrentFocus() : false);
    nodeInfo.SetAccessibilityFocus(node->GetRenderContext()->GetAccessibilityFocus().value_or(false));
    nodeInfo.SetInspectorKey(node->GetInspectorId().value_or(""));
    nodeInfo.SetVisible(node->IsVisible());
}

void UpdateAccessibilityTextInfo(
    AccessibilityElementInfo& nodeInfo, const RefPtr<NG::AccessibilityProperty>& accessibilityProperty)
{
    CHECK_NULL_VOID(accessibilityProperty);
    if (accessibilityProperty->HasUserTextValue()) {
        nodeInfo.SetContent(accessibilityProperty->GetUserTextValue());
    } else if (accessibilityProperty->GetText().length() > 0) {
        nodeInfo.SetContent(accessibilityProperty->GetText());
    } else {
        nodeInfo.SetContent(accessibilityProperty->GetGroupText());
    }
    nodeInfo.SetAccessibilityText(accessibilityProperty->GetAccessibilityText());
    nodeInfo.SetHint(accessibilityProperty->GetHintText());
    nodeInfo.SetAccessibilityGroup(accessibilityProperty->IsAccessibilityGroup());
    nodeInfo.SetAccessibilityLevel(accessibilityProperty->GetAccessibilityLevel());
    nodeInfo.SetTextType(accessibilityProperty->GetTextType());
    nodeInfo.SetTextLengthLimit(accessibilityProperty->GetTextLengthLimit());
    nodeInfo.SetOffset(accessibilityProperty->GetScrollOffSet());
}

void UpdateAccessibilityRangeInfo(
    AccessibilityElementInfo& nodeInfo, const RefPtr<NG::AccessibilityProperty>& accessibilityProperty)
{
    CHECK_NULL_VOID(accessibilityProperty);
    if (accessibilityProperty->HasRange()) {
        RangeInfo rangeInfo = ConvertAccessibilityValue(accessibilityProperty->GetAccessibilityValue());
        nodeInfo.SetRange(rangeInfo);
    }
}

void UpdateAccessibilityContextInfo(const RefPtr<NG::FrameNode>& node, AccessibilityElementInfo& nodeInfo)
{
    CHECK_NULL_VOID(node);
    auto context = node->GetRenderContext();
    if (context != nullptr) {
        nodeInfo.SetZIndex(context->GetZIndex().value_or(0));
        nodeInfo.SetOpacity(context->GetOpacity().value_or(1));
        nodeInfo.SetBackgroundColor(context->GetBackgroundColor().value_or(Color::TRANSPARENT).ToString());
        nodeInfo.SetBackgroundImage(context->GetBackgroundImage().value_or(ImageSourceInfo("")).ToString());
        if (context->GetForeground() != nullptr) {
            nodeInfo.SetBlur(context->GetForeground()->propBlurRadius.value_or(Dimension(0)).ToString());
        }
    }
}

void UpdateAccessibilityStateInfo(
    AccessibilityElementInfo& nodeInfo, const RefPtr<NG::AccessibilityProperty>& accessibilityProperty)
{
    CHECK_NULL_VOID(accessibilityProperty);
    if (accessibilityProperty->HasUserDisabled()) {
        nodeInfo.SetEnabled(!accessibilityProperty->IsUserDisabled());
    }
    if (accessibilityProperty->HasUserCheckedType()) {
        nodeInfo.SetChecked(accessibilityProperty->GetUserCheckedType());
    } else {
        nodeInfo.SetChecked(accessibilityProperty->IsChecked());
    }
    if (accessibilityProperty->HasUserSelected()) {
        nodeInfo.SetSelected(accessibilityProperty->IsUserSelected());
    } else {
        nodeInfo.SetSelected(accessibilityProperty->IsSelected());
    }
    nodeInfo.SetPassword(accessibilityProperty->IsPassword());
    nodeInfo.SetPluraLineSupported(accessibilityProperty->IsMultiLine());
    nodeInfo.SetHinting(accessibilityProperty->IsHint());
    nodeInfo.SetDescriptionInfo(accessibilityProperty->GetAccessibilityDescription());
    if (accessibilityProperty->HasUserCurrentValue()) {
        nodeInfo.SetCurrentIndex(accessibilityProperty->GetUserCurrentValue());
    } else {
        nodeInfo.SetCurrentIndex(accessibilityProperty->GetCurrentIndex());
    }
    if (accessibilityProperty->HasUserMinValue()) {
        nodeInfo.SetBeginIndex(accessibilityProperty->GetUserMinValue());
    } else {
        nodeInfo.SetBeginIndex(accessibilityProperty->GetBeginIndex());
    }
    if (accessibilityProperty->HasUserMaxValue()) {
        nodeInfo.SetEndIndex(accessibilityProperty->GetUserMaxValue());
    } else {
        nodeInfo.SetEndIndex(accessibilityProperty->GetEndIndex());
    }
}

void UpdateAccessibilityGridInfo(
    AccessibilityElementInfo& nodeInfo, const RefPtr<NG::AccessibilityProperty>& accessibilityProperty)
{
    CHECK_NULL_VOID(accessibilityProperty);
    GridInfo gridInfo(accessibilityProperty->GetCollectionInfo().rows,
        accessibilityProperty->GetCollectionInfo().columns, accessibilityProperty->GetCollectionInfo().selectMode);
    nodeInfo.SetGrid(gridInfo);

    int32_t row = accessibilityProperty->GetCollectionItemInfo().row;
    int32_t column = accessibilityProperty->GetCollectionItemInfo().column;
    int32_t rowSpan = accessibilityProperty->GetCollectionItemInfo().rowSpan;
    int32_t columnSpan = accessibilityProperty->GetCollectionItemInfo().columnSpan;
    bool heading = accessibilityProperty->GetCollectionItemInfo().heading;
    GridItemInfo gridItemInfo(row, rowSpan, column, columnSpan, heading, nodeInfo.IsSelected());
    nodeInfo.SetGridItem(gridItemInfo);
}

void UpdateAccessibilityExtraInfo(
    AccessibilityElementInfo& nodeInfo, const RefPtr<NG::AccessibilityProperty>& accessibilityProperty)
{
    CHECK_NULL_VOID(accessibilityProperty);
    ExtraElementInfo extraElementInfo {};
    accessibilityProperty->GetAllExtraElementInfo(extraElementInfo);
    nodeInfo.SetExtraElement(extraElementInfo);

    auto tag = nodeInfo.GetComponentType();
    if (tag == V2::TOAST_ETS_TAG || tag == V2::POPUP_ETS_TAG || tag == V2::DIALOG_ETS_TAG ||
        tag == V2::ACTION_SHEET_DIALOG_ETS_TAG || tag == V2::ALERT_DIALOG_ETS_TAG || tag == V2::MENU_ETS_TAG ||
        tag == "SelectMenu") {
        nodeInfo.SetLiveRegion(1);
    }
    nodeInfo.SetContentInvalid(accessibilityProperty->GetContentInvalid());
    nodeInfo.SetError(accessibilityProperty->GetErrorText());
    nodeInfo.SetSelectedBegin(accessibilityProperty->GetTextSelectionStart());
    nodeInfo.SetSelectedEnd(accessibilityProperty->GetTextSelectionEnd());
    nodeInfo.SetInputType(static_cast<int>(accessibilityProperty->GetTextInputType()));
    nodeInfo.SetItemCounts(accessibilityProperty->GetCollectionItemCounts());
    nodeInfo.SetChildTreeIdAndWinId(accessibilityProperty->GetChildTreeId(), accessibilityProperty->GetChildWindowId());
}

void AccessibilityManagerImpl::UpdateAccessibilityElementInfo(
    const RefPtr<NG::FrameNode>& node, AccessibilityElementInfo& nodeInfo)
{
    CHECK_NULL_VOID(node);
    auto accessibilityProperty = node->GetAccessibilityProperty<NG::AccessibilityProperty>();
    CHECK_NULL_VOID(accessibilityProperty);

    UpdateBasicAccessibilityInfo(node, nodeInfo, accessibilityProperty);
    UpdateAccessibilityTextInfo(nodeInfo, accessibilityProperty);
    UpdateAccessibilityRangeInfo(nodeInfo, accessibilityProperty);
    UpdateAccessibilityContextInfo(node, nodeInfo);
    UpdateAccessibilityStateInfo(nodeInfo, accessibilityProperty);
    UpdateAccessibilityGridInfo(nodeInfo, accessibilityProperty);
    UpdateAccessibilityExtraInfo(nodeInfo, accessibilityProperty);
    if (nodeInfo.GetWindowId() == static_cast<int32_t>(windowId_)) {
        nodeInfo.SetBelongTreeId(treeId_);
        nodeInfo.SetParentWindowId(parentWindowId_);
    } else {
        nodeInfo.SetBelongTreeId(0);
        nodeInfo.SetParentWindowId(0);
    }
    SetAccessibilityFocusAction(nodeInfo, "ace");
    if (nodeInfo.IsEnabled()) {
        UpdateSupportAction(node, nodeInfo);
        nodeInfo.SetCheckable(accessibilityProperty->IsCheckable());
        nodeInfo.SetScrollable(accessibilityProperty->IsScrollable());
        nodeInfo.SetEditable(accessibilityProperty->IsEditable());
        nodeInfo.SetDeletable(accessibilityProperty->IsDeletable());
        accessibilityProperty->ResetSupportAction();
        auto supportAceActions = accessibilityProperty->GetSupportAction();
        for (auto it = supportAceActions.begin(); it != supportAceActions.end(); ++it) {
            AccessibleAction action(ConvertAceAction(*it), "ace");
            nodeInfo.AddAction(action);
        }
    }
}

void AccessibilityManagerImpl::UpdateNodeChildIds(const RefPtr<AccessibilityNode>& node)
{
    CHECK_NULL_VOID(node);
    node->ActionUpdateIds();
    const auto& children = node->GetChildList();
    std::vector<int32_t> childrenVec;
    auto cardId = GetCardId();
    auto rootNodeId = GetRootNodeId();

    if ((node->GetNodeId() == GetRootNodeId() + ROOT_STACK_BASE) && !children.empty() && !IsDeclarative()) {
        auto lastChildNodeId = children.back()->GetNodeId();
        if (isOhosHostCard()) {
            childrenVec.emplace_back(ConvertToCardAccessibilityId(lastChildNodeId, cardId, rootNodeId));
        } else {
            childrenVec.emplace_back(lastChildNodeId);
            for (const auto& child : children) {
                if (child->GetNodeId() == ROOT_DECOR_BASE - 1) {
                    childrenVec.emplace_back(child->GetNodeId());
                    break;
                }
            }
        }
    } else {
        childrenVec.resize(children.size());
        if (isOhosHostCard()) {
            std::transform(children.begin(), children.end(), childrenVec.begin(),
                [cardId, rootNodeId](const RefPtr<AccessibilityNode>& child) {
                    return ConvertToCardAccessibilityId(child->GetNodeId(), cardId, rootNodeId);
                });
        } else {
            std::transform(children.begin(), children.end(), childrenVec.begin(),
                [](const RefPtr<AccessibilityNode>& child) { return child->GetNodeId(); });
        }
    }
    node->SetChildIds(childrenVec);
}

void AccessibilityManagerImpl::SetPipelineContext(const RefPtr<PipelineBase>& context)
{
    context_ = context;
}

void AccessibilityManagerImpl::FireAccessibilityEventCallback(uint32_t eventId, int64_t parameter)
{
    auto eventType = static_cast<AccessibilityCallbackEventId>(eventId);
    AccessibilityEvent event;
    switch (eventType) {
        case AccessibilityCallbackEventId::ON_LOAD_PAGE:
            event.nodeId = parameter;
            event.windowChangeTypes = WindowUpdateType::WINDOW_UPDATE_ACTIVE;
            event.type = AccessibilityEventType::CHANGE;
            SendAccessibilityAsyncEvent(event);
            break;
        default:
            break;
    }
}
} // namespace OHOS::Ace::Framework