/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
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

#include "core/common/dynamic_module_helper.h"

#import <Foundation/Foundation.h>

#include <dlfcn.h>
#include <memory>

#include "base/log/log_wrapper.h"
#include "base/utils/utils.h"
#include "compatible/components/component_loader.h"
#include "interfaces/inner_api/ace/utils.h"
#include "core/common/dynamic_module.h"
#include "core/components_ng/pattern/menu/bridge/menu/menu_dynamic_module.h"
#include "core/components_ng/pattern/menu/bridge/menu_item/menu_item_dynamic_module.h"
#include "core/components_ng/pattern/menu/bridge/menu_item_group/menu_item_group_dynamic_module.h"

// Forward declarations for static module creation functions
extern "C" void* OHOS_ACE_DynamicModule_Create_Menu();
extern "C" void* OHOS_ACE_DynamicModule_Create_MenuItem();
extern "C" void* OHOS_ACE_DynamicModule_Create_MenuItemGroup();

namespace OHOS::Ace {
namespace {
const std::string DYNAMIC_MODULE_LIB_PREFIX = "libarkui_";
static NSString* DYNAMIC_MODULE_LIB_POSTFIX = @".dylib";
static NSString* FRAMEWORK_TYPE = @"framework";

// Static module instances for components bundled into libarkui_ios
static std::unique_ptr<DynamicModule> g_menuModule = nullptr;
static std::unique_ptr<DynamicModule> g_menuItemModule = nullptr;
static std::unique_ptr<DynamicModule> g_menuItemGroupModule = nullptr;

// Initialize static modules
void InitializeStaticModules()
{
    static bool initialized = false;
    if (initialized) {
        return;
    }

    g_menuModule.reset(reinterpret_cast<DynamicModule*>(OHOS_ACE_DynamicModule_Create_Menu()));
    g_menuItemModule.reset(reinterpret_cast<DynamicModule*>(OHOS_ACE_DynamicModule_Create_MenuItem()));
    g_menuItemGroupModule.reset(reinterpret_cast<DynamicModule*>(OHOS_ACE_DynamicModule_Create_MenuItemGroup()));

    LOGI("InitializeStaticModules finished");
    initialized = true;
}

const std::unordered_map<std::string, std::string> soMap = {
    {"Marquee", "marquee"},
    {"Stepper", "stepper" },
    {"StepperItem", "stepper" },
    {"Slider", "slider" },
    {"Checkbox", "checkbox"},
    {"CheckboxGroup", "checkbox"},
    {"Gauge", "gauge"},
    {"Rating", "rating"},
    {"FlowItem", "waterflow" },
    {"WaterFlow", "waterflow" },
    {"Counter", "counter"},
    {"Sidebar", "sidebar"},
    {"ColumnSplit", "linearsplit"},
    {"RowSplit", "linearsplit"},
    {"Radio", "radio"},
    {"QRCode", "qrcode"},
    {"TimePicker", "timepicker"},
    {"TimePickerDialog", "timepicker"},
    {"Indexer", "indexer"},
    {"Hyperlink", "hyperlink"},
    {"PatternLock", "patternlock"},
    {"CalendarPicker", "calendarpicker"},
    {"CalendarPickerDialog", "calendarpicker"},
    {"SymbolGlyph", "symbol"},
    {"DataPanel", "datapanel"},
    {"Richeditor", "richeditor"},
    {"Search", "search"},
    // Menu components are now statically linked, handled in GetDynamicModule
    {"TextClock", "textclock"},
};
} // namespace
DynamicModuleHelper& DynamicModuleHelper::GetInstance()
{
    static DynamicModuleHelper instance;
    return instance;
}

std::unique_ptr<ComponentLoader> DynamicModuleHelper::GetLoaderByName(const char* name)
{
    return nullptr;
}

DynamicModule* DynamicModuleHelper::GetDynamicModule(const std::string& name)
{
    // Initialize static modules (Menu, MenuItem, MenuItemGroup)
    InitializeStaticModules();

    // Check for statically linked modules first
    if (name == "Menu") {
        return g_menuModule.get();
    }
    if (name == "MenuItem") {
        return g_menuItemModule.get();
    }
    if (name == "MenuItemGroup") {
        return g_menuItemGroupModule.get();
    }

    // Double-checked locking pattern for better performance
    {
        std::lock_guard<std::mutex> lock(moduleMapMutex_);
        auto iter = moduleMap_.find(name);
        if (iter != moduleMap_.end()) {
            return iter->second.get();
        }
    }
    auto it = soMap.find(name);
    if (it == soMap.end()) {
        LOGE("No shared library mapping found for nativeModule: %{public}s", name.c_str());
        return nullptr;
    }
    // Load module without holding the lock (dlopen/dlsym may be slow)
    std::string moduleNameStr = DYNAMIC_MODULE_LIB_PREFIX + it->second;
    NSString* moduleName = [NSString stringWithUTF8String:moduleNameStr.c_str()];
    NSString* frameworkPath = [[NSBundle mainBundle] pathForResource:moduleName ofType:FRAMEWORK_TYPE];
    NSString* dylibPath = [frameworkPath stringByAppendingPathComponent:[moduleName stringByAppendingString:DYNAMIC_MODULE_LIB_POSTFIX]];
    const char* libName = [dylibPath UTF8String];
    auto* handle = dlopen(libName, RTLD_NOLOAD);
    LOGI("First load %{public}s nativeModule start", name.c_str());
    if (handle == nullptr) {
        LOGE("Failed to load dynamic module library: %{public}s, error: %{public}s", name.c_str(), dlerror());
        return nullptr;
    }
    auto* createSym = reinterpret_cast<DynamicModuleCreateFunc>(dlsym(handle, (DYNAMIC_MODULE_CREATE + name).c_str()));
    if (createSym == nullptr) {
        LOGE("Failed to find symbol in library %{public}s, error: %{public}s", name.c_str(), dlerror());
        dlclose(handle);
        return nullptr;
    }
    DynamicModule* module = createSym();
    if (module == nullptr) {
        LOGE("Failed to create DynamicModule instance from library %{public}s", name.c_str());
        dlclose(handle);
        return nullptr;
    }
    LOGI("First load %{public}s nativeModule finish", name.c_str());

    // Lock again to insert into map
    {
        std::lock_guard<std::mutex> lock(moduleMapMutex_);
        // Check again in case another thread already loaded it
        auto iter = moduleMap_.find(name);
        if (iter != moduleMap_.end()) {
            // Another thread already loaded it, use that one
            delete module;
            dlclose(handle);
            return iter->second.get();
        }
        moduleMap_.emplace(name, std::unique_ptr<DynamicModule>(module));
        return module;
    }
}

} // namespace OHOS::Ace