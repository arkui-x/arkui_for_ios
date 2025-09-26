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

#import <Foundation/Foundation.h>
#import "StageAssetManager.h"

#include "stage_asset_provider.h"
#include "base/utils/string_utils.h"
#include "nlohmann/json.hpp"

#define DOCUMENTS_SUBDIR_FILES @"files"
#define DOCUMENTS_SUBDIR_DATABASE @"database"

namespace OHOS {
namespace AbilityRuntime {
namespace Platform {
std::shared_ptr<StageAssetProvider> StageAssetProvider::instance_ = nullptr;
std::mutex StageAssetProvider::mutex_;
std::map<std::string, std::pair<std::string, std::string>> StageAssetProvider::staticResCache = {};

std::shared_ptr<StageAssetProvider> StageAssetProvider::GetInstance()
{
    if (instance_ == nullptr) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (instance_ == nullptr) {
            instance_ = std::make_shared<StageAssetProvider>();
        }
    }

    return instance_;
}

std::vector<uint8_t> GetVectorFromNSData(NSData *data)
{
  const uint8_t *bytes = reinterpret_cast<const uint8_t*>(data.bytes);
  return std::vector<uint8_t>(bytes, bytes + data.length);
}

NSData * GetNSDataFromVector(const std::vector<uint8_t>& buffer)
{
  return [NSData dataWithBytes:buffer.data() length:buffer.size()];
}

NSString * GetOCstring(const std::string& c_string)
{ 
    return [NSString stringWithCString:c_string.c_str() encoding:NSUTF8StringEncoding];
}


std::vector<uint8_t> StageAssetProvider::GetPkgJsonBuffer(const std::string& moduleName)
{
    std::lock_guard<std::mutex> lock(providerLock_);
    NSString *oc_moduleName = GetOCstring(moduleName);
    NSArray *pkgJsonFileList = [[StageAssetManager assetManager] getpkgJsonFileList];
    for (NSString *pkgJsonPath in pkgJsonFileList) {
        if ([pkgJsonPath containsString:[NSString stringWithFormat:@"/%@/", oc_moduleName]]) {
            NSData *pathData = [NSData dataWithContentsOfFile:pkgJsonPath];
            if (!pathData) {
                NSLog(@"pathData is null");
                break;
            }
            auto buffer =  GetVectorFromNSData(pathData);
            return buffer;
        }
    }
    return {};
}

std::string ExtractConfigurationFileName(const nlohmann::json& moduleJson)
{
    if (moduleJson.is_null() || moduleJson.is_discarded()) {
        return "";
    }
    auto appValue = moduleJson["app"];
    if (!appValue.is_object() || !appValue.contains("configuration")) {
        return "";
    }
    auto configurationValue = appValue["configuration"];
    std::string configurationStr = configurationValue.get<std::string>();
    auto delimiterPos = configurationStr.find(':');
    if (delimiterPos != std::string::npos) {
        return configurationStr.substr(delimiterPos + 1) + ".json";
    }
    return "";
}

std::list<std::vector<uint8_t>> StageAssetProvider::GetModuleJsonBufferList()
{
    printf("%s", __func__);
    std::lock_guard<std::mutex> lock(providerLock_);
    std::list<std::vector<uint8_t>> bufferList;

    NSArray *moduleJsonFileList = [[StageAssetManager assetManager] getModuleJsonFileList];
    if (!moduleJsonFileList.count) {
        printf("%s moduleJsonFileList count 0", __func__);
        return bufferList;
    }
    NSArray *moduleJsons = [NSArray arrayWithArray:moduleJsonFileList];
    for (NSString *moduleJsonPath in moduleJsons) {
        NSData *pathData = [NSData dataWithContentsOfFile:moduleJsonPath];
        pathData = [[StageAssetManager assetManager] updateModuleNameWithJsonData:pathData 
                                                                   moduleJsonPath:moduleJsonPath];
        std::vector<uint8_t> moduleBuffer =  GetVectorFromNSData(pathData);
        if (moduleBuffer.empty() || moduleBuffer.size() == 0) {
            continue;
        }
        bufferList.emplace_back(moduleBuffer);
    }
    if (!bufferList.empty()) {
        auto firstModule = bufferList.front();
        std::string moduleContent(firstModule.begin(), firstModule.end());
        nlohmann::json moduleJson = nlohmann::json::parse(moduleContent, nullptr, false);
        if (moduleJson.is_discarded()) {
            return bufferList;
        }
        fontConfigName_ = ExtractConfigurationFileName(moduleJson);
    }
    return bufferList;
}

std::vector<uint8_t> StageAssetProvider::GetFontConfigJsonBuffer(const std::string& moduleName)
{
    std::lock_guard<std::mutex> lock(providerLock_);
    if (fontConfigName_.empty()) {
        return {};
    }
    NSString *oc_moduleName = GetOCstring(fontConfigName_);
    NSArray *pkgJsonFileList = [[StageAssetManager assetManager] getAssetAllFilePathList];
    for (NSString *pkgJsonPath in pkgJsonFileList) {
        if ([pkgJsonPath containsString:[NSString stringWithFormat:@"/%@", oc_moduleName]]) {
            NSData *pathData = [NSData dataWithContentsOfFile:pkgJsonPath];
            if (!pathData) {
                NSLog(@"pathData is null");
                break;
            }
            auto buffer =  GetVectorFromNSData(pathData);
            return buffer;
        }
    }
    return {};
}

std::vector<uint8_t> StageAssetProvider::GetModuleBuffer(const std::string& moduleName, std::string& modulePath, bool esmodule)
{
    printf("%s, moduleName : %s, modulePath : %s", __func__, moduleName.c_str(), modulePath.c_str());
    std::lock_guard<std::mutex> lock(providerLock_);
    std::vector<uint8_t> buffer;
    
    if (moduleName.empty()) {
        printf("%s, moduleName null", __func__);
        return buffer;
    }
    
    NSString *oc_moduleName = GetOCstring(moduleName);
    NSString *oc_modulePath = GetOCstring(modulePath);
    NSString *abilityStageAbcPath = [[StageAssetManager assetManager] getAbilityStageABCWithModuleName:oc_moduleName
                                                                                            modulePath:&oc_modulePath
                                                                                              esmodule:esmodule];
    if (!abilityStageAbcPath.length || moduleIsUpdates_[moduleName]) {
        printf("%s, abilityStageAbcPath null", __func__);

        std::string fullAbilityName = esmodule ? "modules.abc" : "AbilityStage.abc";
        auto path = GetAppDataModuleDir() + "/" + moduleName;
        std::vector<std::string> fileFullPaths;
        GetAppDataModuleAssetList(path, fileFullPaths, false);
        for (auto& path : fileFullPaths) {
            if (path.find("/" + moduleName + "/") != std::string::npos && path.find(fullAbilityName) != std::string::npos) {
                modulePath = path;
                break;
            }
        }
        NSString *oc_dataAppPath = GetOCstring(modulePath);
        NSData *oc_dataAppPathData = [NSData dataWithContentsOfFile:oc_dataAppPath];
        buffer = GetVectorFromNSData(oc_dataAppPathData);
        return buffer;
    }
    modulePath = [oc_modulePath UTF8String];
    NSData *abilityStageAbcPathData = [NSData dataWithContentsOfFile:abilityStageAbcPath];
    buffer = GetVectorFromNSData(abilityStageAbcPathData);
    return buffer;
}

void StageAssetProvider::GetResIndexPath(const std::string& moduleName,
    std::string& appResIndexPath, std::string& sysResIndexPath)
{
    printf("%s, moduleName : %s", __func__, moduleName.c_str());
    std::lock_guard<std::mutex> lock(providerLock_);
     if (moduleName.empty()) {
        printf("%s, moduleName null", __func__);
        return;
    }
    auto it = staticResCache.find(moduleName);
    if (it != staticResCache.end() && !moduleIsUpdates_[moduleName]) {
        appResIndexPath = it->second.first;
        sysResIndexPath = it->second.second;
        return;
    }
    NSString *oc_moduleName = GetOCstring(moduleName);
    NSString *oc_appResIndexPath = GetOCstring(appResIndexPath);
    NSString *oc_sysResIndexPath = GetOCstring(sysResIndexPath);
    [[StageAssetManager assetManager] getModuleResourcesWithModuleName:oc_moduleName
                                                       appResIndexPath:&oc_appResIndexPath
                                                       sysResIndexPath:&oc_sysResIndexPath];
    appResIndexPath = [oc_appResIndexPath UTF8String];
    sysResIndexPath = [oc_sysResIndexPath UTF8String];

    if (!oc_appResIndexPath.length || moduleIsUpdates_[moduleName]) {
        auto path = GetAppDataModuleDir() + "/" + moduleName;
        std::vector<std::string> fileFullPaths;
        GetAppDataModuleAssetList(path, fileFullPaths, false);
        for (auto& file : fileFullPaths) {
            if (file.find("/" + moduleName + "/resources.index") != std::string::npos) {
                appResIndexPath = file;
                continue;
            }
            if (!oc_sysResIndexPath.length && file.find("/systemres/resources.index") != std::string::npos) {
                sysResIndexPath = file;
                continue;
            }
        }
        staticResCache[moduleName] = {appResIndexPath, sysResIndexPath};
    }
    if (!oc_sysResIndexPath.length || moduleIsUpdates_[moduleName]) {
        auto path = GetAppDataModuleDir() + "/" + "systemres";
        std::vector<std::string> fileFullPaths;
        GetAppDataModuleAssetList(path, fileFullPaths, false);
        for (auto& file : fileFullPaths) {
            if (file.find("/systemres/resources.index") != std::string::npos) {
                sysResIndexPath = file;
                continue;
            }
        }
        staticResCache[moduleName] = {appResIndexPath, sysResIndexPath};
    }
}

std::vector<uint8_t> StageAssetProvider::GetModuleAbilityBuffer (
    const std::string& moduleName, const std::string& abilityName, std::string& modulePath, bool esmodule)
{
    printf("%s, moduleName : %s, abilityName : %s", __func__, moduleName.c_str(), abilityName.c_str());
    std::lock_guard<std::mutex> lock(providerLock_);
    std::vector<uint8_t> buffer;

    if (moduleName.empty()) {
        printf("%s, moduleName null", __func__);
        return buffer;
    }

    if (abilityName.empty()) {
        printf("%s, abilityName null", __func__);
        buffer = GetModuleBuffer(moduleName, modulePath, esmodule);
        return buffer;
    }

    NSString *oc_moduleName = GetOCstring(moduleName);
    NSString *oc_abilityName = GetOCstring(abilityName);
    NSString *oc_modulePath = GetOCstring(modulePath);
    NSString *moduleAbilityPath = [[StageAssetManager assetManager] getModuleAbilityABCWithModuleName:oc_moduleName
                                                                                          abilityName:oc_abilityName
                                                                                           modulePath:&oc_modulePath 
                                                                                             esmodule:esmodule];
    if (!moduleAbilityPath.length || moduleIsUpdates_[moduleName]) {
        printf("%s, moduleAbilityPath null", __func__);

        std::string fullAbilityName = esmodule ? "modules.abc" : abilityName + ".abc";
        auto path = GetAppDataModuleDir() + "/" + moduleName;
        std::vector<std::string> fileFullPaths;
        GetAppDataModuleAssetList(path, fileFullPaths, false);
        for (auto& file : fileFullPaths) {
            if (file.find("/" + moduleName + "/") != std::string::npos && file.find(fullAbilityName) != std::string::npos) {
                modulePath = file;
                break;
            }
        }
        NSString *oc_dataAppPath = GetOCstring(modulePath);        
        NSData *oc_dataAppPathData = [NSData dataWithContentsOfFile:oc_dataAppPath];
        buffer = GetVectorFromNSData(oc_dataAppPathData);
        return buffer;
    }
    modulePath = [oc_modulePath UTF8String];
    NSData *moduleAbilityPathData = [NSData dataWithContentsOfFile:moduleAbilityPath];
    buffer = GetVectorFromNSData(moduleAbilityPathData);
    return buffer;
}

std::string StageAssetProvider::GetBundleCodeDir()
{
    NSString *bundleDirectory = [[StageAssetManager assetManager] getBundlePath];
    std::string bundleCodeDir = [bundleDirectory UTF8String];
    return bundleCodeDir;
}

std::string StageAssetProvider::GetCacheDir()
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachesDirectory = [paths objectAtIndex:0];

