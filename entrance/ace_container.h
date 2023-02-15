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

#ifndef FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACE_CONTAINER_H
#define FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACE_CONTAINER_H

#include <iostream>
#include <memory>
#include <string.h>
#include <vector>

#include "adapter/ios/entrance/flutter_ace_view.h"
#include "adapter/preview/entrance/ace_run_args.h"
#include "base/resource/asset_manager.h"
#include "base/thread/task_executor.h"
#include "base/utils/noncopyable.h"
#include "core/common/ace_view.h"
#include "core/common/container.h"
#include "core/common/js_message_dispatcher.h"
#include "core/common/platform_bridge.h"
#include "frameworks/bridge/js_frontend/engine/common/js_engine.h"

#include "flutter/fml/synchronization/waitable_event.h"

namespace OHOS::Ace::Platform {

namespace {
constexpr int32_t ACE_INSTANCE_ID = 0;
}

class AceContainer : public Container, public JsMessageDispatcher {
    DECLARE_ACE_TYPE(AceContainer, Container, JsMessageDispatcher);

public:
    AceContainer(int32_t instanceId, FrontendType type);
    static void AddAssetPath(int32_t instanceId, const std::string& packagePath, const std::vector<std::string>& paths);
    static void SetView(FlutterAceView* view, double density, int32_t width, int32_t height);
    ~AceContainer() override = default;
    void Initialize() override;
    static void CreateContainer(int32_t instanceId, FrontendType type);
    static void RemoveContainer(int32_t instanceId);
    static std::string GetCustomAssetPath(std::string assetPath);
    static void RequestFrame();

    static RefPtr<AceContainer> GetContainerInstance(int32_t instanceId);

    void UpdateColorMode(ColorMode colorMode);

    int32_t GetInstanceId() const override
    {
        if (aceView_) {
            return aceView_->GetInstanceId();
        }
        return 0;
    }

    void Destroy() override;

    std::string GetHostClassName() const override
    {
        return "";
    }

    RefPtr<Frontend> GetFrontend() const override
    {
        return frontend_;
    }

    RefPtr<TaskExecutor> GetTaskExecutor() const override
    {
        return taskExecutor_;
    }

    void SetAssetManager(RefPtr<AssetManager> assetManager)
    {
        assetManager_ = assetManager;
        if (frontend_) {
            frontend_->SetAssetManager(assetManager);
        }
    }

    RefPtr<AssetManager> GetAssetManager() const override
    {
        return assetManager_;
    }

    RefPtr<PlatformResRegister> GetPlatformResRegister() const override
    {
        return resRegister_;
    }

    RefPtr<PipelineBase> GetPipelineContext() const override
    {
        return pipelineContext_;
    }

    bool Dump(const std::vector<std::string>& params, std::vector<std::string>& info) override;

    AceView* GetAceView()
    {
        return aceView_;
    }

    int32_t GetViewWidth() const override
    {
        return aceView_ ? aceView_->GetWidth() : 0;
    }

    int32_t GetViewHeight() const override
    {
        return aceView_ ? aceView_->GetHeight() : 0;
    }

    int32_t GetViewPosX() const override
    {
        return aceView_ ? aceView_->GetPosX() : 0;
    }

    int32_t GetViewPosY() const override
    {
        return aceView_ ? aceView_->GetPosY() : 0;
    }

    uint32_t GetWindowId() const override
    {
        return 0;
    }

    void SetWindowId(uint32_t windowId) override {}

    void* GetView() const override
    {
        return static_cast<void*>(aceView_);
    }

    void Dispatch(
        const std::string& group, std::vector<uint8_t>&& data, int32_t id, bool replyToComponent) const override;

    void DispatchSync(
        const std::string& group, std::vector<uint8_t>&& data, uint8_t** resData, int64_t& position) const override
    {}

    void DispatchPluginError(int32_t callbackId, int32_t errorCode, std::string&& errorMessage) const override;

    static void OnShow(int32_t instanceId);
    static void OnHide(int32_t instanceId);
    static void OnActive(int32_t instanceId);
    static void OnInactive(int32_t instanceId);
    static bool OnBackPressed(int32_t instanceId);
    static std::string OnSaveData(int32_t instanceId);
    static bool OnRestoreData(int32_t instanceId, const std::string& data);

    static bool RunPage(int32_t instanceId, int32_t pageId, const std::string& url, const std::string& params);
    static void SetJsFrameworkLocalPath(const char*);
    void initResourceManager(std::string pkgPath, int32_t themeId);

private:
    void InitializeFrontend();
    void InitializeCallback();
    void SetThemeResourceInfo(const std::string& path, int32_t themeId);
    void InitThemeManager();
    void AttachView(
        std::unique_ptr<Window> window, FlutterAceView* view, double density, int32_t width, int32_t height);

    int32_t instanceId_ = 0;
    AceView* aceView_ = nullptr;
    RefPtr<TaskExecutor> taskExecutor_;
    RefPtr<AssetManager> assetManager_;
    RefPtr<PlatformResRegister> resRegister_;
    RefPtr<PipelineBase> pipelineContext_;
    RefPtr<Frontend> frontend_;
    FrontendType type_ = FrontendType::JS;
    ColorScheme colorScheme_ { ColorScheme::SCHEME_LIGHT };
    ResourceInfo resourceInfo_;
    static std::once_flag onceFlag_;
    RefPtr<ThemeManager> themeManager_;
    std::shared_ptr<fml::ManualResetWaitableEvent> themeLatch_;
    ACE_DISALLOW_COPY_AND_MOVE(AceContainer);
};

} // namespace OHOS::Ace::Platform

#endif // FOUNDATION_ACE_ADAPTER_IOS_ENTRANCE_ACE_CONTAINER_H
