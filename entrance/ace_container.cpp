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

#include "adapter/ios/entrance/ace_container.h"

#include <cstring>
#include <string>

#ifdef NG_BUILD
#include "ace_shell/shell/common/window_manager.h"
#else
#include "third_party/flutter/build/lib/ui/ui_javascript_state.h"
#endif
#include "third_party/quickjs/cutils.h"

#include "adapter/ios/entrance/ace_application_info_impl.h"
#include "adapter/ios/osal/dir_asset_provider.h"
#include "base/log/ace_trace.h"
#include "base/log/event_report.h"
#include "base/log/log.h"
#include "base/utils/system_properties.h"
#include "base/utils/utils.h"
#include "core/common/ace_engine.h"
#include "core/common/ace_view.h"
#include "core/common/container_scope.h"
#include "core/common/flutter/flutter_asset_manager.h"
#include "core/common/flutter/flutter_task_executor.h"
#include "core/common/platform_bridge.h"
#include "core/common/platform_window.h"
#include "core/common/text_field_manager.h"
#include "core/common/watch_dog.h"
#include "core/common/window.h"
#include "core/components/theme/app_theme.h"
#include "core/components/theme/theme_constants.h"
#include "core/components/theme/theme_manager.h"
#include "core/pipeline/base/element.h"
#ifdef NG_BUILD
#include "core/pipeline_ng/pipeline_context.h"
#else
#include "core/pipeline/pipeline_context.h"
#endif
#include "frameworks/bridge/card_frontend/card_frontend.h"
#include "frameworks/bridge/common/utils/engine_helper.h"
#include "frameworks/bridge/declarative_frontend/declarative_frontend.h"
#include "frameworks/bridge/js_frontend/engine/common/js_engine_loader.h"
#include "frameworks/bridge/js_frontend/engine/quickjs/qjs_utils.h"
#include "frameworks/bridge/js_frontend/js_frontend.h"

const char* localJsFrameworkPath_;

