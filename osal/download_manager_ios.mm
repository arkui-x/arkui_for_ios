#include <dlfcn.h>

#import <Foundation/Foundation.h>

#include "base/log/log_wrapper.h"
#include "base/network/download_manager.h"
#include "core/image/image_file_cache.h"

namespace OHOS::Ace {
DownloadManager* CreateIOSDownloadManager();
std::unique_ptr<DownloadManager> DownloadManager::instance_ = nullptr;
std::mutex DownloadManager::mutex_;
namespace {
using CreateDownloadManagerFunc = DownloadManager* (*)(const char* path);

constexpr char CREATE_DOWNLOAD_MANAGER_FUNC[] = "OHOS_ACE_CreateDownloadManager";
constexpr char ACE_NETWORK_RPATH[] = "@rpath/libace_network.framework/libace_network";

NSString* const ACE_NETWORK_FRAMEWORK_NAME = @"libace_network";
NSString* const FRAMEWORK_TYPE = @"framework";

std::string GetAceNetworkFrameworkPath()
{
    NSString* frameworkPath = [[NSBundle mainBundle] pathForResource:ACE_NETWORK_FRAMEWORK_NAME ofType:FRAMEWORK_TYPE];
    if (frameworkPath == nil) {
        return {};
    }

    NSString* binaryPath = [frameworkPath stringByAppendingPathComponent:ACE_NETWORK_FRAMEWORK_NAME];
    if (binaryPath == nil) {
        return {};
    }

    return std::string([binaryPath UTF8String]);
}

void* LoadAceNetworkLibrary()
{
    auto frameworkBinaryPath = GetAceNetworkFrameworkPath();
    if (!frameworkBinaryPath.empty()) {
        void* handle = dlopen(frameworkBinaryPath.c_str(), RTLD_LAZY | RTLD_LOCAL);
        if (handle != nullptr) {
            return handle;
        }

        TAG_LOGW(AceLogTag::ACE_DOWNLOAD_MANAGER,
            "Load libace_network by framework path failed: %{public}s", dlerror());
    }

    void* handle = dlopen(ACE_NETWORK_RPATH, RTLD_LAZY | RTLD_LOCAL);
    if (handle == nullptr) {
        TAG_LOGW(AceLogTag::ACE_DOWNLOAD_MANAGER,
            "Load libace_network by rpath failed: %{public}s", dlerror());
    }

    return handle;
}

DownloadManager* CreateDownloadManager()
{
    void* handle = LoadAceNetworkLibrary();
    if (handle == nullptr) {
        return nullptr;
    }

    auto entry = reinterpret_cast<CreateDownloadManagerFunc>(dlsym(handle, CREATE_DOWNLOAD_MANAGER_FUNC));
    const char* error = dlerror();
    if (entry == nullptr || error != nullptr) {
        TAG_LOGW(AceLogTag::ACE_DOWNLOAD_MANAGER,
            "Find OHOS_ACE_CreateDownloadManager failed: %{public}s", error == nullptr ? "" : error);
        dlclose(handle);
        return nullptr;
    }

    auto path = ImageFileCache::GetInstance().GetImageCacheFilePath();
    return entry(path.c_str());
}
} // namespace

DownloadManager* DownloadManager::GetInstance()
{
    if (!instance_) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (!instance_) {
            DownloadManager* manager = CreateDownloadManager();
            if (manager != nullptr) {
                instance_.reset(manager);
            } else {
                instance_.reset(CreateIOSDownloadManager());
            }
        }
    }
    return instance_.get();
}
} // namespace OHOS::Ace