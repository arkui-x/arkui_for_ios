//
//  TestMinixContainer.hpp
//  sources
//
//  Created by vail 王军平 on 2021/12/21.
//

#include <sys/_types/_int32_t.h>
#include <vector>
#include <iostream>
#include <string.h>
#include <memory>
#include "base/resource/asset_manager.h"
#include "base/thread/task_executor.h"
#include "base/utils/noncopyable.h"
#include "core/common/ace_view.h"
#include "core/common/container.h"
#include "core/common/js_message_dispatcher.h"
#include "core/common/platform_bridge.h"
#include "adapter/ios/entrance/flutter_ace_view.h"
#include "adapter/preview/entrance/ace_run_args.h"
#include "frameworks/bridge/js_frontend/engine/common/js_engine.h"
namespace OHOS::Ace::Platform {

namespace {
   constexpr int32_t ACE_INSTANCE_ID = 0;
}

class AceContainer : public Container,public JsMessageDispatcher {
    DECLARE_ACE_TYPE(AceContainer, Container, JsMessageDispatcher);
    
public:
    AceContainer(int32_t instanceId, FrontendType type);
    static void AddAssetPath(int32_t instanceId, const std::string& packagePath, const std::vector<std::string>& paths);
    static void SetResourcesPathAndThemeStyle(int32_t instanceId, const std::string& systemResourcesPath,
        const std::string& appResourcesPath, const int32_t& themeId, const ColorMode& colorMode);
    static void SetView(FlutterAceView* view, double density, int32_t width, int32_t height);
    ~AceContainer() override = default;
    void Initialize() override;
    static void CreateContainer(int32_t instanceId, FrontendType type);
    static std::string GetCustomAssetPath(std::string assetPath);
    static void RequestFrame();

    static RefPtr<AceContainer> GetContainerInstance(int32_t instanceId);

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
    
    RefPtr<AssetManager> GetAssetManager() const override
    {
        return assetManager_;
    }
    
    RefPtr<PlatformResRegister> GetPlatformResRegister() const override
    {
        return resRegister_;
    }
    
    RefPtr<PipelineContext> GetPipelineContext() const override
    {
        return pipelineContext_;
    }
    
    bool Dump(const std::vector<std::string>& params) override;
    
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
    
    void* GetView() const override
    {
        return static_cast<void*>(aceView_);
    }
    
    void Dispatch(const std::string& group, std::vector<uint8_t>&& data, int32_t id, bool replyToComponent) const override;
    
    void DispatchSync(const std::string& group, std::vector<uint8_t>&& data, uint8_t** resData, int64_t& position) const override
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
    static void SetJsFrameworkLocalPath(const char *);
private:
    void InitializeFrontend();
    void InitializeCallback();
    void AttachView(std::unique_ptr<Window> window, FlutterAceView* view, double density, int32_t width, int32_t height);

    int32_t instanceId_ = 0;
    AceView* aceView_ = nullptr;
    RefPtr<TaskExecutor> taskExecutor_;
    RefPtr<AssetManager> assetManager_;
    RefPtr<PlatformResRegister> resRegister_;
    RefPtr<PipelineContext> pipelineContext_;
    RefPtr<Frontend> frontend_;
    FrontendType type_ = FrontendType::JS;
    ColorScheme colorScheme_ { ColorScheme::SCHEME_LIGHT };
    ResourceInfo resourceInfo_;
    static std::once_flag onceFlag_;
    ACE_DISALLOW_COPY_AND_MOVE(AceContainer);
};

} // namespace OHOS::Ace::Platform