namespace OHOS::Ace::Platform {

constexpr int32_t UNUSED_PAGE_ID = 1;
constexpr char ASSET_PATH_SHARE[] = "share";
constexpr char DELIMITER[] = "/";

AceContainer::AceContainer(int32_t instanceId, FrontendType type) : instanceId_(instanceId), type_(type)
{
    LOGI("AceContainer::AceContainer");
#ifdef NG_BUILD
        LOGD("AceContainer created use new pipeline");
    SetUseNewPipeline();
#endif
    auto flutterTaskExecutor = Referenced::MakeRefPtr<FlutterTaskExecutor>();
    flutterTaskExecutor->InitPlatformThread();

    if (type_ == FrontendType::DECLARATIVE_JS) {
        GetSettings().useUIAsJSThread = true;
    } else {
        flutterTaskExecutor->InitJsThread();
    }
    taskExecutor_ = flutterTaskExecutor;
}

RefPtr<AceContainer> AceContainer::GetContainerInstance(int32_t instanceId)
{
    auto container = AceType::DynamicCast<AceContainer>(AceEngine::Get().GetContainer(instanceId));
    return container;
}

void AceContainer::CreateContainer(int32_t instanceId, FrontendType type)
{
    LOGI("AceContainer::CreateContainer");
    auto aceContainer = AceType::MakeRefPtr<AceContainer>(instanceId, type);
    AceEngine::Get().AddContainer(aceContainer->GetInstanceId(), aceContainer);
    aceContainer->Initialize();
    ContainerScope scope(instanceId);
    auto front = aceContainer->GetFrontend();
    if (front) {
        front->UpdateState(Frontend::State::ON_CREATE);
        front->SetJsMessageDispatcher(aceContainer);
    }
}

void AceContainer::Initialize()
{
    ContainerScope scope(instanceId_);
    LOGI("AceContainer::Initialize");
    if (type_ != FrontendType::DECLARATIVE_JS) {
        InitializeFrontend();
    }
}

void AceContainer::Destroy()
{
    ContainerScope scope(instanceId_);
    EngineHelper::RemoveEngine(instanceId_);
}

bool AceContainer::RunPage(int32_t instanceId, int32_t pageId, const std::string& url, const std::string& params)
{
    ACE_FUNCTION_TRACE();
    auto container = AceEngine::Get().GetContainer(instanceId);
    if (!container) {
        return false;
    }

    ContainerScope scope(instanceId);

    auto front = container->GetFrontend();
    if (front) {
        LOGI("RunPage url=[%{private}s]", url.c_str());
        front->RunPage(pageId, url, params);
        return true;
    }
    return false;
}

bool AceContainer::Dump(const std::vector<std::string>& params)
{
    ContainerScope scope(instanceId_);
    if (aceView_ && aceView_->Dump(params)) {
        return true;
    }

    if (pipelineContext_) {
        pipelineContext_->Dump(params);
        return true;
    }
    return false;
}

void AceContainer::InitializeFrontend()
{
    LOGI("AceContainer::InitializeFrontend");
    if (type_ == FrontendType::JS) {
#ifdef NG_BUILD
        LOGE("NG veriosn not support js frontend yet!");
#else
        frontend_ = Frontend::Create();
        auto jsFrontend = AceType::DynamicCast<JsFrontend>(frontend_);

        // TODO: set locale in ViewController when get system locale info
        AceApplicationInfo::GetInstance().SetLocale("zh", "CN", "", "");
        auto jsEngine = Framework::JsEngineLoader::Get().CreateJsEngine(GetInstanceId());
        jsFrontend->SetJsEngine(jsEngine);
        EngineHelper::AddEngine(instanceId_, jsEngine);
        jsFrontend->SetNeedDebugBreakPoint(AceApplicationInfo::GetInstance().IsNeedDebugBreakPoint());
        jsFrontend->SetDebugVersion(AceApplicationInfo::GetInstance().IsDebugVersion());
#endif
    } else if (type_ == FrontendType::DECLARATIVE_JS) {
        frontend_ = AceType::MakeRefPtr<DeclarativeFrontend>();
        auto declarativeFrontend = AceType::DynamicCast<DeclarativeFrontend>(frontend_);
        // TODO: set locale in ViewController when get system locale info
        AceApplicationInfo::GetInstance().SetLocale("zh", "CN", "", "");
        auto& loader = Framework::JsEngineLoader::GetDeclarative(nullptr);
        auto jsEngine = loader.CreateJsEngine(instanceId_);
        declarativeFrontend->SetJsEngine(jsEngine);
        EngineHelper::AddEngine(instanceId_, jsEngine);
        declarativeFrontend->SetNeedDebugBreakPoint(AceApplicationInfo::GetInstance().IsNeedDebugBreakPoint());
        declarativeFrontend->SetDebugVersion(AceApplicationInfo::GetInstance().IsDebugVersion());
    }
    ACE_DCHECK(frontend_);
    frontend_->Initialize(type_, taskExecutor_);
    if (assetManager_) {
        frontend_->SetAssetManager(assetManager_);
    }
}

void AceContainer::InitializeCallback()
{
    ACE_FUNCTION_TRACE();
    auto weak = AceType::WeakClaim(AceType::RawPtr(pipelineContext_));
    auto&& touchEventCallback = [weak, id = instanceId_](
                                    const TouchEvent& event, const std::function<void()>& markProcess) {
        ContainerScope scope(id);
        auto context = weak.Upgrade();
        if (context == nullptr) {
            LOGE("context is nullptr");
            return;
        }
        context->GetTaskExecutor()->PostTask(
            [context, event]() { context->OnTouchEvent(event); }, TaskExecutor::TaskType::UI);
    };
    aceView_->RegisterTouchEventCallback(touchEventCallback);

    auto&& keyEventCallback = [weak, id = instanceId_](const KeyEvent& event) {
        ContainerScope scope(id);
        auto context = weak.Upgrade();
        if (context == nullptr) {
            LOGE("context is nullptr");
            return false;
        }
        bool result = false;
        context->GetTaskExecutor()->PostSyncTask(
            [context, event, &result]() { result = context->OnKeyEvent(event); }, TaskExecutor::TaskType::UI);
        return result;
    };
    aceView_->RegisterKeyEventCallback(keyEventCallback);

    auto&& mouseEventCallback = [weak, id = instanceId_](
                                    const MouseEvent& event, const std::function<void()>& markProcess) {
        ContainerScope scope(id);
        auto context = weak.Upgrade();
        if (context == nullptr) {
            LOGE("context is nullptr");
            return;
        }
        context->GetTaskExecutor()->PostTask(
            [context, event]() { context->OnMouseEvent(event); }, TaskExecutor::TaskType::UI);
    };
    aceView_->RegisterMouseEventCallback(mouseEventCallback);

    auto&& axisEventCallback = [weak, id = instanceId_](
                                   const AxisEvent& event, const std::function<void()>& markProcess) {
        ContainerScope scope(id);
        auto context = weak.Upgrade();
        if (context == nullptr) {
            LOGE("context is nullptr");
            return;
        }
        context->GetTaskExecutor()->PostTask(
            [context, event]() { context->OnAxisEvent(event); }, TaskExecutor::TaskType::UI);
    };
    aceView_->RegisterAxisEventCallback(axisEventCallback);

    auto&& rotationEventCallback = [weak, id = instanceId_](const RotationEvent& event) {
        ContainerScope scope(id);
        auto context = weak.Upgrade();
        if (context == nullptr) {
            LOGE("context is nullptr");
            return false;
        }
        bool result = false;
        context->GetTaskExecutor()->PostSyncTask(
            [context, event, &result]() { result = context->OnRotationEvent(event); }, TaskExecutor::TaskType::UI);
        return result;
    };
    aceView_->RegisterRotationEventCallback(rotationEventCallback);

    auto&& viewChangeCallback = [weak, id = instanceId_](int32_t width, int32_t height, WindowSizeChangeReason type) {
        ContainerScope scope(id);
        auto context = weak.Upgrade();
        if (context == nullptr) {
            LOGE("context is nullptr");
            return;
        }
        ACE_SCOPED_TRACE("ViewChangeCallback(%d, %d)", width, height);
        context->GetTaskExecutor()->PostTask(
            [context, width, height]() { context->OnSurfaceChanged(width, height); }, TaskExecutor::TaskType::UI);
    };
    aceView_->RegisterViewChangeCallback(viewChangeCallback);

    auto&& densityChangeCallback = [weak, id = instanceId_](double density) {
        ContainerScope scope(id);
        auto context = weak.Upgrade();
        if (context == nullptr) {
            LOGE("context is nullptr");
            return;
        }
        ACE_SCOPED_TRACE("DensityChangeCallback(%lf)", density);
        context->GetTaskExecutor()->PostTask(
            [context, density]() { context->OnSurfaceDensityChanged(density); }, TaskExecutor::TaskType::UI);
    };
    aceView_->RegisterDensityChangeCallback(densityChangeCallback);

    auto&& systemBarHeightChangeCallback = [weak, id = instanceId_](double statusBar, double navigationBar) {
        ContainerScope scope(id);
        auto context = weak.Upgrade();
        if (context == nullptr) {
            LOGE("context is nullptr");
            return;
        }
        ACE_SCOPED_TRACE("SystemBarHeightChangeCallback(%lf, %lf)", statusBar, navigationBar);
        context->GetTaskExecutor()->PostTask(
            [context, statusBar, navigationBar]() { context->OnSystemBarHeightChanged(statusBar, navigationBar); },
            TaskExecutor::TaskType::UI);
    };
    aceView_->RegisterSystemBarHeightChangeCallback(systemBarHeightChangeCallback);

    auto&& surfaceDestroyCallback = [weak, id = instanceId_]() {
        ContainerScope scope(id);
        auto context = weak.Upgrade();
        if (context == nullptr) {
            LOGE("context is nullptr");
            return;
        }
        context->GetTaskExecutor()->PostTask(
            [context]() { context->OnSurfaceDestroyed(); }, TaskExecutor::TaskType::UI);
    };
    aceView_->RegisterSurfaceDestroyCallback(surfaceDestroyCallback);

    auto&& idleCallback = [weak, id = instanceId_](int64_t deadline) {
        ContainerScope scope(id);
        auto context = weak.Upgrade();
        if (context == nullptr) {
            LOGE("context is nullptr");
            return;
        }
        context->GetTaskExecutor()->PostTask(
            [context, deadline]() { context->OnIdle(deadline); }, TaskExecutor::TaskType::UI);
    };
    aceView_->RegisterIdleCallback(idleCallback);
}

void AceContainer::Dispatch(
    const std::string& group, std::vector<uint8_t>&& data, int32_t id, bool replyToComponent) const
{}

void AceContainer::DispatchPluginError(int32_t callbackId, int32_t errorCode, std::string&& errorMessage) const {}

void AceContainer::AddAssetPath(
    int32_t instanceId, const std::string& packagePath, const std::vector<std::string>& paths)
{
    auto container = AceType::DynamicCast<AceContainer>(AceEngine::Get().GetContainer(instanceId));
    if (!container) {
        return;
    }

    for (const auto& path : paths) {
        RefPtr<FlutterAssetManager> flutterAssetManager;
        if (container->assetManager_) {
            flutterAssetManager = AceType::DynamicCast<FlutterAssetManager>(container->assetManager_);
        } else {
            flutterAssetManager = Referenced::MakeRefPtr<FlutterAssetManager>();
            container->SetAssetManager(flutterAssetManager);
        }
        if (flutterAssetManager) {
            LOGD("Current path is: %s", path.c_str());
#ifdef NG_BUILD
            auto dirAssetProvider = AceType::MakeRefPtr<DirAssetProvider>(
                    path, std::make_unique<flutter::DirectoryAssetBundle>(
                            fml::OpenDirectory(path.c_str(), false, fml::FilePermission::kRead),true));
#else
            auto dirAssetProvider = AceType::MakeRefPtr<DirAssetProvider>(
                path, std::make_unique<flutter::DirectoryAssetBundle>(
                          fml::OpenDirectory(path.c_str(), false, fml::FilePermission::kRead)));
#endif
            flutterAssetManager->PushBack(std::move(dirAssetProvider));
        }
    }
}

void AceContainer::SetResourcesPathAndThemeStyle(int32_t instanceId, const std::string& systemResourcesPath,
    const std::string& appResourcesPath, const int32_t& themeId, const ColorMode& colorMode)
{
    auto container = AceType::DynamicCast<AceContainer>(AceEngine::Get().GetContainer(instanceId));
    if (!container) {
        return;
    }
    ContainerScope scope(instanceId);
    auto resConfig = container->resourceInfo_.GetResourceConfiguration();
    resConfig.SetColorMode(static_cast<OHOS::Ace::ColorMode>(colorMode));
    container->resourceInfo_.SetResourceConfiguration(resConfig);
    container->resourceInfo_.SetPackagePath(appResourcesPath);
    container->resourceInfo_.SetThemeId(themeId);
}

void AceContainer::SetView(FlutterAceView* view, double density, int32_t width, int32_t height)
{
    if (view == nullptr) {
        return;
    }

    auto container = AceType::DynamicCast<AceContainer>(AceEngine::Get().GetContainer(view->GetInstanceId()));
    if (!container) {
        return;
    }
    auto platformWindow = PlatformWindow::Create(view);
    if (!platformWindow) {
        LOGE("Create PlatformWindow failed!");
        return;
    }

    std::unique_ptr<Window> window = std::make_unique<Window>(std::move(platformWindow));
    container->AttachView(std::move(window), view, density, width, height);
}

void AceContainer::AttachView(
    std::unique_ptr<Window> window, FlutterAceView* view, double density, int32_t width, int32_t height)
{
    aceView_ = view;
    auto instanceId = aceView_->GetInstanceId();
#ifdef NG_BUILD
    auto state = flutter::ace::WindowManager::GetWindow(instanceId);
    ACE_DCHECK(state != nullptr);
#else
    auto state = flutter::UIJavaScriptState::Current()->GetStateById(instanceId);
    ACE_DCHECK(state != nullptr);
#endif
    auto flutterTaskExecutor = AceType::DynamicCast<FlutterTaskExecutor>(taskExecutor_);
    flutterTaskExecutor->InitOtherThreads(state->GetTaskRunners());

    ContainerScope scope(instanceId);
    if (type_ == FrontendType::DECLARATIVE_JS) {
        flutterTaskExecutor->InitJsThread(false);
        LOGI("Initialize frontend");
        InitializeFrontend();
        auto front = GetFrontend();
        if (front) {
            front->UpdateState(Frontend::State::ON_CREATE);
        }
    }

    resRegister_ = aceView_->GetPlatformResRegister();
    auto pipelineContext = AceType::MakeRefPtr<PipelineContext>(
        std::move(window), taskExecutor_, assetManager_, resRegister_, frontend_, instanceId);
    
#ifdef NG_BUILD
    LOGI("New pipeline version creating...");
    auto pipelineContext = AceType::MakeRefPtr<NG::PipelineContext>(
        std::move(window), taskExecutor_, assetManager_, resRegister_, frontend_, instanceId);
#else
    auto pipelineContext = AceType::MakeRefPtr<PipelineContext>(
        std::move(window), taskExecutor_, assetManager_, resRegister_, frontend_, instanceId);
#endif
    pipelineContext_ = pipelineContext;
    pipelineContext_->SetRootSize(density, width, height);
    pipelineContext_->SetTextFieldManager(AceType::MakeRefPtr<TextFieldManager>());
    pipelineContext_->SetIsRightToLeft(AceApplicationInfo::GetInstance().IsRightToLeft());
#ifndef NG_BUILD
    pipelineContext->SetDrawDelegate(aceView_->GetDrawDelegate());
#endif
    pipelineContext_->SetIsJsCard(type_ == FrontendType::JS_CARD);
    InitializeCallback();

    // Only init global resource here, construct theme in UI thread
    auto themeManager = AceType::MakeRefPtr<ThemeManager>();
    if (themeManager) {
        pipelineContext_->SetThemeManager(themeManager);
        // Init resource, load theme map.
        themeManager->InitResource(resourceInfo_);
        themeManager->LoadSystemTheme(resourceInfo_.GetThemeId());
        taskExecutor_->PostTask(
            [themeManager, assetManager = assetManager_, colorScheme = colorScheme_, aceView = aceView_]() {
                themeManager->ParseSystemTheme();
                themeManager->SetColorScheme(colorScheme);
                themeManager->LoadCustomTheme(assetManager);
                // get background color from theme
                aceView->SetBackgroundColor(themeManager->GetBackgroundColor());
            },
            TaskExecutor::TaskType::UI);
    }

    taskExecutor_->PostTask(
        [context = pipelineContext_]() { context->SetupRootElement(); }, TaskExecutor::TaskType::UI);
    aceView_->Launch();

    frontend_->AttachPipelineContext(pipelineContext_);
    auto cardFronted = AceType::DynamicCast<CardFrontend>(frontend_);
    if (cardFronted) {
        cardFronted->SetDensity(static_cast<double>(density));
        taskExecutor_->PostTask(
            [context = pipelineContext_, width, height]() { context->OnSurfaceChanged(width, height); },
            TaskExecutor::TaskType::UI);
    }

    taskExecutor_->PostTask([context = pipelineContext_, width, height]() { context->OnSurfaceChanged(width, height); },
        TaskExecutor::TaskType::UI);

    AceEngine::Get().RegisterToWatchDog(instanceId, taskExecutor_);
}

void AceContainer::RequestFrame() {}

std::string AceContainer::GetCustomAssetPath(std::string assetPath)
{
    if (assetPath.empty()) {
        LOGE("AssetPath is null.");
        return std::string();
    }
    std::string customAssetPath;
    if (OHOS::Ace::Framework::EndWith(assetPath, DELIMITER)) {
        assetPath = assetPath.substr(0, assetPath.size() - 1);
    }
    customAssetPath = assetPath.substr(0, assetPath.find_last_of(DELIMITER) + 1);
    return customAssetPath;
}

bool AceContainer::OnBackPressed(int32_t instanceId)
{
    auto container = AceEngine::Get().GetContainer(instanceId);
    if (!container) {
        return false;
    }

    auto context = container->GetPipelineContext();
    if (!context) {
        return false;
    }

    Container::UpdateCurrent(INSTANCE_ID_PLATFORM);
    bool ret = context->CallRouterBackToPopPage();
    ContainerScope scope(instanceId);
    return ret;
}

void AceContainer::OnShow(int32_t instanceId)
{
    auto container = AceEngine::Get().GetContainer(instanceId);
    if (!container) {
        return;
    }

    ContainerScope scope(instanceId);
    auto front = container->GetFrontend();
    if (front) {
        front->OnShow();
    }
    auto context = container->GetPipelineContext();
    if (!context) {
        return;
    }
    context->OnShow();
}

void AceContainer::OnActive(int32_t instanceId)
{
    auto container = AceEngine::Get().GetContainer(instanceId);
    if (!container) {
        return;
    }

    ContainerScope scope(instanceId);
    auto front = container->GetFrontend();
    if (front) {
        front->OnActive();
    }
}

void AceContainer::OnInactive(int32_t instanceId)
{
    auto container = AceEngine::Get().GetContainer(instanceId);
    if (!container) {
        return;
    }

    ContainerScope scope(instanceId);
    auto front = container->GetFrontend();
    if (front) {
        front->OnInactive();
    }
}

void AceContainer::OnHide(int32_t instanceId)
{
    auto container = AceEngine::Get().GetContainer(instanceId);
    if (!container) {
        return;
    }

    ContainerScope scope(instanceId);
    auto front = container->GetFrontend();
    if (front) {
        front->OnHide();
        auto taskExecutor = container->GetTaskExecutor();
        if (taskExecutor) {
            taskExecutor->PostTask([front]() { front->TriggerGarbageCollection(); }, TaskExecutor::TaskType::JS);
        }
    }

    auto context = container->GetPipelineContext();
    if (!context) {
        return;
    }
    context->OnHide();
}

std::string AceContainer::OnSaveData(int32_t instanceId)
{
    std::string result = "false";
    auto container = AceEngine::Get().GetContainer(instanceId);
    if (!container) {
        LOGI("container is null, OnSaveData failed.");
        return result;
    }

    ContainerScope scope(instanceId);
    auto front = container->GetFrontend();
    if (!front) {
        LOGI("front is null, OnSaveData failed.");
        return result;
    }
    front->OnSaveData(result);
    return result;
}

bool AceContainer::OnRestoreData(int32_t instanceId, const std::string& data)
{
    auto container = AceEngine::Get().GetContainer(instanceId);
    if (!container) {
        LOGI("container is null, OnRestoreData failed.");
        return false;
    }

    ContainerScope scope(instanceId);
    auto front = container->GetFrontend();
    if (!front) {
        LOGI("front is null, OnRestoreData failed.");
        return false;
    }
    return front->OnRestoreData(data);
}

void AceContainer::SetJsFrameworkLocalPath(const char* path)
{
    localJsFrameworkPath_ = path;
}

} // namespace OHOS::Ace::Platform
