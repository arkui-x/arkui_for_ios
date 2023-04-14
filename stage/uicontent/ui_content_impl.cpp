/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

#include "adapter/ios/stage/uicontent/ui_content_impl.h"

#include "ability.h"
#include "ability_context.h"
#include "ability_info.h"
#include "js_runtime_utils.h"
#include "res_config.h"
#include "resource_manager.h"
#include "stage_asset_manager.h"

#include "adapter/ios/entrance/ace_application_info_impl.h"
#include "adapter/ios/entrance/capability_registry.h"
#include "adapter/ios/osal/file_asset_provider.h"
#include "adapter/ios/stage/uicontent/ace_container_sg.h"
#include "adapter/ios/stage/uicontent/ace_view_sg.h"
#include "adapter/ios/stage/uicontent/platform_event_callback.h"
#include "base/log/ace_trace.h"
#include "base/log/event_report.h"
#include "base/log/log.h"
#include "core/common/ace_engine.h"
#include "core/common/ace_view.h"
#include "core/common/container.h"
#include "core/common/container_scope.h"
#include "core/common/flutter/flutter_asset_manager.h"

namespace OHOS::Ace::Platform {
namespace {
const std::string START_PARAMS_KEY = "__startParams";
} // namespace

using ContentFinishCallback = std::function<void()>;
using ContentStartAbilityCallback = std::function<void(const std::string& address)>;
class ContentEventCallback final : public Platform::PlatformEventCallback {
public:
    explicit ContentEventCallback(ContentFinishCallback onFinish) : onFinish_(onFinish) {}
    ContentEventCallback(ContentFinishCallback onFinish, ContentStartAbilityCallback onStartAbility)
        : onFinish_(onFinish), onStartAbility_(onStartAbility)
    {}
    ~ContentEventCallback() override = default;

    void OnFinish() const override
    {
        LOGI("UIContent OnFinish");
        CHECK_NULL_VOID_NOLOG(onFinish_);
        onFinish_();
    }

    void OnStartAbility(const std::string& address) override
    {
        LOGI("UIContent OnStartAbility");
        CHECK_NULL_VOID_NOLOG(onStartAbility_);
        onStartAbility_(address);
    }

