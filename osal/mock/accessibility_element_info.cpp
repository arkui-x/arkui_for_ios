/*
 * Copyright (C) 2024-2024 Huawei Device Co., Ltd.
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

#include "accessibility_element_info.h"

#include <cinttypes>

namespace OHOS {
namespace Accessibility {

const std::vector<int64_t>& AccessibilityElementInfo::GetChildIds() const
{
    return childNodeIds_;
}

void AccessibilityElementInfo::AddChild(const int64_t childId)
{
    for (int32_t i = 0; i < childCount_; i++) {
        if (childNodeIds_[i] == childId) {
            return;
        }
    }
    childCount_++;
    childNodeIds_.push_back(childId);
}

bool AccessibilityElementInfo::RemoveChild(const int64_t childId)
{
    for (auto iter = childNodeIds_.begin(); iter != childNodeIds_.end(); iter++) {
        if (*iter == childId) {
            iter = childNodeIds_.erase(iter);
            childCount_--;
            return true;
        }
    }
    return false;
}

const std::vector<AccessibleAction>& AccessibilityElementInfo::GetActionList() const
{
    return operations_;
}

void AccessibilityElementInfo::AddAction(AccessibleAction& action)
{
    operations_.push_back(action);
}

void AccessibilityElementInfo::SetTextLengthLimit(const int32_t max)
{
    textLengthLimit_ = max;
}

int32_t AccessibilityElementInfo::GetTextLengthLimit() const
{
    return textLengthLimit_;
}

int32_t AccessibilityElementInfo::GetWindowId() const
{
    return windowId_;
}

void AccessibilityElementInfo::SetWindowId(const int32_t windowId)
{
    windowId_ = windowId;
}

int64_t AccessibilityElementInfo::GetParentNodeId() const
{
    return parentId_;
}

void AccessibilityElementInfo::SetParent(const int64_t parentId)
{
    parentId_ = parentId;
}

const Rect& AccessibilityElementInfo::GetRectInScreen() const
{
    return bounds_;
}

void AccessibilityElementInfo::SetRectInScreen(Rect& bounds)
{
    bounds_.SetLeftTopScreenPostion(bounds.GetLeftTopXScreenPostion(), bounds.GetLeftTopYScreenPostion());
    bounds_.SetRightBottomScreenPostion(bounds.GetRightBottomXScreenPostion(), bounds.GetRightBottomYScreenPostion());
}

bool AccessibilityElementInfo::IsCheckable() const
{
    return checkable_;
}

void AccessibilityElementInfo::SetCheckable(const bool checkable)
{
    checkable_ = checkable;
}

bool AccessibilityElementInfo::IsChecked() const
{
    return checked_;
}

void AccessibilityElementInfo::SetChecked(const bool checked)
{
    checked_ = checked;
}

bool AccessibilityElementInfo::IsFocusable() const
{
    return focusable_;
}

void AccessibilityElementInfo::SetFocusable(const bool focusable)
{
    focusable_ = focusable;
}

bool AccessibilityElementInfo::IsFocused() const
{
    return focused_;
}

void AccessibilityElementInfo::SetFocused(const bool focused)
{
    focused_ = focused;
}

bool AccessibilityElementInfo::IsVisible() const
{
    return visible_;
}

void AccessibilityElementInfo::SetVisible(const bool visible)
{
    visible_ = visible;
}

bool AccessibilityElementInfo::HasAccessibilityFocus() const
{
    return accessibilityFocused_;
}

void AccessibilityElementInfo::SetAccessibilityFocus(const bool focused)
{
    accessibilityFocused_ = focused;
}

bool AccessibilityElementInfo::IsSelected() const
{
    return selected_;
}

void AccessibilityElementInfo::SetSelected(const bool selected)
{
    selected_ = selected;
}

bool AccessibilityElementInfo::IsClickable() const
{
    return clickable_;
}

void AccessibilityElementInfo::SetClickable(const bool clickable)
{
    clickable_ = clickable;
}

bool AccessibilityElementInfo::IsLongClickable() const
{
    return longClickable_;
}

void AccessibilityElementInfo::SetLongClickable(const bool longClickable)
{
    longClickable_ = longClickable;
}

bool AccessibilityElementInfo::IsEnabled() const
{
    return enable_;
}

void AccessibilityElementInfo::SetEnabled(const bool enabled)
{
    enable_ = enabled;
}

bool AccessibilityElementInfo::IsPassword() const
{
    return isPassword_;
}

void AccessibilityElementInfo::SetPassword(const bool type)
{
    isPassword_ = type;
}

bool AccessibilityElementInfo::IsScrollable() const
{
    return scrollable_;
}

void AccessibilityElementInfo::SetScrollable(const bool scrollable)
{
    scrollable_ = scrollable;
}

int32_t AccessibilityElementInfo::GetCurrentIndex() const
{
    return currentIndex_;
}

void AccessibilityElementInfo::SetCurrentIndex(const int32_t index)
{
    currentIndex_ = index;
}

int32_t AccessibilityElementInfo::GetBeginIndex() const
{
    return beginIndex_;
}

void AccessibilityElementInfo::SetBeginIndex(const int32_t index)
{
    beginIndex_ = index;
}

int32_t AccessibilityElementInfo::GetEndIndex() const
{
    return endIndex_;
}

void AccessibilityElementInfo::SetEndIndex(const int32_t index)
{
    endIndex_ = index;
}

void AccessibilityElementInfo::SetInputType(const int32_t inputType)
{
    inputType_ = inputType;
}

void AccessibilityElementInfo::SetInspectorKey(const std::string& key)
{
    inspectorKey_ = key;
}

void AccessibilityElementInfo::SetPagePath(const std::string& path)
{
    pagePath_ = path;
}

const std::string& AccessibilityElementInfo::GetPagePath() const
{
    return pagePath_;
}

bool AccessibilityElementInfo::IsEditable() const
{
    return editable_;
}

void AccessibilityElementInfo::SetEditable(const bool editable)
{
    editable_ = editable;
}

void AccessibilityElementInfo::SetPluraLineSupported(const bool multiLine)
{
    multiLine_ = multiLine;
}

bool AccessibilityElementInfo::IsPopupSupported() const
{
    return popupSupported_;
}

void AccessibilityElementInfo::SetPopupSupported(const bool supportPopup)
{
    popupSupported_ = supportPopup;
}

bool AccessibilityElementInfo::IsDeletable() const
{
    return deletable_;
}

void AccessibilityElementInfo::SetDeletable(const bool deletable)
{
    deletable_ = deletable;
}

void AccessibilityElementInfo::SetHinting(const bool hinting)
{
    hint_ = hinting;
}

const std::string& AccessibilityElementInfo::GetBundleName() const
{
    return bundleName_;
}

void AccessibilityElementInfo::SetBundleName(const std::string& bundleName)
{
    bundleName_ = bundleName;
}

const std::string& AccessibilityElementInfo::GetComponentType() const
{
    return componentType_;
}

void AccessibilityElementInfo::SetComponentType(const std::string& className)
{
    componentType_ = className;
}

const std::string& AccessibilityElementInfo::GetContent() const
{
    return text_;
}

void AccessibilityElementInfo::SetContent(const std::string& text)
{
    text_ = text;
}

void AccessibilityElementInfo::SetSelectedBegin(const int32_t start)
{
    beginSelected_ = start;
}

void AccessibilityElementInfo::SetSelectedEnd(const int32_t end)
{
    endSelected_ = end;
}

const std::string& AccessibilityElementInfo::GetHint() const
{
    return hintText_;
}

void AccessibilityElementInfo::SetHint(const std::string& hintText)
{
    hintText_ = hintText;
}

const std::string& AccessibilityElementInfo::GetDescriptionInfo() const
{
    return contentDescription_;
}

void AccessibilityElementInfo::SetDescriptionInfo(const std::string& contentDescription)
{
    contentDescription_ = contentDescription;
}

void AccessibilityElementInfo::SetComponentResourceId(const std::string& viewIdResName)
{
    resourceName_ = viewIdResName;
}

void AccessibilityElementInfo::SetLiveRegion(const int32_t liveRegion)
{
    liveRegion_ = liveRegion;
}

void AccessibilityElementInfo::SetContentInvalid(const bool contentInvalid)
{
    contentInvalid_ = contentInvalid;
}

bool AccessibilityElementInfo::GetContentInvalid() const
{
    return contentInvalid_;
}

void AccessibilityElementInfo::SetError(const std::string& error)
{
    error_ = error;
}

void AccessibilityElementInfo::SetAccessibilityId(const int64_t componentId)
{
    elementId_ = componentId;
}

int64_t AccessibilityElementInfo::GetAccessibilityId() const
{
    return elementId_;
}

void AccessibilityElementInfo::SetRange(RangeInfo& rangeInfo)
{
    rangeInfo_.SetMax(rangeInfo.GetMax());
    rangeInfo_.SetMin(rangeInfo.GetMin());
    rangeInfo_.SetCurrent(rangeInfo.GetCurrent());
}

void AccessibilityElementInfo::SetGrid(const GridInfo& grid)
{
    grid_ = grid;
}

void AccessibilityElementInfo::SetGridItem(const GridItemInfo& gridItem)
{
    gridItem_ = gridItem;
}

const std::string& AccessibilityElementInfo::GetAccessibilityText() const
{
    return accessibilityText_;
}

void AccessibilityElementInfo::SetAccessibilityText(const std::string& accessibilityText)
{
    accessibilityText_ = accessibilityText;
}

void AccessibilityElementInfo::SetTextType(const std::string& textType)
{
    textType_ = textType;
}

const std::string& AccessibilityElementInfo::GetTextType() const
{
    return textType_;
}

void AccessibilityElementInfo::SetOffset(const float offset)
{
    offset_ = offset;
}

AccessibilityElementInfo::AccessibilityElementInfo() {}

AccessibleAction::AccessibleAction(ActionType actionType, const std::string& description)
{
    actionType_ = actionType;
    description_ = description;
}

ActionType AccessibleAction::GetActionType() const
{
    return actionType_;
}

const std::string& AccessibleAction::GetDescriptionInfo() const
{
    return description_;
}

RangeInfo::RangeInfo(double min, double max, double current)
{
    min_ = min;
    max_ = max;
    current_ = current;
}

double RangeInfo::GetMin() const
{
    return min_;
}

double RangeInfo::GetMax() const
{
    return max_;
}

double RangeInfo::GetCurrent() const
{
    return current_;
}

void RangeInfo::SetMin(double min)
{
    min_ = min;
}

void RangeInfo::SetMax(double max)
{
    max_ = max;
}

void RangeInfo::SetCurrent(double current)
{
    current_ = current;
}

GridInfo::GridInfo(int32_t rowCount, int32_t columnCount, int32_t mode)
{
    rowCount_ = rowCount;
    columnCount_ = columnCount;
    selectionMode_ = mode;
}

void GridInfo::SetGrid(int32_t rowCount, int32_t columnCount, int32_t mode)
{
    rowCount_ = rowCount;
    columnCount_ = columnCount;
    selectionMode_ = mode;
}

void GridInfo::SetGrid(GridInfo other)
{
    rowCount_ = other.rowCount_;
    columnCount_ = other.columnCount_;
    selectionMode_ = other.selectionMode_;
}

GridItemInfo::GridItemInfo(
    int32_t rowIndex, int32_t rowSpan, int32_t columnIndex, int32_t columnSpan, bool heading, bool selected)
{
    rowIndex_ = rowIndex;
    rowSpan_ = rowSpan;
    columnIndex_ = columnIndex;
    columnSpan_ = columnSpan;
    heading_ = heading;
    selected_ = selected;
}

int32_t GridItemInfo::GetColumnSpan() const
{
    return columnSpan_;
}

bool GridItemInfo::IsSelected() const
{
    return selected_;
}

int32_t AccessibilityElementInfo::GetPageId() const
{
    return pageId_;
}

void AccessibilityElementInfo::SetPageId(const int32_t pageId)
{
    pageId_ = pageId;
}

void AccessibilityElementInfo::SetItemCounts(const int32_t itemCounts)
{
    itemCounts_ = itemCounts;
}

void AccessibilityElementInfo::SetChildTreeIdAndWinId(const int32_t iChildTreeId, const int32_t iChildWindowId)
{
    childTreeId_ = iChildTreeId;
    childWindowId_ = iChildWindowId;
}

int32_t AccessibilityElementInfo::GetChildTreeId() const
{
    return childTreeId_;
}

int32_t AccessibilityElementInfo::GetChildWindowId() const
{
    return childWindowId_;
}

void AccessibilityElementInfo::SetBelongTreeId(const int32_t iBelongTreeId)
{
    belongTreeId_ = iBelongTreeId;
}

void AccessibilityElementInfo::SetParentWindowId(const int32_t iParentWindowId)
{
    parentWindowId_ = iParentWindowId;
}

void AccessibilityElementInfo::SetExtraElement(const ExtraElementInfo& extraElementInfo)
{
    extraElementInfo_ = extraElementInfo;
}

const std::string& AccessibilityElementInfo::GetAccessibilityLevel() const
{
    return accessibilityLevel_;
}

void AccessibilityElementInfo::SetAccessibilityGroup(const bool accessibilityGroup)
{
    accessibilityGroup_ = accessibilityGroup;
}

void AccessibilityElementInfo::SetAccessibilityLevel(const std::string& accessibilityLevel)
{
    accessibilityLevel_ = accessibilityLevel;
}

void AccessibilityElementInfo::SetZIndex(const int32_t zIndex)
{
    zIndex_ = zIndex;
}

int32_t AccessibilityElementInfo::GetZIndex() const
{
    return zIndex_;
}

void AccessibilityElementInfo::SetOpacity(const float opacity)
{
    opacity_ = opacity;
}

float AccessibilityElementInfo::GetOpacity() const
{
    return opacity_;
}

void AccessibilityElementInfo::SetBackgroundColor(const std::string& backgroundColor)
{
    backgroundColor_ = backgroundColor;
}

const std::string& AccessibilityElementInfo::GetBackgroundColor() const
{
    return backgroundColor_;
}

void AccessibilityElementInfo::SetBackgroundImage(const std::string& backgroundImage)
{
    backgroundImage_ = backgroundImage;
}

const std::string& AccessibilityElementInfo::GetBackgroundImage() const
{
    return backgroundImage_;
}

void AccessibilityElementInfo::SetBlur(const std::string& blur)
{
    blur_ = blur;
}

void AccessibilityElementInfo::SetHitTestBehavior(const std::string& hitTestBehavior)
{
    hitTestBehavior_ = hitTestBehavior;
}
} // namespace Accessibility
} // namespace OHOS