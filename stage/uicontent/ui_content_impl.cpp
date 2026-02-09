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

#include "adapter/ios/stage/uicontent/ui_content_impl.h"

#include "ability.h"
#include "ability_context.h"
#include "ability_info.h"
#include "js_runtime_utils.h"
#include "res_config.h"
#include "resource_manager.h"
#include "stage_asset_manager.h"

#include "adapter/ios/entrance/ace_application_info_impl.h"
#include "adapter/ios/entrance/utils.h"
#include "adapter/ios/osal/accessibility_manager_impl.h"
#include "adapter/ios/osal/file_asset_provider.h"
#include "adapter/ios/osal/navigation_route_ios.h"
#include "adapter/ios/osal/page_url_checker_ios.h"
#include "adapter/ios/stage/ability/stage_asset_provider.h"
#include "adapter/ios/stage/uicontent/ace_view_sg.h"
#include "adapter/ios/stage/uicontent/platform_event_callback.h"
#include "base/log/ace_trace.h"
#include "base/log/event_report.h"
#include "base/log/log.h"
#include "base/perfmonitor/perf_monitor.h"
#include "base/subwindow/subwindow_manager.h"
#include "core/common/ace_engine.h"
#include "core/common/ace_view.h"
#include "core/common/asset_manager_impl.h"
#include "core/common/container.h"
#include "core/common/container_scope.h"
#include "core/event/touch_event.h"
#include "core/image/image_file_cache.h"
#include "frameworks/bridge/declarative_frontend/ng/declarative_frontend_ng.h"

namespace OHOS::Ace::Platform {
namespace {
const std::string START_PARAMS_KEY = "__startParams";
const std::string SUBWINDOW_PREFIX = "ARK_APP_SUBWINDOW_";
constexpr int32_t ORIENTATION_PORTRAIT = 1;
constexpr int32_t ORIENTATION_LANDSCAPE = 2;
constexpr double DPI_BASE { 160.0f };
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
        CHECK_NULL_VOID(onFinish_);
        onFinish_();
    }