    void OnStatusBarBgColorChanged(uint32_t color) override
    {
        LOGI("UIContent OnStatusBarBgColorChanged");
    }

private:
    ContentFinishCallback onFinish_;
    ContentStartAbilityCallback onStartAbility_;
};

UIContentImpl::UIContentImpl(OHOS::AbilityRuntime::Platform::Context* context, NativeEngine* runtime)
    : runtime_(reinterpret_cast<void*>(runtime))
{
    CHECK_NULL_VOID(context);
    const auto& obj = context->GetBindingObject();
    auto ref = obj->Get<NativeReference>();
    auto object = AbilityRuntime::ConvertNativeValueTo<NativeObject>(ref->Get());
    auto weak = static_cast<std::weak_ptr<AbilityRuntime::Platform::Context>*>(object->GetNativePointer());
    context_ = *weak;

    LOGI("Create UIContentImpl successfully.");
}

void UIContentImpl::DestroyCallback() const
{
    auto container = Platform::AceContainerSG::GetContainer(instanceId_);
    CHECK_NULL_VOID(container);
    auto pipelineContext = container->GetPipelineContext();
    CHECK_NULL_VOID(pipelineContext);
    pipelineContext->SetNextFrameLayoutCallback(nullptr);
    LOGI("DestroyCallback called.");
}

void UIContentImpl::Initialize(OHOS::Rosen::Window* window, const std::string& url, NativeValue* storage)
{
    if (window) {
        CommonInitialize(window, url, storage);
    }
    LOGI("Initialize startUrl = %{public}s", startUrl_.c_str());

    Platform::AceContainerSG::RunPage(
        instanceId_, Platform::AceContainerSG::GetContainer(instanceId_)->GeneratePageId(), startUrl_, "");
    LOGI("RunPage UIContentImpl done.");
}

void UIContentImpl::CommonInitialize(OHOS::Rosen::Window* window, const std::string& url, NativeValue* storage)
{
    ACE_FUNCTION_TRACE();
    window_ = window;
    startUrl_ = url;
    CHECK_NULL_VOID(window_);

    InitOnceAceInfo();
    InitAceInfoFromResConfig();

    auto context = context_.lock();
    CHECK_NULL_VOID(context);

    auto abilityContext =
        OHOS::AbilityRuntime::Platform::Context::ConvertTo<OHOS::AbilityRuntime::Platform::AbilityContext>(context);
    std::shared_ptr<OHOS::AppExecFwk::AbilityInfo> info;
    CHECK_NULL_VOID(abilityContext);
    info = abilityContext->GetAbilityInfo();
    if (info) {
        AceApplicationInfo::GetInstance().SetAbilityName(info->name);
    }

    RefPtr<FlutterAssetManager> flutterAssetManager = Referenced::MakeRefPtr<FlutterAssetManager>();
    bool isModelJson = info != nullptr ? info->isModuleJson : false;
    std::string moduleName = info != nullptr ? info->moduleName : "";
    auto appInfo = context->GetApplicationInfo();
    auto bundleName = info != nullptr ? info->bundleName : "";
    std::string pageProfile;
    LOGI("Initialize UIContent isModelJson:%{public}s", isModelJson ? "true" : "false");
    if (isModelJson) {
        std::string hapPath = context->GetBundleCodeDir() + "/" + moduleName + "/";
        LOGI("hapPath:%{public}s", hapPath.c_str());
        // first use hap provider
        if (flutterAssetManager && !hapPath.empty()) {
            auto assetBasePathStr = { std::string(""), std::string("ets/"),
                std::string("ets/share"), std::string("resources/base/profile/") };
            if (flutterAssetManager && !hapPath.empty()) {
                auto assetProvider = AceType::MakeRefPtr<FileAssetProvider>();
                if (assetProvider->Initialize(hapPath, assetBasePathStr)) {
                    LOGD("Push AssetProvider to queue.");
                    flutterAssetManager->PushBack(std::move(assetProvider));
                }
            }
        }
        auto hapInfo = context->GetHapModuleInfo();
        if (hapInfo) {
            pageProfile = hapInfo->pages;
            const std::string profilePrefix = "$profile:";
            if (pageProfile.compare(0, profilePrefix.size(), profilePrefix) == 0) {
                pageProfile = pageProfile.substr(profilePrefix.length()).append(".json");
            }
            LOGI("In stage mode, pageProfile:%{public}s", pageProfile.c_str());
        } else {
            LOGE("In stage mode, can't get hap info.");
        }
    }

    // create container
    if (info) {
        instanceId_ = info->instanceId;
        LOGI("acecontainer init instanceId_:%{public}d", instanceId_);
    }

    auto container = AceType::MakeRefPtr<Platform::AceContainerSG>(instanceId_, FrontendType::DECLARATIVE_JS, context_,
        info,
        std::make_unique<ContentEventCallback>(
            [context = context_] {
                auto sharedContext = context.lock();
                if (!sharedContext) {
                    return;
                }
                auto abilityContext =
                    OHOS::AbilityRuntime::Platform::Context::ConvertTo<OHOS::AbilityRuntime::Platform::AbilityContext>(
                        sharedContext);
                if (abilityContext) {
                    LOGI("callback abilitycontext to terminate self.");
                    abilityContext->TerminateSelf();
                }
            },
            [](const std::string& address) { LOGI("start ability with url = %{private}s", address.c_str()); }),
        true);

    CHECK_NULL_VOID(container);
    AceEngine::Get().AddContainer(instanceId_, container);
    container->SetInstanceName(info->name);
    container->SetHostClassName(info->name);
    if (runtime_) {
        LOGI("settings:setUsingSharedRuntime.");
        container->GetSettings().SetUsingSharedRuntime(true);
        container->SetSharedRuntime(runtime_);
    } else {
        LOGI("settings:set not UsingSharedRuntime.");
        container->GetSettings().SetUsingSharedRuntime(false);
    }
    container->SetPageProfile(pageProfile);
    container->Initialize();
    ContainerScope Initializescope(instanceId_);
    auto front = container->GetFrontend();
    if (front) {
        front->UpdateState(Frontend::State::ON_CREATE);
        front->SetJsMessageDispatcher(container);
    }
    auto aceResCfg = container->GetResourceConfiguration();
    aceResCfg.SetOrientation(SystemProperties::GetDeviceOrientation());
    aceResCfg.SetDensity(SystemProperties::GetResolution());
    aceResCfg.SetDeviceType(SystemProperties::GetDeviceType());
    aceResCfg.SetColorMode(SystemProperties::GetColorMode());
    aceResCfg.SetDeviceAccess(SystemProperties::GetDeviceAccess());
    container->SetResourceConfiguration(aceResCfg);
    container->SetAssetManagerIfNull(flutterAssetManager);
    container->SetBundlePath(context->GetBundleCodeDir());
    container->SetFilesDataPath(context->GetFilesDir());

    std::string hapResPath { "" };
    std::string sysResPath { "" };
    abilityContext->GetResourcePaths(hapResPath, sysResPath);
    container->SetResPaths(hapResPath, sysResPath, SystemProperties::GetColorMode());

    auto aceView = Platform::AceViewSG::CreateView(instanceId_);
    if (!window_) {
        Platform::AceViewSG::SurfaceCreated(aceView, window_);
    }
    // set view
    Platform::AceContainerSG::SetView(aceView, 1.0f, 0, 0, window_);

    // Set sdk version in module json mode
    if (isModelJson) {
        auto pipeline = container->GetPipelineContext();
        if (pipeline && appInfo) {
            LOGI("SetMinPlatformVersion code is %{public}d", appInfo->minCompatibleVersionCode);
            pipeline->SetMinPlatformVersion(appInfo->minCompatibleVersionCode);
        }
    }
}

void UIContentImpl::InitOnceAceInfo()
{
    LOGI("Initialize UIContentImpl start.");
    auto context = context_.lock();
    CHECK_NULL_VOID(context);
    static std::once_flag onceFlag;
    std::call_once(onceFlag, [&context]() {
        LOGI("Initialize for current process.");
        Container::UpdateCurrent(INSTANCE_ID_PLATFORM);
        Platform::CapabilityRegistry::Register();
        AceApplicationInfo::GetInstance().SetProcessName(context->GetBundleName());
        AceApplicationInfo::GetInstance().SetPackageName(context->GetBundleName());
        AceApplicationInfo::GetInstance().SetDataFileDirPath(context->GetFilesDir());
        AceApplicationInfo::GetInstance().SetUid(context->GetApplicationInfo()->uid);
        AceApplicationInfo::GetInstance().SetPid(context->GetApplicationInfo()->pid);
        ImageCache::SetImageCacheFilePath(context->GetCacheDir());
        ImageCache::SetCacheFileInfo();
    });
}

void UIContentImpl::InitAceInfoFromResConfig()
{
    auto context = context_.lock();
    CHECK_NULL_VOID(context);
    std::unique_ptr<Global::Resource::ResConfig> resConfig(Global::Resource::CreateResConfig());
    auto resourceManager = context->GetResourceManager();
    if (resourceManager != nullptr) {
        resourceManager->GetResConfig(*resConfig);
        auto localeInfo = resConfig->GetLocaleInfo();
        Platform::AceApplicationInfoImpl::GetInstance().SetResourceManager(resourceManager);
        if (localeInfo != nullptr) {
            auto language = localeInfo->getLanguage();
            auto region = localeInfo->getCountry();
            auto script = localeInfo->getScript();
            AceApplicationInfo::GetInstance().SetLocale((language == nullptr) ? "" : language,
                (region == nullptr) ? "" : region, (script == nullptr) ? "" : script, "");
        } else {
            LOGI("localeInfo is nullptr, set localeInfo to default");
            AceApplicationInfo::GetInstance().SetLocale("", "", "", "");
        }
        if (resConfig->GetColorMode() == OHOS::Global::Resource::ColorMode::DARK) {
            SystemProperties::SetColorMode(ColorMode::DARK);
            LOGI("UIContent set dark mode");
        } else {
            SystemProperties::SetColorMode(ColorMode::LIGHT);
            LOGI("UIContent set light mode");
        }
        SystemProperties::SetDeviceAccess(
            resConfig->GetInputDevice() == Global::Resource::InputDevice::INPUTDEVICE_POINTINGDEVICE);
    }
}

void UIContentImpl::Foreground()
{
    LOGI("UIContentImpl: window foreground");
    Platform::AceContainerSG::OnShow(instanceId_);
    // set the flag isForegroundCalled to be true
    auto container = Platform::AceContainerSG::GetContainer(instanceId_);
    CHECK_NULL_VOID(container);
    auto pipelineContext = container->GetPipelineContext();
    CHECK_NULL_VOID(pipelineContext);
    pipelineContext->SetForegroundCalled(true);
}

void UIContentImpl::Background()
{
    LOGI("UIContentImpl: window background");
    Platform::AceContainerSG::OnHide(instanceId_);
}

void UIContentImpl::Focus()
{
    LOGI("UIContentImpl: window focus");
    Platform::AceContainerSG::OnActive(instanceId_);
}

void UIContentImpl::UnFocus()
{
    LOGI("UIContentImpl: window unFocus");
    Platform::AceContainerSG::OnInactive(instanceId_);
}

void UIContentImpl::Destroy()
{
    LOGI("UIContentImpl: window destroy");
    auto container = AceEngine::Get().GetContainer(instanceId_);
    CHECK_NULL_VOID(container);
    Platform::AceContainerSG::DestroyContainer(instanceId_);
}

void UIContentImpl::OnNewWant(const OHOS::AAFwk::Want& want)
{
    LOGI("UIContent OnNewWant");
    Platform::AceContainerSG::OnShow(instanceId_);
    std::string params = want.GetStringParam(START_PARAMS_KEY);
    Platform::AceContainerSG::OnNewRequest(instanceId_, params);
}

uint32_t UIContentImpl::GetBackgroundColor()
{
    auto container = Platform::AceContainerSG::GetContainer(instanceId_);
    CHECK_NULL_RETURN(container, 0x000000);
    auto taskExecutor = container->GetTaskExecutor();
    CHECK_NULL_RETURN(taskExecutor, 0x000000);

    ContainerScope scope(instanceId_);
    uint32_t bgColor = 0x000000;
    taskExecutor->PostSyncTask(
        [&bgColor, container]() {
            CHECK_NULL_VOID(container);
            auto pipelineContext = container->GetPipelineContext();
            CHECK_NULL_VOID(pipelineContext);
            bgColor = pipelineContext->GetAppBgColor().GetValue();
        },
        TaskExecutor::TaskType::UI);

    LOGI("UIContentImpl::GetBackgroundColor, value is %{public}u", bgColor);
    return bgColor;
}

void UIContentImpl::SetBackgroundColor(uint32_t color)
{
    LOGI("UIContentImpl: SetBackgroundColor color is %{public}u", color);
    auto container = AceEngine::Get().GetContainer(instanceId_);
    CHECK_NULL_VOID(container);
    
    ContainerScope scope(instanceId_);
    auto taskExecutor = container->GetTaskExecutor();
    CHECK_NULL_VOID(taskExecutor);
    taskExecutor->PostSyncTask(
        [container, bgColor = color]() {
            auto pipelineContext = container->GetPipelineContext();
            CHECK_NULL_VOID(pipelineContext);
            pipelineContext->SetAppBgColor(Color(bgColor));
        },
        TaskExecutor::TaskType::UI);
}

bool UIContentImpl::ProcessBackPressed()
{
    LOGI("UIContentImpl: ProcessBackPressed: Platform::AceContainerSG::OnBackPressed called");
    auto container = AceEngine::Get().GetContainer(instanceId_);
    CHECK_NULL_RETURN_NOLOG(container, false);

    LOGI("UIContentImpl::ProcessBackPressed AceContainerSG");
    if (Platform::AceContainerSG::OnBackPressed(instanceId_)) {
        LOGI("UIContentImpl::ProcessBackPressed AceContainerSG return true");
        return true;
    }
    LOGI("ProcessBackPressed: Platform::AceContainerSG::OnBackPressed return false");
    return false;
}

bool UIContentImpl::ProcessPointerEvent(const std::vector<uint8_t>& data)
{
    LOGI("UIContentImpl::ProcessPointerEvent called");
    auto container = AceEngine::Get().GetContainer(instanceId_);
    CHECK_NULL_RETURN_NOLOG(container, false);

    auto aceView = static_cast<Platform::AceViewSG*>(container->GetView());
    CHECK_NULL_RETURN_NOLOG(aceView, false);

    return aceView->DispatchTouchEvent(data);
}

bool UIContentImpl::ProcessKeyEvent(int32_t keyCode, int32_t keyAction, int32_t repeatTime, int64_t timeStamp,
    int64_t timeStampStart, int32_t metaKey, int32_t sourceDevice, int32_t deviceId)
{
    LOGI("UIContentImpl: OnKeyUp called");
    auto container = AceEngine::Get().GetContainer(instanceId_);
    CHECK_NULL_RETURN_NOLOG(container, false);

    auto aceView = static_cast<Platform::AceViewSG*>(container->GetView());
    CHECK_NULL_RETURN_NOLOG(aceView, false);

    return aceView->DispatchKeyEvent(
        { keyCode, keyAction, repeatTime, timeStamp, timeStampStart, metaKey, sourceDevice, deviceId });
}

void UIContentImpl::UpdateConfiguration(const std::shared_ptr<OHOS::AbilityRuntime::Platform::Configuration>& config)
{
    LOGI("UIContentImpl: UpdateConfiguration called");
}

void UIContentImpl::UpdateViewportConfig(const ViewportConfig& config, OHOS::Rosen::WindowSizeChangeReason reason)
{
    LOGI("UIContentImpl: UpdateViewportConfig %{public}s", config.ToString().c_str());
    SystemProperties::SetResolution(config.Density());
    SystemProperties::SetDeviceOrientation(config.Height() >= config.Width() ? 0 : 1);
    auto container = Platform::AceContainerSG::GetContainer(instanceId_);
    CHECK_NULL_VOID(container);
    auto taskExecutor = container->GetTaskExecutor();
    CHECK_NULL_VOID(taskExecutor);
    taskExecutor->PostTask(
        [config, container, reason]() {
            container->SetWindowPos(config.Left(), config.Top());
            auto pipelineContext = container->GetPipelineContext();
            if (pipelineContext) {
                pipelineContext->SetDisplayWindowRectInfo(
                    Rect(Offset(config.Left(), config.Top()), Size(config.Width(), config.Height())));
            }
            auto aceView = static_cast<Platform::AceViewSG*>(container->GetAceView());
            CHECK_NULL_VOID(aceView);
            Platform::AceViewSG::SetViewportMetrics(aceView, config);
            Platform::AceViewSG::SurfaceChanged(aceView, config.Width(), config.Height(), config.Orientation(),
                static_cast<WindowSizeChangeReason>(reason));
            Platform::AceViewSG::SurfacePositionChanged(aceView, config.Left(), config.Top());
        },
        TaskExecutor::TaskType::PLATFORM);
}

void UIContentImpl::DumpInfo(const std::vector<std::string>& params, std::vector<std::string>& info)
{
    auto container = Platform::AceContainerSG::GetContainer(instanceId_);
    CHECK_NULL_VOID(container);
    container->Dump(params, info);
}

void UIContentImpl::SetNextFrameLayoutCallback(std::function<void()>&& callback)
{
    CHECK_NULL_VOID(callback);
    auto container = Platform::AceContainerSG::GetContainer(instanceId_);
    CHECK_NULL_VOID(container);
    auto pipelineContext = container->GetPipelineContext();
    CHECK_NULL_VOID(pipelineContext);
    pipelineContext->SetNextFrameLayoutCallback(std::move(callback));
}

void UIContentImpl::NotifyMemoryLevel(int32_t level)
{
    LOGI("Receive Memory level notification, level: %{public}d", level);
    auto container = Platform::AceContainerSG::GetContainer(instanceId_);
    CHECK_NULL_VOID(container);
    auto pipelineContext = container->GetPipelineContext();
    CHECK_NULL_VOID(pipelineContext);
    ContainerScope scope(instanceId_);
    pipelineContext->NotifyMemoryLevel(level);
}

void UIContentImpl::NotifySurfaceCreated()
{
    LOGI("UIContentImpl: NotifySurfaceCreated called.");
    auto container = AceEngine::Get().GetContainer(instanceId_);
    CHECK_NULL_VOID(container);
    auto pipeline = container->GetPipelineContext();
    CHECK_NULL_VOID(pipeline);
    ContainerScope scope(instanceId_);
    auto* window = pipeline->GetWindow();
    CHECK_NULL_VOID(window);
    window->Init();
    window->RequestFrame();
}

void UIContentImpl::NotifySurfaceDestroyed()
{
    LOGI("UIContentImpl: NotifySurfaceDestroyed called.");
    auto container = AceEngine::Get().GetContainer(instanceId_);
    CHECK_NULL_VOID(container);
    auto aceView = static_cast<Platform::AceViewSG*>(container->GetView());
    CHECK_NULL_VOID(aceView);
    aceView->NotifySurfaceDestroyed();
}

std::unique_ptr<UIContent> UIContent::Create(OHOS::AbilityRuntime::Platform::Context* context, NativeEngine* runtime)
{
    std::unique_ptr<UIContent> content;
    content.reset(new UIContentImpl(context, runtime));
    return content;
}
} // namespace OHOS::Ace::Platform