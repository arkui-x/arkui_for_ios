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

#import "StageAssetManager.h"

#include "app_main.h"

using AppMain = OHOS::AbilityRuntime::Platform::AppMain;
#define FILTER_FILE_MODULE_JSON @"module.json"
#define FILTER_FILE_ABILITYSTAGE_ABC @"AbilityStage.abc"
#define MODULE_STAGE_ABC_NAME @"modules.abc"
#define FILTER_FILE_MODULE_ABC @".abc"
#define FILTER_FILE_RESOURCES_INDEX @"resources.index"
#define FILTER_FILE_SYSTEM_RESOURCES_INDEX @"systemres"
#define DOCUMENTS_SUBDIR_FILES @"files"
#define DOCUMENTS_SUBDIR_DATABASE @"database"

@interface StageAssetManager ()

@property (nonatomic, strong) NSMutableArray *allModuleFilePathArray;

@property (nonatomic, strong) NSMutableArray *moduleJsonFileArray;

@property (nonatomic, strong) NSString *bundlePath;

@end

@implementation StageAssetManager

+ (instancetype)assetManager {
    static StageAssetManager *_assetManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"StageManager share instance");
        _assetManager = [[StageAssetManager alloc] init];
    });
    return _assetManager;
}

- (void)moduleFilesWithbundleDirectory:(NSString *_Nonnull)bundleDirectory {
    NSError *error = nil;
    NSMutableArray *files = [[NSMutableArray alloc] init];
    NSString *bundlePath = [NSString stringWithFormat:@"%@/%@", [NSBundle mainBundle].bundlePath, bundleDirectory];
    NSLog(@"%s, \n bundlePath is : %@", __func__, bundlePath);
    self.bundlePath = bundlePath;
    NSArray *moduleArray = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:bundlePath error:&error];
    if (!error && moduleArray.count > 0) {
        for (NSString *subFile in moduleArray) {
            NSString *filePath = [NSString stringWithFormat:@"%@/%@", bundlePath, subFile];
            if ([self isExistFileForPath:filePath]) {
                if ([subFile containsString:FILTER_FILE_MODULE_JSON]) {
                    @synchronized (self) {
                        [self.moduleJsonFileArray addObject:filePath];
                    }
                }
                [files addObject:filePath];
            }
        }
    }
    NSLog(@"%s, all files count : %lu", __func__, (unsigned long)files.count);
    @synchronized (self) {
        [self.allModuleFilePathArray addObjectsFromArray:files.copy];
    }

    BOOL isCreatFiles = [self createDocumentSubDirectoryAtPath:DOCUMENTS_SUBDIR_FILES];
    BOOL isCreatDatabase = [self createDocumentSubDirectoryAtPath:DOCUMENTS_SUBDIR_DATABASE];
    NSLog(@"isCreatFiles : %d, isCreatDatabase : %d", isCreatFiles, isCreatDatabase);
}

- (void)launchAbility {
    NSLog(@"%s", __func__);
    AppMain::GetInstance()->LaunchApplication();
}

- (NSString *_Nullable)getBundlePath {
    NSLog(@"%s", __func__);
    return self.bundlePath;
}

- (NSArray *_Nullable)getAssetAllFilePathList {
    @synchronized (self) {
        NSLog(@"%s, \n all asset file list : %@", __func__, self.allModuleFilePathArray);
        return self.allModuleFilePathArray.copy;
    }
}

- (NSArray *_Nullable)getModuleJsonFileList {
    @synchronized (self) {
        NSLog(@"%s, \n modulejson file list : %@", __func__, self.moduleJsonFileArray);
        return self.moduleJsonFileArray.copy;
    }
}

- (NSString *_Nullable)getAbilityStageABCWithModuleName:(NSString *)moduleName
                                             modulePath:(NSString **)modulePath 
                                               esmodule:(BOOL)esmodule {
    NSLog(@"%s, moduleName : %@", __func__, moduleName);
    if (!moduleName.length) {
        return nil;
    }
    if (!self.allModuleFilePathArray.count) {
        NSLog(@"%s, allModuleFilePathArray null", __func__);
        return nil;
    }

    NSArray *array = self.allModuleFilePathArray.copy;
    NSString *moduleString = esmodule ? MODULE_STAGE_ABC_NAME : FILTER_FILE_ABILITYSTAGE_ABC;
    for (NSString *path in array) {
        if ([path containsString:[NSString stringWithFormat:@"/%@/", moduleName]]
            && [path containsString:moduleString]) {
            NSLog(@"%s, moduleName : %@, \n AbilityStage.abc  : %@", __func__, moduleName, path);
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
    NSLog(@"%s, moduleName : %@, abilityName : %@", __func__, moduleName, abilityName);
    if (!moduleName.length || !abilityName.length) {
        return nil;
    }
    if (!self.allModuleFilePathArray.count) {
        NSLog(@"%s, allModuleFilePathArray null", __func__);
        return nil;
    }

    NSArray *array = self.allModuleFilePathArray.copy;
    if (!esmodule) {
        for (NSString *path in array) {
            if ([path containsString:[NSString stringWithFormat:@"/%@/", moduleName]]
                && [path containsString:abilityName]
                && [path containsString:FILTER_FILE_MODULE_ABC]) {
                NSLog(@"%s, moduleName : %@, abilityName : %@, \n path : %@", __func__, moduleName, abilityName, path);
                *modulePath = path;
                return path;
            }
        }
    } else {
        for (NSString *path in array) {
        if ([path containsString:[NSString stringWithFormat:@"/%@/", moduleName]]
                && [path containsString:MODULE_STAGE_ABC_NAME]) {
                NSLog(@"%s, moduleName : %@, abilityName : %@, \n path : %@", __func__, moduleName, abilityName, path);
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
    NSLog(@"%s, moduleName : %@", __func__, moduleName);
    if (!moduleName.length) {
        return;
    }
    if (!self.allModuleFilePathArray.count) {
        NSLog(@"%s, allModuleFilePathArray null", __func__);
        return;
    }

    NSArray *array = self.allModuleFilePathArray.copy;
    for (NSString *path in array) {
       if ([path containsString:[NSString stringWithFormat:@"/%@/",moduleName]]
            && [path containsString:FILTER_FILE_RESOURCES_INDEX]) {
                *appResIndexPath = path;
                NSLog(@"%s, moduleName : %@, \n appResIndexPath : %@", __func__, moduleName, path);
                continue;
        }
        if ([path containsString:FILTER_FILE_RESOURCES_INDEX]
            && [path containsString:FILTER_FILE_SYSTEM_RESOURCES_INDEX]) {
                NSLog(@"%s, moduleName : %@, \n sysResIndexPath : %@", __func__, moduleName, path);
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

@end