    std::string cacheDir = [cachesDirectory UTF8String];
    return cacheDir;
}

std::string StageAssetProvider::GetResourceFilePrefixPath()
{
    NSString *bundleDirectory = [[StageAssetManager assetManager] GetResourceFilePrefixPath];
    std::string bundleCodeDir = [bundleDirectory UTF8String];
    return bundleCodeDir;
}

std::string StageAssetProvider::GetTempDir()
{
    NSString *tempDirectory = NSTemporaryDirectory();
    tempDirectory = [tempDirectory substringToIndex:tempDirectory.length - 1];
    std::string tempDir = [tempDirectory UTF8String];
    return tempDir;
}

std::string StageAssetProvider::GetFilesDir()
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filesDirectory = [documentsDirectory stringByAppendingPathComponent:DOCUMENTS_SUBDIR_FILES];
    std::string filesDir = [filesDirectory UTF8String];
    return filesDir;
}

std::string StageAssetProvider::GetDatabaseDir()
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *databaseDirectory = [documentsDirectory stringByAppendingPathComponent:DOCUMENTS_SUBDIR_DATABASE];
    std::string documentsDir = [documentsDirectory UTF8String];
    return documentsDir;
}

std::string StageAssetProvider::GetPreferencesDir()
{
    NSString *preferencesDirectory = [[NSHomeDirectory() stringByAppendingPathComponent:@"Library"]
                                                         stringByAppendingPathComponent:@"Preferences"];
    std::string preferencesDir = [preferencesDirectory UTF8String];
    return preferencesDir;
}

