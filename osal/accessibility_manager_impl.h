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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_OSAL_ACCESSIBILITY_MANAGER_IMPL_H
#define FOUNDATION_ACE_ADAPTER_IOS_OSAL_ACCESSIBILITY_MANAGER_IMPL_H

#include "foundation/appframework/arkui/uicontent/component_info.h"

#include "adapter/ios/capability/environment/environment_proxy_impl.h"
#include "adapter/ios/osal/mock/accessibility_constants.h"
#include "adapter/ios/osal/mock/accessibility_element_info.h"
#include "base/log/ace_trace.h"
#include "base/log/dump_log.h"
#include "base/log/event_report.h"
#include "base/log/log.h"
#include "base/utils/linear_map.h"
#include "base/utils/string_utils.h"
#include "base/utils/utils.h"
#include "core/accessibility/accessibility_manager.h"
#include "core/accessibility/accessibility_utils.h"
#include "core/components_ng/base/inspector.h"
#include "core/components_v2/inspector/inspector_constants.h"
#include "core/pipeline/pipeline_context.h"
#include "core/pipeline_ng/pipeline_context.h"
#include "frameworks/bridge/common/accessibility/accessibility_node_manager.h"
#include "frameworks/bridge/common/dom/dom_type.h"
#include "frameworks/core/components_ng/pattern/ui_extension/ui_extension_manager.h"

namespace OHOS::Ace::Platform {
struct ComponentInfo;
}

namespace OHOS::Ace::Framework {
constexpr int DEFAULT_ElEMENTID = -1;
constexpr int DEFAULT_SELECTION = -1;
constexpr int DEFAULT_ID = 0;
struct SearchParameter {
    int64_t nodeId;
    std::string text;
    int32_t mode;
    int64_t uiExtensionOffset;
};

struct CommonProperty {
    int32_t windowId = DEFAULT_ID;
    int32_t windowLeft = DEFAULT_ID;
    int32_t windowTop = DEFAULT_ID;
    int32_t pageId = DEFAULT_ID;
    std::string pagePath;
};

class AccessibilityManagerImpl : public AccessibilityNodeManager {
    DECLARE_ACE_TYPE(AccessibilityManagerImpl, AccessibilityNodeManager);

public:
    AccessibilityManagerImpl() = default;
    ~AccessibilityManagerImpl() override;
    void InitializeCallback() override;
    void SendAccessibilityAsyncEvent(const AccessibilityEvent& accessibilityEvent) override;
    void SendEventToAccessibilityWithNode(const AccessibilityEvent& accessibilityEvent, const RefPtr<AceType>& node,
        const RefPtr<PipelineBase>& context) override;
    void SetPipelineContext(const RefPtr<PipelineBase>& context) override;
    bool GetAllComponents(NodeId nodeID, OHOS::Ace::Platform::ComponentInfo& rootComponent);
    bool SubscribeStateObserver();
    void UnSubscribeStateObserver();
    void RegisterInteractionOperation(int windowId);
    void DeregisterInteractionOperation();
    struct ActionParam {
        Accessibility::ActionType action;
        std::map<std::string, std::string> actionArguments;
    };
    void ExecuteAction(const int64_t accessibilityId, const ActionParam& param, const int32_t windowId);
    void RequestUpdate(int64_t elementId, const int32_t windowId);
    bool ExecuteActionNG(int32_t elementId, AceAction action, const RefPtr<PipelineBase>& context);
    bool ExecuteActionNG(int64_t elementId, const std::map<std::string, std::string>& actionArguments,
        Accessibility::ActionType action, const RefPtr<PipelineBase>& context, int64_t uiExtensionOffset);
    void SearchElementInfoByAccessibilityIdNG(int64_t elementId, int32_t mode,
        std::list<Accessibility::AccessibilityElementInfo>& infos, const RefPtr<PipelineBase>& context,
        const int64_t uiExtensionOffset = DEFAULT_ID);
    void UpdateNodeChildIds(const RefPtr<AccessibilityNode>& node);
    void SendActionEvent(const Accessibility::ActionType& action, int64_t nodeId);
    void FireAccessibilityEventCallback(uint32_t eventId, int64_t parameter) override;

    std::string GetPagePath();

    uint32_t GetWindowId() const
    {
        return windowId_;
    }

    void SetWindowId(uint32_t windowId)
    {
        windowId_ = windowId;
    }

    void SaveLast(const int64_t elementId, const RefPtr<NG::FrameNode>& node)
    {
        lastElementId_ = elementId;
        lastFrameNode_ = node;
    }

    class InteractionOperation {
    public:
        explicit InteractionOperation(int32_t windowId) : windowId_(windowId) {}
        virtual ~InteractionOperation() = default;

        void ExecuteAction(
            const int64_t elementId, const int32_t action, const std::map<std::string, std::string>& actionArguments);

