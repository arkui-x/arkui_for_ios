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

#import "StageAssetManager.h"

#include "app_main.h"

using AppMain = OHOS::AbilityRuntime::Platform::AppMain;
#define PKG_CONTEXT_INFO_JSON @"pkgContextInfo.json"
#define FILTER_FILE_MODULE_JSON @"module.json"
#define FILTER_FILE_ABILITYSTAGE_ABC @"AbilityStage.abc"
#define MODULE_STAGE_ABC_NAME @"modules.abc"
#define FILTER_FILE_MODULE_ABC @".abc"
#define FILTER_FILE_RESOURCES_INDEX @"resources.index"
#define FILTER_FILE_SYSTEM_RESOURCES_INDEX @"systemres"
#define DOCUMENTS_FONTS_FILES @"fonts"
#define DOCUMENTS_SUBDIR_FILES @"files"
#define DOCUMENTS_SUBDIR_DATABASE @"database"

@interface StageAssetManager ()

@property (nonatomic, strong) NSMutableArray *allModuleFilePathArray;

@property (nonatomic, strong) NSMutableArray *moduleJsonFileArray;

@property (nonatomic, strong) NSMutableArray *pkgJsonFileArray;

@property (nonatomic, strong) NSString *bundlePath;

@end

@implementation StageAssetManager

+ (instancetype)assetManager {
    static StageAssetManager *_assetManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        LOGI("StageManager share instance");
        _assetManager = [[StageAssetManager alloc] init];
    });
    return _assetManager;
}

- (void)moduleFilesWithbundleDirectory:(NSString *_Nonnull)bundleDirectory {
    NSError *error = nil;
    NSMutableArray *files = [[NSMutableArray alloc] init];
    NSString *bundlePath = [NSString stringWithFormat:@"%@/%@", [NSBundle mainBundle].bundlePath, bundleDirectory];
    LOGI("%{public}s, \n bundlePath is : %{public}s", __func__, [bundlePath UTF8String]);
    self.bundlePath = bundlePath;
    NSArray *moduleArray = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:bundlePath error:&error];
    if (!error && moduleArray.count > 0) {
        for (NSString *subFile in moduleArray) {
            NSString *filePath = [NSString stringWithFormat:@"%@/%@", bundlePath, subFile];
            if ([self isExistFileForPath:filePath]) {
                NSString *fileName = [subFile lastPathComponent];
                if ([fileName isEqualToString:FILTER_FILE_MODULE_JSON]) {
                    @synchronized (self) {
                        [self.moduleJsonFileArray addObject:filePath];
                    }
                } else if ([fileName isEqualToString:PKG_CONTEXT_INFO_JSON]) {
                    @synchronized (self) {
                        [self.pkgJsonFileArray addObject:filePath];
                    }
                }
                [files addObject:filePath];
            }
        }
    }
    LOGI("%{public}s, all files count : %{public}lu", __func__, (unsigned long)files.count);
    @synchronized (self) {
        [self.allModuleFilePathArray addObjectsFromArray:files.copy];
    }

    BOOL isCreatFiles = [self createDocumentSubDirectoryAtPath:DOCUMENTS_SUBDIR_FILES];
    BOOL isCreatDatabase = [self createDocumentSubDirectoryAtPath:DOCUMENTS_SUBDIR_DATABASE];
    LOGI("isCreatFiles : %{public}d, isCreatDatabase : %{public}d", isCreatFiles, isCreatDatabase);
}

- (void)launchAbility:(BOOL)isLoadArkUI {
    LOGI("%{public}s", __func__);
    AppMain::GetInstance()->LaunchApplication(true, isLoadArkUI);
}

- (NSString *_Nullable)GetResourceFilePrefixPath {
    NSString *dirPath = [[self.bundlePath
            stringByAppendingPathComponent:FILTER_FILE_SYSTEM_RESOURCES_INDEX]
            stringByAppendingPathComponent:DOCUMENTS_FONTS_FILES];
    return dirPath ;
}

- (NSString *_Nullable)getBundlePath {
    LOGI("%{public}s", __func__);
    return self.bundlePath;
}

- (NSArray *_Nullable)getAssetAllFilePathList {
    @synchronized (self) {
        LOGI("%{public}s, \n all asset file list size: %{public}ld", __func__, self.allModuleFilePathArray.count);
        return self.allModuleFilePathArray.copy;
    }
}

- (NSArray *_Nullable)getpkgJsonFileList {
    @synchronized (self) {
        return self.pkgJsonFileArray.copy;
    }
}

- (NSArray *_Nullable)getModuleJsonFileList {
    @synchronized (self) {
        //to do
        LOGI("%{public}s, \n modulejson file list", __func__);
        return self.moduleJsonFileArray.copy;
    }
}