std::string StageAssetProvider::GetAppDataModuleDir() const
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filesDirectory = [[documentsDirectory stringByAppendingPathComponent:@"files"]
                                                         stringByAppendingPathComponent:@"arkui-x"];    
    std::string stageDynamicDir = [filesDirectory UTF8String];
    return stageDynamicDir;
}

std::vector<std::string> StageAssetProvider::GetAllFilePath()
{
    std::vector<std::string> fileFullPaths;

    NSArray *filePathArray = [[StageAssetManager assetManager] getAssetAllFilePathList];
    for (NSString *filePath in filePathArray) {        
        std::string file = [filePath UTF8String];
        fileFullPaths.emplace_back(file);
    }
    return fileFullPaths;
}

bool StageAssetProvider::GetAppDataModuleAssetList(
    const std::string& path, std::vector<std::string>& fileFullPaths, bool onlyChild)
{
    NSError *error = nil;
    NSString *bundlePath = GetOCstring(path);
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    BOOL isDirectroy = NO;
    NSArray *moduleArray = [fileMgr subpathsOfDirectoryAtPath:bundlePath error:&error];    

    if (error || moduleArray.count <= 0) {
        return false;
    }
    // onlyChild no use
    for (NSString *subFile in moduleArray) {
        NSString *filePath = [NSString stringWithFormat:@"%@/%@", bundlePath, subFile];
        BOOL result = [fileMgr fileExistsAtPath:filePath isDirectory:&isDirectroy];
        if (!isDirectroy && result) {
            std::string file = [filePath UTF8String];
            fileFullPaths.emplace_back(file);
        }
    }
    return true;
}