        void RequestUpdate(const int64_t elementId);

        void SetHandler(const WeakPtr<AccessibilityManagerImpl>& impl)
        {
            impl_ = impl;
        }

        const WeakPtr<AccessibilityManagerImpl>& GetHandler() const
        {
            return impl_;
        }

    private:
        WeakPtr<AccessibilityManagerImpl> impl_;
        uint32_t windowId_ = DEFAULT_ID;
    };

    class AccessibilityStateObserver {
    public:
        void OnStateChanged(const bool state);
        void SetAccessibilityManager(const WeakPtr<AccessibilityManagerImpl>& accessibilityManager)
        {
            accessibilityManager_ = accessibilityManager;
        }

        void SetPipeline(const WeakPtr<PipelineBase>& pipeline)
        {
            pipeline_ = pipeline;
        }

    private:
        WeakPtr<AccessibilityManagerImpl> accessibilityManager_;
        WeakPtr<PipelineBase> pipeline_;
    };

protected:
    void DumpHandleEvent(const std::vector<std::string>& params) override;
    void DumpProperty(const std::vector<std::string>& params) override;
    void DumpTree(int32_t depth, int64_t nodeID, bool isDumpSimplify = false) override;

private:
    RefPtr<NG::PipelineContext> FindPipelineByElementId(const int32_t elementId, RefPtr<NG::FrameNode>& node);
    RefPtr<NG::FrameNode> FindNodeFromPipeline(const WeakPtr<PipelineBase>& context, const int32_t elementId);
    RefPtr<PipelineBase> GetPipelineByWindowId(const int32_t windowId);
    RefPtr<NG::PipelineContext> GetPipelineByWindowId(uint32_t windowId);
    void GenerateCommonProperty(
        const RefPtr<PipelineBase>& context, CommonProperty& output, const RefPtr<PipelineBase>& mainContext);
    RefPtr<NG::FrameNode> GetFramenodeByAccessibilityId(const RefPtr<NG::FrameNode>& root, int64_t id);
    void SendEventToAccessibilityWithNodeInner(
        const AccessibilityEvent& accessibilityEvent, const RefPtr<AceType>& node, const RefPtr<PipelineBase>& context);
    void UpdateAccessibilityElementInfo(
        const RefPtr<NG::FrameNode>& node, Accessibility::AccessibilityElementInfo& nodeInfo);
    void UpdateAccessibilityElementInfo(const RefPtr<NG::FrameNode>& node, const CommonProperty& commonProperty,
        Accessibility::AccessibilityElementInfo& nodeInfo, const RefPtr<NG::PipelineContext>& ngPipeline);
    bool ConvertActionTypeToBoolen(Accessibility::ActionType action, RefPtr<NG::FrameNode>& frameNode,
        int64_t elementId, RefPtr<NG::PipelineContext>& context);
    bool AccessibilityActionEvent(const Accessibility::ActionType& action,
        const std::map<std::string, std::string>& actionArguments, const RefPtr<AccessibilityNode>& node,
        const RefPtr<PipelineContext>& context);
    bool ActAccessibilityAction(Accessibility::ActionType action,
        const std::map<std::string, std::string> actionArguments,
        RefPtr<NG::AccessibilityProperty> accessibilityProperty);
    void ProcessAccessibilityEvent(const AccessibilityEvent& accessibilityEvent, bool needAsync, size_t eventType);
    void UpdateElementInfos(const int64_t elementId, RefPtr<NG::FrameNode> node, bool needAsync, size_t eventType);
    void SetAccessibilityGroupSpecific(RefPtr<OHOS::Ace::NG::FrameNode> node);
    void UpdateElementInfosByAccessibilityId(const int64_t elementId, const int32_t mode, size_t eventType);
    bool ClearCurrentFocus();
    bool RequestAccessibilityFocus(const RefPtr<AccessibilityNode>& node);
    bool ClearAccessibilityFocus(const RefPtr<AccessibilityNode>& node);
    int64_t GetDelayTimeBeforeSendEvent(const AccessibilityEvent& accessibilityEvent, const RefPtr<AceType>& node);
    std::shared_ptr<AccessibilityStateObserver> stateObserver_ = nullptr;
    uint32_t windowId_ = DEFAULT_ID;
    uint32_t parentWindowId_ = DEFAULT_ID;
    int64_t lastElementId_ = DEFAULT_ElEMENTID;
    int64_t currentFocusNodeId_ = DEFAULT_ElEMENTID;
    WeakPtr<NG::FrameNode> lastFrameNode_;
    mutable std::mutex ocNodeUpdateMutex_;
};
} // namespace OHOS::Ace::Framework
#endif // FOUNDATION_ACE_ADAPTER_PREVIEW_INSPECTOR_JS_INSPECTOR_MANAGER_H