- (NSString *_Nullable)getAbilityStageABCWithModuleName:(NSString *)moduleName
                                             modulePath:(NSString **)modulePath 
                                               esmodule:(BOOL)esmodule {
    LOGI("%{public}s, moduleName : %{public}s", __func__, [moduleName UTF8String]);
    if (!moduleName.length) {
        return nil;
    }
    if (!self.allModuleFilePathArray.count) {
        LOGI("%{public}s, allModuleFilePathArray null", __func__);
        return nil;
    }

    NSArray *array = self.allModuleFilePathArray.copy;
    NSString *moduleString = esmodule ? MODULE_STAGE_ABC_NAME : FILTER_FILE_ABILITYSTAGE_ABC;
    for (NSString *path in array) {
        if ([path containsString:[NSString stringWithFormat:@"/%@/", moduleName]]
            && [path containsString:moduleString]) {
            LOGI("%{public}s, moduleName : %{public}s, \n AbilityStage.abc  : %{public}s",
                __func__, [moduleName UTF8String], [path UTF8String]);
            *modulePath = path;
            return path;
        }
    }
    return nil;
}

- (NSString *_Nullable)getModuleAbilityABCWithModuleName:(NSString *)moduleName
                                             abilityName:(NSString *)abilityName
                                              modulePath:(NSString **)modulePath
                                                esmodule:(BOOL)esmodule {
    LOGI("%{public}s, moduleName : %{public}s, abilityName : %{public}s",
        __func__, [moduleName UTF8String], [abilityName UTF8String]);
    if (!moduleName.length || !abilityName.length) {
        return nil;
    }
    if (!self.allModuleFilePathArray.count) {
        LOGI("%{public}s, allModuleFilePathArray null", __func__);
        return nil;
    }

    NSArray *array = self.allModuleFilePathArray.copy;
    if (!esmodule) {
        for (NSString *path in array) {
            if ([path containsString:[NSString stringWithFormat:@"/%@/", moduleName]]
                && [path containsString:abilityName]
                && [path containsString:FILTER_FILE_MODULE_ABC]) {
                LOGI("%{public}s, moduleName : %{public}s, abilityName : %{public}s, \n path : %{public}s",
                    __func__, [moduleName UTF8String], [abilityName UTF8String], [path UTF8String]);
                *modulePath = path;
                return path;
            }
        }
    } else {
        for (NSString *path in array) {
        if ([path containsString:[NSString stringWithFormat:@"/%@/", moduleName]]
                && [path containsString:MODULE_STAGE_ABC_NAME]) {
                LOGI("%{public}s, moduleName : %{public}s, abilityName : %{public}s, \n path : %{public}s",
                    __func__, [moduleName UTF8String], [abilityName UTF8String], [path UTF8String]);
                *modulePath = path;
                return path;
            }
        }
    }
    return nil;
}

- (void)getModuleResourcesWithModuleName:(NSString *)moduleName
                         appResIndexPath:(NSString **)appResIndexPath
                         sysResIndexPath:(NSString **)sysResIndexPath {
    LOGI("%{public}s, moduleName : %{public}s", __func__, [moduleName UTF8String]);
    if (!moduleName.length) {
        return;
    }
    if (!self.allModuleFilePathArray.count) {
        LOGI("%{public}s, allModuleFilePathArray null", __func__);
        return;
    }

    NSArray *array = self.allModuleFilePathArray.copy;
    for (NSString *path in array) {
       if ([path containsString:[NSString stringWithFormat:@"/%@/",moduleName]]
            && [path containsString:FILTER_FILE_RESOURCES_INDEX]) {
                *appResIndexPath = path;
                LOGI("%{public}s, moduleName : %{public}s, \n appResIndexPath : %{public}s",
                    __func__, [moduleName UTF8String], [path UTF8String]);
                continue;
        }
        if ([path containsString:FILTER_FILE_RESOURCES_INDEX]
            && [path containsString:FILTER_FILE_SYSTEM_RESOURCES_INDEX]) {
                LOGI("%{public}s, moduleName : %{public}s, \n sysResIndexPath : %{public}s",
                    __func__, [moduleName UTF8String], [path UTF8String]);
                *sysResIndexPath = path;
                continue;
            }
    }
}

#pragma mark - private
- (BOOL)createDocumentSubDirectoryAtPath:(NSString *)path {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSString *targetDirectory = [documentsDirectory stringByAppendingPathComponent:path];
    BOOL isSuccess = [fileManager createDirectoryAtPath:targetDirectory
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:&error];
    if (isSuccess && !error) {
        return YES;
    }
    LOGE("createDocumentSubDirectoryAtPath error");
    return NO;
}

- (BOOL)isExistFileForPath:(NSString *)filePath {
    if (!filePath.length) {
        return NO;
    }
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    BOOL isDirectroy = NO;
    BOOL result = [fileMgr fileExistsAtPath:filePath isDirectory:&isDirectroy];
    if (!isDirectroy && result) {
        return YES;
    }
    return NO;
}

#pragma mark - lazy load
- (NSMutableArray *)allModuleFilePathArray {
    if (!_allModuleFilePathArray) {
        @synchronized (self) {
            _allModuleFilePathArray = [[NSMutableArray alloc] init];
        }
    }
    return _allModuleFilePathArray;
}

- (NSMutableArray *)moduleJsonFileArray {
    if (!_moduleJsonFileArray) {
        @synchronized (self) {
            _moduleJsonFileArray = [[NSMutableArray alloc] init];
        }
    }
    return _moduleJsonFileArray;
}

- (NSMutableArray *)pkgJsonFileArray {
    if (!_pkgJsonFileArray) {
        @synchronized (self) {
            _pkgJsonFileArray = [[NSMutableArray alloc] init];
        }
    }
    return _pkgJsonFileArray;
}
@end