std::vector<uint8_t> StageAssetProvider::GetBufferByAppDataPath(const std::string& fileFullPath)
{
    std::vector<uint8_t> buffer;
        
    NSString *oc_dataAppPath = GetOCstring(fileFullPath);
    NSData *oc_dataAppPathData = [NSData dataWithContentsOfFile:oc_dataAppPath];
    buffer = GetVectorFromNSData(oc_dataAppPathData);
    return buffer;
}

std::vector<uint8_t> StageAssetProvider::GetAotBuffer(const std::string &fileName)
{
    std::vector<uint8_t> buffer;
    return buffer;
}

bool ExistDir(const std::string& target)
{
    NSString *path = [NSString stringWithUTF8String:target.c_str()];
    BOOL isDir = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
    return exists && isDir;
}

void StageAssetProvider::SetBundleName(const std::string& bundleName)
{
    bundleName_ = bundleName;
}

std::string StageAssetProvider::GetSplicingModuleName(const std::string& moduleName)
{
    if (moduleName.empty() || bundleName_.empty()) {
        return moduleName;
    }
    std::string fullModuleName = bundleName_ + "." + moduleName;
    std::string modulePath = GetAppDataModuleDir() + '/' + fullModuleName;
    return ExistDir(modulePath) ? fullModuleName : moduleName;
}