    void OnStartAbility(const std::string& address) override
    {
        LOGI("UIContent OnStartAbility");
        CHECK_NULL_VOID(onStartAbility_);
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

class OccupiedAreaChangeListener : public OHOS::Rosen::IOccupiedAreaChangeListener {
public:
    explicit OccupiedAreaChangeListener(int32_t instanceId) : instanceId_(instanceId) {}
    ~OccupiedAreaChangeListener() = default;

    void OnSizeChange(const OHOS::Rosen::Rect& rect, const OHOS::Rosen::OccupiedAreaType type)
    {
        Rect keyboardRect = Rect(rect.posX_, rect.posY_, rect.width_, rect.height_);
        if (type == OHOS::Rosen::OccupiedAreaType::TYPE_INPUT) {
            auto container = Platform::AceContainerSG::GetContainer(instanceId_);
            CHECK_NULL_VOID(container);
            auto taskExecutor = container->GetTaskExecutor();
            CHECK_NULL_VOID(taskExecutor);
            ContainerScope scope(instanceId_);
            taskExecutor->PostTask(
                [container, keyboardRect] {
                    auto context = container->GetPipelineContext();
                    CHECK_NULL_VOID(context);
                    context->OnVirtualKeyboardAreaChange(keyboardRect);
                },
                TaskExecutor::TaskType::UI, "ArkUI-XUIContentImplOnSizeChange");
        }
    }

private:
    int32_t instanceId_ = -1;
};

class TouchOutsideListener : public OHOS::Rosen::ITouchOutsideListener {
public:
    explicit TouchOutsideListener(int32_t instanceId) : instanceId_(instanceId) {}
    ~TouchOutsideListener() = default;

    void OnTouchOutside() const
    {
        LOGI("window is touching outside. instance id is %{public}d", instanceId_);
        auto container = Platform::AceContainerSG::GetContainer(instanceId_);
        CHECK_NULL_VOID(container);
        auto taskExecutor = container->GetTaskExecutor();
        CHECK_NULL_VOID(taskExecutor);
        ContainerScope scope(instanceId_);
        taskExecutor->PostTask(
            [instanceId = instanceId_, targetId = targetId_] {
                SubwindowManager::GetInstance()->ClearMenu();
                SubwindowManager::GetInstance()->ClearMenuNG(instanceId, targetId, true, true);
                SubwindowManager::GetInstance()->ClearPopupInSubwindow(instanceId);
            },
            TaskExecutor::TaskType::UI, "ArkUI-XUIContentImplOnTouchOutside");
    }

private:
    int32_t instanceId_ = -1;
    int32_t targetId_ = -1;
};

class AvoidAreaChangedListener : public OHOS::Rosen::IAvoidAreaChangedListener {
public:
    explicit AvoidAreaChangedListener(int32_t instanceId) : instanceId_(instanceId) {}
    ~AvoidAreaChangedListener() = default;
    void OnAvoidAreaChanged(const OHOS::Rosen::AvoidArea avoidArea, OHOS::Rosen::AvoidAreaType type) override
    {
        LOGD("Avoid area changed, type:%{public}d, topRect: avoidArea:x:%{public}d, y:%{public}d, "
             "width:%{public}d, height%{public}d; bottomRect: avoidArea:x:%{public}d, y:%{public}d, "
             "width:%{public}d, height%{public}d",
            type, avoidArea.topRect_.posX_, avoidArea.topRect_.posY_, (int32_t)avoidArea.topRect_.width_,
            (int32_t)avoidArea.topRect_.height_, avoidArea.bottomRect_.posX_, avoidArea.bottomRect_.posY_,
            (int32_t)avoidArea.bottomRect_.width_, (int32_t)avoidArea.bottomRect_.height_);
        auto container = Platform::AceContainerSG::GetContainer(instanceId_);
        CHECK_NULL_VOID(container);
        auto pipeline = container->GetPipelineContext();
        CHECK_NULL_VOID(pipeline);
        auto taskExecutor = container->GetTaskExecutor();
        CHECK_NULL_VOID(taskExecutor);
        if (type == Rosen::AvoidAreaType::TYPE_SYSTEM) {
            systemSafeArea_ = ConvertAvoidArea(avoidArea);
        } else if (type == Rosen::AvoidAreaType::TYPE_NAVIGATION_INDICATOR) {
            navigationBar_ = ConvertAvoidArea(avoidArea);
        }
        auto safeArea = systemSafeArea_;
        auto navSafeArea = navigationBar_;
        ContainerScope scope(instanceId_);
        taskExecutor->PostTask(
            [pipeline, safeArea, navSafeArea, type, avoidArea] {
                if (type == Rosen::AvoidAreaType::TYPE_SYSTEM) {
                    pipeline->UpdateSystemSafeArea(safeArea);
                } else if (type == Rosen::AvoidAreaType::TYPE_NAVIGATION_INDICATOR) {
                    pipeline->UpdateNavSafeArea(navSafeArea);
                }
                // for ui extension component
                pipeline->UpdateOriginAvoidArea(avoidArea, static_cast<uint32_t>(type));
            },
            TaskExecutor::TaskType::UI, "ArkUI-XUIContentImplOnAvoidAreaChanged");
    }

private:
    NG::SafeAreaInsets systemSafeArea_;
    NG::SafeAreaInsets navigationBar_;
    int32_t instanceId_ = -1;
};

UIContentImpl::UIContentImpl(OHOS::AbilityRuntime::Platform::Context* context, NativeEngine* runtime)
    : runtime_(reinterpret_cast<void*>(runtime))
{
    CHECK_NULL_VOID(context);
    const auto& obj = context->GetBindingObject();
    auto ref = obj->Get<NativeReference>();
    void* result = nullptr;
    napi_unwrap(reinterpret_cast<napi_env>(runtime), ref->GetNapiValue(), &result);
    auto weak = static_cast<std::weak_ptr<AbilityRuntime::Platform::Context>*>(result);
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

void UIContentImpl::InitializeByName(OHOS::Rosen::Window* window, const std::string& name, napi_value storage)
{
    InitializeInner(window, name, storage, true);
}

void UIContentImpl::InitializeInner(OHOS::Rosen::Window* window, const std::string& url, napi_value storage, bool isNamedRouter)
{
    if (window) {
        CommonInitialize(window, url, storage);
    }
    LOGI("InitializeInner startUrl = %{public}s", startUrl_.c_str());

    Platform::AceContainerSG::RunPage(
        instanceId_, Platform::AceContainerSG::GetContainer(instanceId_)->GeneratePageId(), startUrl_, "", isNamedRouter);
    LOGI("InitializeInner RunPage UIContentImpl done.");
}

void UIContentImpl::Initialize(OHOS::Rosen::Window* window, const std::string& url, napi_value storage)
{
    InitializeInner(window, url, storage, false);
}

napi_value UIContentImpl::GetUINapiContext()
{
    auto container = Platform::AceContainerSG::GetContainer(instanceId_);
    ContainerScope scope(instanceId_);
    auto frontend = container->GetFrontend();
    CHECK_NULL_RETURN(frontend, nullptr);
    if (frontend->GetType() == FrontendType::DECLARATIVE_JS) {
        auto declarativeFrontend = AceType::DynamicCast<DeclarativeFrontendNG>(frontend);
        CHECK_NULL_RETURN(declarativeFrontend, nullptr);
        return declarativeFrontend->GetContextValue();
    }

    return nullptr;
}

void UpdateFontScale(RefPtr<Platform::AceContainerSG> container,
    const std::shared_ptr<OHOS::AbilityRuntime::Platform::Configuration>& config)
{
    CHECK_NULL_VOID(config);
    CHECK_NULL_VOID(container);
    auto maxAppFontScale = config->GetItem(OHOS::AbilityRuntime::Platform::ConfigurationInner::APP_FONT_MAX_SCALE);
    auto followSystem = config->GetItem(OHOS::AbilityRuntime::Platform::ConfigurationInner::APP_FONT_SIZE_SCALE);
    auto fontScale = config->GetItem(OHOS::AbilityRuntime::Platform::ConfigurationInner::SYSTEM_FONT_SIZE_SCALE);
    if (!maxAppFontScale.empty() && !followSystem.empty() && !fontScale.empty()) {
        container->SetPipelineContextFont(fontScale, maxAppFontScale, followSystem);
    }
}

void UIContentImpl::CommonInitialize(OHOS::Rosen::Window* window, const std::string& url, napi_value storage)
{
    ACE_FUNCTION_TRACE();
    window_ = sptr<OHOS::Rosen::Window>(window);
    startUrl_ = url;
    CHECK_NULL_VOID(window_);

    if (StringUtils::StartWith(window->GetWindowName(), SUBWINDOW_PREFIX)) {
        InitializeSubWindow();
        return;
    }

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

    RefPtr<AssetManagerImpl> assetManagerImpl = Referenced::MakeRefPtr<AssetManagerImpl>();
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
        if (assetManagerImpl && !hapPath.empty()) {
            auto assetProvider = AbilityRuntime::Platform::StageAssetProvider::GetInstance();
            CHECK_NULL_VOID(assetProvider);
            auto dynamicLoadFlag = true;
            std::string moduleNameMark = "/" + moduleName + "/";
            auto allFilePath = assetProvider->GetAllFilePath();
            for (auto& path : allFilePath) {
                if (path.find(moduleNameMark) != std::string::npos) {
                    dynamicLoadFlag = false;
                    break;
                }
            }
            if (dynamicLoadFlag) {
                hapPath = assetProvider->GetAppDataModuleDir() + "/" + moduleName + "/";
            }

            auto assetBasePathStr = { std::string(""), std::string("ets/"), std::string("ets/share"),
                std::string("resources/base/profile/") };
            if (assetManagerImpl && !hapPath.empty()) {
                auto assetProvider = AceType::MakeRefPtr<FileAssetProvider>();
                if (assetProvider->Initialize(hapPath, assetBasePathStr)) {
                    LOGD("Push AssetProvider to queue.");
                    assetManagerImpl->PushBack(std::move(assetProvider));
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
        instanceId_ = window->IsSubWindow() ? window->GetWindowId() : info->instanceId;
        LOGI("acecontainer init instanceId_:%{public}d", instanceId_);
        Ace::Platform::UIContent::AddUIContent(instanceId_, this);
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
    ContainerScope::Add(instanceId_);
    container->SetWindowName(window_->GetWindowName());
    container->SetWindowId(window_->GetWindowId());
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

    std::unique_ptr<Global::Resource::ResConfig> resConfig(Global::Resource::CreateResConfig());
    auto resourceManager = context->GetResourceManager();
    ColorMode colorMode = ColorMode::LIGHT;
    if (resourceManager != nullptr) {
        resourceManager->GetResConfig(*resConfig);
        if (resConfig->GetColorMode() == OHOS::Global::Resource::ColorMode::DARK) {
            colorMode = ColorMode::DARK;
            LOGI("UIContent set dark mode");
        } else {
            colorMode = ColorMode::LIGHT;
            LOGI("UIContent set light mode");
        }
    }
    container->SetColorMode(colorMode);

    container->Initialize();
    ContainerScope Initializescope(instanceId_);
    auto front = container->GetFrontend();
    if (front) {
        front->UpdateState(Frontend::State::ON_CREATE);
        front->SetJsMessageDispatcher(container);
    }

    double density = SystemProperties::GetResolution();
    auto aceResCfg = container->GetResourceConfiguration();
    aceResCfg.SetOrientation(SystemProperties::GetDeviceOrientation());
    aceResCfg.SetDensity(density);
    aceResCfg.SetDeviceType(SystemProperties::GetDeviceType());
    aceResCfg.SetColorMode(container->GetColorMode());
    aceResCfg.SetDeviceAccess(SystemProperties::GetDeviceAccess());
    container->SetResourceConfiguration(aceResCfg);
    container->SetAssetManagerIfNull(assetManagerImpl);
    container->SetBundlePath(context->GetBundleCodeDir());
    container->SetFilesDataPath(context->GetFilesDir());
    container->SetModuleName(moduleName);
    container->SetIsModule(info->compileMode == AppExecFwk::CompileMode::ES_MODULE);
    container->SetPageUrlChecker(AceType::MakeRefPtr<PageUrlCheckerIos>());
    container->SetNavigationRoute(AceType::MakeRefPtr<NavigationRouteIos>(context->GetBundleName()));

    std::vector<std::string> resourcePaths;
    std::string sysResPath { "" };
    abilityContext->GetResourcePaths(resourcePaths, sysResPath);
    container->SetResPaths(resourcePaths, sysResPath, container->GetColorMode());

    auto aceView = Platform::AceViewSG::CreateView(instanceId_);
    if (!window_) {
        Platform::AceViewSG::SurfaceCreated(aceView, window_);
    }
    // set view
    Platform::AceContainerSG::SetView(aceView, density, 0, 0, window_);
    auto config = context->GetConfiguration();
    UpdateFontScale(container, config);
    if (window_) {
        occupiedAreaChangeListener_ = new OccupiedAreaChangeListener(instanceId_);
        window_->RegisterOccupiedAreaChangeListener(occupiedAreaChangeListener_);
    }

    if (appInfo) {
        AceApplicationInfo::GetInstance().SetApiTargetVersion(static_cast<int32_t>(appInfo->apiTargetVersion));
        container->SetApiTargetVersion(appInfo->apiTargetVersion);
    }

    // Set sdk version in module json mode
    if (isModelJson) {
        auto pipeline = container->GetPipelineContext();
        if (pipeline && appInfo) {
            LOGI("SetMinPlatformVersion code is %{public}d", appInfo->apiCompatibleVersion);
            pipeline->SetMinPlatformVersion(appInfo->apiCompatibleVersion);
        }
    }

    if (runtime_) {
        auto nativeEngine = reinterpret_cast<NativeEngine*>(runtime_);
        if (!storage) {
            container->SetLocalStorage(nullptr, context->GetBindingObject()->Get<NativeReference>());
        } else {
            auto env = reinterpret_cast<napi_env>(nativeEngine);
            napi_ref ref = nullptr;
            napi_create_reference(env, storage, 1, &ref);
            container->SetLocalStorage(
                reinterpret_cast<NativeReference*>(ref), context->GetBindingObject()->Get<NativeReference>());
        }
    }

    InitializeSafeArea(container);
}


void UIContentImpl::InitializeSafeArea(const RefPtr<Platform::AceContainerSG>& container)
{
    constexpr static int32_t PLATFORM_VERSION_TEN = 10;
    auto pipeline = container->GetPipelineContext();
    if (pipeline && pipeline->GetMinPlatformVersion() >= PLATFORM_VERSION_TEN) {
        avoidAreaChangedListener_ = new AvoidAreaChangedListener(instanceId_);
        window_->RegisterAvoidAreaChangeListener(avoidAreaChangedListener_);
    }
}

NG::SafeAreaInsets UIContentImpl::GetViewSafeAreaByType(OHOS::Rosen::AvoidAreaType type)
{
    CHECK_NULL_RETURN(window_, {});
    Rosen::AvoidArea avoidArea;
    Rosen::WMError ret = window_->GetAvoidAreaByType(type, avoidArea);
    if (ret == Rosen::WMError::WM_OK) {
        auto safeAreaInsets = ConvertAvoidArea(avoidArea);
        LOGI("SafeArea get success, area type is:%{public}d insets area is:%{public}s", static_cast<int32_t>(type),
            safeAreaInsets.ToString().c_str());
        return safeAreaInsets;
    }
    return {};
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
        AceApplicationInfo::GetInstance().SetProcessName(context->GetBundleName());
        AceApplicationInfo::GetInstance().SetPackageName(context->GetBundleName());
        AceApplicationInfo::GetInstance().SetDataFileDirPath(context->GetFilesDir());
        AceApplicationInfo::GetInstance().SetUid(context->GetApplicationInfo()->uid);
        AceApplicationInfo::GetInstance().SetPid(context->GetApplicationInfo()->pid);
        ImageFileCache::GetInstance().SetImageCacheFilePath(context->GetCacheDir());
        ImageFileCache::GetInstance().SetCacheFileInfo();
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

        SystemProperties::SetDeviceAccess(
            resConfig->GetInputDevice() == Global::Resource::InputDevice::INPUTDEVICE_POINTINGDEVICE);
    }

    auto config = context->GetConfiguration();
    if (config) {
        auto direction = config->GetItem(OHOS::AbilityRuntime::Platform::ConfigurationInner::APPLICATION_DIRECTION);
        auto densityDpi = config->GetItem(OHOS::AbilityRuntime::Platform::ConfigurationInner::APPLICATION_DENSITYDPI);
        auto systemFont = config->GetItem(OHOS::AbilityRuntime::Platform::ConfigurationInner::APP_FONT_SIZE_SCALE);
        auto maxFontScale = config->GetItem(OHOS::AbilityRuntime::Platform::ConfigurationInner::APP_FONT_MAX_SCALE);
        auto fontScale = config->GetItem(OHOS::AbilityRuntime::Platform::ConfigurationInner::SYSTEM_FONT_SIZE_SCALE);
        if (!fontScale.empty()) {
            float fontScaleValue = StringUtils::StringToFloat(fontScale);
            if (!maxFontScale.empty()) {
                float maxFontScaleValue = StringUtils::StringToFloat(maxFontScale);
                fontScaleValue = std::min(fontScaleValue, maxFontScaleValue);
            }
            SystemProperties::SetFontScale(fontScaleValue);
        }
        LOGI("UIContent set GetScreenDensity dpi=%{public}s", densityDpi.c_str());
        if (!densityDpi.empty()) {
            double density = std::stoi(densityDpi) / DPI_BASE;
            SystemProperties::SetResolution(density);
        }
        if (direction == OHOS::AbilityRuntime::Platform::ConfigurationInner::DIRECTION_VERTICAL) {
            SystemProperties::SetDeviceOrientation(ORIENTATION_PORTRAIT);
        } else if (direction == OHOS::AbilityRuntime::Platform::ConfigurationInner::DIRECTION_HORIZONTAL) {
            SystemProperties::SetDeviceOrientation(ORIENTATION_LANDSCAPE);
        } else {
            LOGI("UIContent Direction get fail");
        }
    }
}

void UIContentImpl::Foreground()
{
    LOGI("UIContentImpl: window foreground");
    PerfMonitor::GetPerfMonitor()->SetAppStartStatus();
    ContainerScope::UpdateRecentForeground(instanceId_);
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
    ContainerScope::UpdateRecentActive(instanceId_);
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
    ContainerScope::RemoveAndCheck(instanceId_);
}

void UIContentImpl::OnNewWant(const OHOS::AAFwk::Want& want)
{
    LOGI("UIContent OnNewWant");
    Platform::AceContainerSG::OnShow(instanceId_);
    std::string params = want.GetStringParam(START_PARAMS_KEY);
    Platform::AceContainerSG::OnNewRequest(instanceId_, params);
}

void UIContentImpl::Finish()
{
    LOGI("UIContent Finish");
    auto container = Platform::AceContainerSG::GetContainer(instanceId_);
    CHECK_NULL_VOID(container);
    container->OnFinish();
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
        TaskExecutor::TaskType::UI, "ArkUI-XUIContentImplGetBackgroundColor");

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
        TaskExecutor::TaskType::UI, "ArkUI-XUIContentImplSetBackgroundColor");
}

bool UIContentImpl::ProcessBackPressed()
{
    LOGI("UIContentImpl: ProcessBackPressed: Platform::AceContainerSG::OnBackPressed called");
    auto container = AceEngine::Get().GetContainer(instanceId_);
    CHECK_NULL_RETURN(container, false);

    LOGI("UIContentImpl::ProcessBackPressed AceContainerSG");
    if (Platform::AceContainerSG::OnBackPressed(instanceId_)) {
        LOGI("UIContentImpl::ProcessBackPressed AceContainerSG return true");
        return true;
    }
    LOGI("ProcessBackPressed: Platform::AceContainerSG::OnBackPressed return false");
    return false;
}

bool UIContentImpl::ProcessBasicEvent(const std::vector<TouchEvent>& touchEvents)
{
    auto container = AceEngine::Get().GetContainer(instanceId_);
    CHECK_NULL_RETURN(container, false);

    auto aceView = static_cast<Platform::AceViewSG*>(container->GetView());
    CHECK_NULL_RETURN(aceView, false);

    return aceView->DispatchBasicEvent(touchEvents);
}

bool UIContentImpl::ProcessPointerEvent(const std::shared_ptr<OHOS::MMI::PointerEvent>& pointerEvent)
{
    LOGI("UIContentImpl::ProcessPointerEvent called");
    auto container = AceEngine::Get().GetContainer(instanceId_);
    CHECK_NULL_RETURN(container, false);

    auto aceView = static_cast<Platform::AceViewSG*>(container->GetView());
    CHECK_NULL_RETURN(aceView, false);

    return aceView->DispatchTouchEvent(pointerEvent);
}

bool UIContentImpl::ProcessPointerEventWithCallback(
    const std::shared_ptr<OHOS::MMI::PointerEvent>& pointerEvent, const std::function<void()>& callback)
{
    LOGI("UIContentImpl::ProcessPointerEvent called");
    auto container = AceEngine::Get().GetContainer(instanceId_);
    CHECK_NULL_RETURN(container, false);

    auto aceView = static_cast<Platform::AceViewSG*>(container->GetView());
    CHECK_NULL_RETURN(aceView, false);

    return aceView->DispatchTouchEvent(pointerEvent, nullptr, callback);
}

bool UIContentImpl::ProcessPointerEventTargetHitTest(const std::shared_ptr<OHOS::MMI::PointerEvent>& pointerEvent, const std::string& target)
{
    auto container = AceEngine::Get().GetContainer(instanceId_);
    CHECK_NULL_RETURN(container, false);
    auto aceView = static_cast<Platform::AceViewSG*>(container->GetView());
    bool isTargetTouched = aceView->DispatchTouchEventTargetHitTest(pointerEvent, target);
    return isTargetTouched;
}

bool UIContentImpl::ProcessKeyEvent(int32_t keyCode, int32_t keyAction, int32_t repeatTime, int64_t timeStamp,
    int64_t timeStampStart, int32_t metaKey, int32_t sourceDevice, int32_t deviceId, std::string msg)
{
    LOGI("UIContentImpl: OnKeyUp called");
    auto container = AceEngine::Get().GetContainer(instanceId_);
    CHECK_NULL_RETURN(container, false);

    auto aceView = static_cast<Platform::AceViewSG*>(container->GetView());
    CHECK_NULL_RETURN(aceView, false);

    return aceView->DispatchKeyEvent(
        { keyCode, keyAction, repeatTime, timeStamp, timeStampStart, metaKey, sourceDevice, deviceId, msg });
}

void UIContentImpl::UpdateConfiguration(const std::shared_ptr<OHOS::AbilityRuntime::Platform::Configuration>& config)
{
    LOGI("UIContentImpl: UpdateConfiguration called");
    CHECK_NULL_VOID(config);
    auto container = Platform::AceContainerSG::GetContainer(instanceId_);
    CHECK_NULL_VOID(container);
    UpdateFontScale(container, config);
    auto taskExecutor = container->GetTaskExecutor();
    CHECK_NULL_VOID(taskExecutor);
    auto colorMode = config->GetItem(OHOS::AbilityRuntime::Platform::ConfigurationInner::SYSTEM_COLORMODE);
    auto direction = config->GetItem(OHOS::AbilityRuntime::Platform::ConfigurationInner::APPLICATION_DIRECTION);
    auto densityDpi = config->GetItem(OHOS::AbilityRuntime::Platform::ConfigurationInner::APPLICATION_DENSITYDPI);
    auto languageTag = config->GetItem(OHOS::AbilityRuntime::Platform::ConfigurationInner::APPLICATION_LANGUAGE);
    auto fontFamily = config->GetItem(OHOS::AbilityRuntime::Platform::ConfigurationInner::APPLICATION_FONT);
    auto fontScale = config->GetItem(OHOS::AbilityRuntime::Platform::ConfigurationInner::SYSTEM_FONT_SIZE_SCALE);
    auto maxAppFontScale = config->GetItem(OHOS::AbilityRuntime::Platform::ConfigurationInner::APP_FONT_MAX_SCALE);
    auto followSystem = config->GetItem(OHOS::AbilityRuntime::Platform::ConfigurationInner::APP_FONT_SIZE_SCALE);
    auto configStr = colorMode + ";" + direction + ";" + densityDpi + ";" + languageTag + ";" + fontFamily + ";" +
        fontScale + ";" + maxAppFontScale + ";" + followSystem + ";";
    if (lastConfig_ != configStr) {
        lastConfig_ = configStr;
        taskExecutor->PostTask(
            [weakContainer = WeakPtr<Platform::AceContainerSG>(container),
             colorMode, direction, densityDpi, languageTag, fontFamily, fontScale]() {
                auto container = weakContainer.Upgrade();
                CHECK_NULL_VOID(container);
                Platform::ParsedConfig parsedConfig;
                parsedConfig.colorMode = colorMode;
                parsedConfig.direction = direction;
                parsedConfig.densitydpi = densityDpi;
                parsedConfig.languageTag = languageTag;
                parsedConfig.fontFamily = fontFamily;
                parsedConfig.fontScale = fontScale;
                container->UpdateConfiguration(parsedConfig);
                auto context = container->GetPipelineContext();
                CHECK_NULL_VOID(context);
                AccessibilityEvent event;
                event.type = AccessibilityEventType::CHANGE;
                event.windowId = context->GetWindowId();
                event.windowChangeTypes = WINDOW_UPDATE_INVALID;
                context->SendEventToAccessibility(event);
            },
            TaskExecutor::TaskType::UI, "ArkUI-XUIContentImplUpdateConfiguration");
    }
}

bool IsNeedAvoidWindowMode(OHOS::Rosen::Window* rsWindow)
{
    return (rsWindow->GetMode() == Rosen::WindowMode::WINDOW_MODE_FLOATING ||
               rsWindow->GetMode() == Rosen::WindowMode::WINDOW_MODE_SPLIT_PRIMARY ||
               rsWindow->GetMode() == Rosen::WindowMode::WINDOW_MODE_SPLIT_SECONDARY) &&
           (SystemProperties::GetDeviceType() == DeviceType::PHONE ||
               SystemProperties::GetDeviceType() == DeviceType::TABLET);
}

void UIContentImpl::UpdateViewportConfig(const ViewportConfig& config, OHOS::Rosen::WindowSizeChangeReason reason)
{
    LOGI("UIContentImpl: UpdateViewportConfig %{public}s", config.ToString().c_str());
    auto orientation = config.Height() >= config.Width() ? ORIENTATION_PORTRAIT : ORIENTATION_LANDSCAPE;
    SystemProperties::InitDeviceInfo(config.Width(), config.Height(), orientation, config.Density(), false);
    SystemProperties::SetResolution(config.Density());
    SystemProperties::SetDeviceOrientation(
        config.Height() >= config.Width() ? ORIENTATION_PORTRAIT : ORIENTATION_LANDSCAPE);
    auto container = Platform::AceContainerSG::GetContainer(instanceId_);
    CHECK_NULL_VOID(container);
    auto taskExecutor = container->GetTaskExecutor();
    CHECK_NULL_VOID(taskExecutor);
    taskExecutor->PostTask(
        [config, container, reason, rsWindow = window_]() {
            container->SetWindowPos(config.Left(), config.Top());
            auto pipelineContext = container->GetPipelineContext();
            if (pipelineContext) {
                pipelineContext->SetDisplayWindowRectInfo(
                    Rect(Offset(config.Left(), config.Top()), Size(config.Width(), config.Height())));
                if (rsWindow) {
                    pipelineContext->SetIsLayoutFullScreen(
                        rsWindow->GetMode() == Rosen::WindowMode::WINDOW_MODE_FULLSCREEN);
                    auto isNeedAvoidWindowMode = IsNeedAvoidWindowMode(rsWindow);
                    pipelineContext->SetIsNeedAvoidWindow(isNeedAvoidWindowMode);
                }
            }
            auto aceView = static_cast<Platform::AceViewSG*>(container->GetAceViewEx());
            CHECK_NULL_VOID(aceView);
            Platform::AceViewSG::SetViewportMetrics(aceView, config);
            Platform::AceViewSG::SurfaceChanged(aceView, config.Width(), config.Height(), config.Orientation(),
                static_cast<WindowSizeChangeReason>(reason));
            Platform::AceViewSG::SurfacePositionChanged(aceView, config.Left(), config.Top());
        },
        TaskExecutor::TaskType::PLATFORM, "ArkUI-XUIContentImplUpdateViewportConfig");
}

// Control filtering
bool UIContentImpl::GetAllComponents(NodeId nodeID, OHOS::Ace::Platform::ComponentInfo& components)
{
    LOGI("UIContentImpl::GetAllComponents enter.");
    auto container = Platform::AceContainerSG::GetContainer(instanceId_);
    CHECK_NULL_RETURN(container, false);
    if (container->GetPipelineContext()) {
        auto accessibilityManager = container->GetPipelineContext()->GetAccessibilityManager();
        if (accessibilityManager) {
            auto accessibilityNodeManager =
                AceType::DynamicCast<OHOS::Ace::Framework::AccessibilityNodeManager>(accessibilityManager);
            auto accessibilityManagerImpl =
                AceType::DynamicCast<OHOS::Ace::Framework::AccessibilityManagerImpl>(accessibilityNodeManager);
            auto ret = accessibilityManagerImpl->GetAllComponents(nodeID, components);
            LOGI("UIContentImpl::GetAllComponents ret = %d", ret);
            return ret;
        }
    }
    LOGI("UIContentImpl::GetAllComponents exit.");
    return false;
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
    window->InitArkUI_X();
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

void UIContentImpl::InitializeSubWindow()
{
    CHECK_NULL_VOID(window_);
    LOGI("The window name is %{public}s", window_->GetWindowName().c_str());
    instanceId_ = window_->GetWindowId();
    std::weak_ptr<OHOS::AppExecFwk::AbilityInfo> abilityInfo;
    std::weak_ptr<OHOS::AbilityRuntime::Platform::Context> runtimeContext;

    auto container = AceType::MakeRefPtr<Platform::AceContainerSG>(instanceId_, FrontendType::DECLARATIVE_JS,
        runtimeContext, abilityInfo, std::make_unique<ContentEventCallback>([] {
            // Sub-window ,just return.
            LOGI("Content event callback");
        }),
        false, true);

    AceEngine::Get().AddContainer(instanceId_, container);
    touchOutsideListener_ = new TouchOutsideListener(instanceId_);
    window_->RegisterTouchOutsideListener(touchOutsideListener_);
    occupiedAreaChangeListener_ = new OccupiedAreaChangeListener(instanceId_);
    window_->RegisterOccupiedAreaChangeListener(occupiedAreaChangeListener_);
}
} // namespace OHOS::Ace::Platform