void StageAssetProvider::InitModuleVersionCode()
{
    auto moduleList = GetModuleJsonBufferList();
    std::string bundleName = "";
    std::string moduleName = "";
    int32_t versionCode = 0;
    for (auto& buffer : moduleList) {
        buffer.push_back('\0');
        nlohmann::json moduleJson = nlohmann::json::parse(buffer.data(), nullptr, false);
        if (moduleJson.is_discarded()) {
            continue;
        }
        if (moduleJson.contains("app") && moduleJson["app"].contains("versionCode")) {
            versionCode = moduleJson["app"]["versionCode"].get<int>();
        }
        if (moduleJson.contains("module") && moduleJson["module"].contains("name")) {
            moduleName = moduleJson["module"]["name"].get<std::string>();
        }
        if (moduleJson.contains("app") && moduleJson["app"].contains("bundleName")) {
            bundleName = moduleJson["app"]["bundleName"].get<std::string>();
        }
        if (!moduleName.empty() && !bundleName.empty()) {
            std::string fullModuleName = bundleName + "." + moduleName;
            std::string modulePath = GetAppDataModuleDir() + '/' + fullModuleName;
            moduleName = ExistDir(modulePath) ? fullModuleName : moduleName;
        }
        if (!moduleName.empty() && versionCode > 0) {
            versionCodes_.emplace(moduleName, versionCode);
        }
    }
}

void StageAssetProvider::UpdateVersionCode(const std::string& moduleName, bool needUpdate)
{
    bool isUpdate = false;
    if (needUpdate) {
        auto modulePath = GetAppDataModuleDir() + '/' + moduleName + "/module.json";
        auto dynamicModuleBuffer = GetBufferByAppDataPath(modulePath);
        dynamicModuleBuffer.push_back('\0');
        int32_t versionCode = 0;
        nlohmann::json moduleJson = nlohmann::json::parse(dynamicModuleBuffer.data(), nullptr, false);
        if (!moduleJson.is_discarded() && moduleJson.contains("app") && moduleJson["app"].contains("versionCode")) {
            versionCode = moduleJson["app"]["versionCode"].get<int>();
        }
        if (versionCode > 0) {
            auto it = versionCodes_.find(moduleName);
            if (it == versionCodes_.end() || it->second < versionCode) {
                isUpdate = true;
                versionCodes_[moduleName] = versionCode;
            }
        }
    }
    moduleIsUpdates_[moduleName] = isUpdate;
}

bool StageAssetProvider::IsDynamicUpdateModule(const std::string& moduleName)
{
    bool isDynamicUpdate = false;
    auto it = moduleIsUpdates_.find(moduleName);
    if (it != moduleIsUpdates_.end()) {
        isDynamicUpdate = it->second;
    }
    return isDynamicUpdate;
}
} // namespace Platform
} // namespace AbilityRuntime
} // namespace OHOS