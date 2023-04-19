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

#import <XCTest/XCTest.h>
#import <libarkui_ios/StageApplication.h>
#import <libarkui_ios/StageViewController.h>
#import <libarkui_ios/StageConfigurationManager.h>
#import <libarkui_ios/StageAssetManager.h>

@interface StageTest : XCTestCase {
    StageViewController *_testVCMock;
    StageConfigurationManager *testConfigurationManager;
    StageAssetManager *testAssetManager;
}

@end

#define TEST_BUNDLE_DIRECTORY @"arkui-x"
#define TEST_MODULE_NAME @"entry"
#define TEST_ABILITY_NAME @"EntryAbility"
#define TEST_ABILITY_NAME_NOSINGLETON @"SecondTestAbility"
#define TEST_BUNDLE_NAME @"com.example.ljhTest"
#define TEST_DIRECTIONL 1
#define TEST_COLOR_MODE 1
#define FAILED_MESSAGE @"FAILED!"
@implementation StageTest

- (void)setUp {
    NSString *instanceName = [NSString stringWithFormat:@"%@:%@:%@", TEST_BUNDLE_NAME, TEST_MODULE_NAME, TEST_ABILITY_NAME];
    _testVCMock = [[StageViewController alloc] initWithInstanceName:instanceName];
    testConfigurationManager = [StageConfigurationManager configurationManager];
    testAssetManager = [StageAssetManager assetManager];
}

- (void)tearDown {
    _testVCMock = nil;
    testConfigurationManager = nil;
    testAssetManager = nil;
}

- (void)testInitStageViewController_0100 {
    XCTAssertNotNil(_testVCMock, FAILED_MESSAGE);
}

- (void)testStageViewControllerInstaceNameExist_0200 {
    XCTAssertNotNil(_testVCMock.instanceName, FAILED_MESSAGE);
}

- (void)testGetStageViewControllerInstaceNameIsRule_0100 {
    int32_t instanceId = [_testVCMock getInstanceId];
    NSString *instanceName = [NSString stringWithFormat:@"%@:%@:%@:%d",
                              TEST_BUNDLE_NAME,
                              TEST_MODULE_NAME,
                              TEST_ABILITY_NAME,
                              instanceId];
    XCTAssertEqualObjects(instanceName, _testVCMock.instanceName, FAILED_MESSAGE);
}

- (void)testGetInstanceId_0200 {
    int32_t instanceId = [_testVCMock getInstanceId];
    XCTAssertFalse(instanceId < 0, FAILED_MESSAGE);
}

- (void)testLaunchApplication0100 {
    XCTAssertNoThrow([StageApplication launchApplication], FAILED_MESSAGE);
}

- (void)testConfigModule_0100 {
    XCTAssertNoThrow([StageApplication configModuleWithBundleDirectory:TEST_BUNDLE_DIRECTORY], FAILED_MESSAGE);
}

- (void)testCallCurrentAbilityOnForeground_0100 {
    XCTAssertNoThrow([StageApplication callCurrentAbilityOnForeground], FAILED_MESSAGE);
}

- (void)testCallCurrentAbilityOnBackground_0100 {
    XCTAssertNoThrow([StageApplication callCurrentAbilityOnBackground], FAILED_MESSAGE);
}

- (void)testIsSingletonAbility_0100 {
    BOOL isSingleton = [StageApplication handleSingleton:TEST_BUNDLE_NAME
                                              moduleName:TEST_MODULE_NAME
                                             abilityName:TEST_ABILITY_NAME];
    XCTAssertTrue(isSingleton, FAILED_MESSAGE);
}

- (void)testNoSingletonAbility_0200 {
    BOOL isSingleton = [StageApplication handleSingleton:TEST_BUNDLE_NAME
                                              moduleName:TEST_MODULE_NAME
                                             abilityName:TEST_ABILITY_NAME_NOSINGLETON];
    XCTAssertFalse(isSingleton, FAILED_MESSAGE);
}

- (void)testHandleSingletonAbilityThrow_0300 {
    XCTAssertNoThrow([StageApplication handleSingleton:TEST_BUNDLE_NAME
                                            moduleName:TEST_MODULE_NAME
                                           abilityName:TEST_ABILITY_NAME], FAILED_MESSAGE);
}

- (void)testReleaseViewControllers_0100 {
    XCTAssertNoThrow([StageApplication releaseViewControllers], FAILED_MESSAGE);
}

- (void)testGetTopViewController_0100 {
    StageViewController *topVC = [StageApplication getApplicationTopViewController];
    XCTAssertNotNil(topVC, FAILED_MESSAGE);
}

- (void)testConfigurationManagerIsSingleton_0100 {
    NSMutableArray *managerList = [NSMutableArray array];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        StageConfigurationManager *tempManager = [[StageConfigurationManager alloc] init];
        [managerList addObject:tempManager];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        StageConfigurationManager *tempManager = [[StageConfigurationManager alloc] init];
        [managerList addObject:tempManager];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        StageConfigurationManager *tempManager = [StageConfigurationManager configurationManager];
        [managerList addObject:tempManager];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        StageConfigurationManager *tempManager = [StageConfigurationManager configurationManager];
        [managerList addObject:tempManager];
    });
    
    StageConfigurationManager *managerOne = [StageConfigurationManager configurationManager];
    [managerList enumerateObjectsUsingBlock:^(StageConfigurationManager *obj, NSUInteger idx, BOOL *_Nonnull stop) {
        XCTAssertEqual(managerOne, obj, FAILED_MESSAGE);
    }];
}

- (void)testSetDirection_0100 {
    XCTAssertNoThrow([testConfigurationManager setDirection:TEST_DIRECTIONL], FAILED_MESSAGE);
}

- (void)testDirectionUpdate_0100 {
    XCTAssertNoThrow([testConfigurationManager directionUpdate:TEST_DIRECTIONL], FAILED_MESSAGE);
}

- (void)testSetColorMode_0100 {
    XCTAssertNoThrow([testConfigurationManager setColorMode:TEST_COLOR_MODE], FAILED_MESSAGE);
}

- (void)testColorModeUpdate_0100 {
    XCTAssertNoThrow([testConfigurationManager colorModeUpdate:TEST_COLOR_MODE], FAILED_MESSAGE);
}

- (void)testRegistConfiguration_0100 {
    XCTAssertNoThrow([testConfigurationManager registConfiguration], FAILED_MESSAGE);
}

- (void)testAssetManagerIsSingleton_0100 {
    NSMutableArray *managers = [NSMutableArray array];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        StageAssetManager *tempManager = [[StageAssetManager alloc] init];
        [managers addObject:tempManager];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        StageAssetManager *tempManager = [[StageAssetManager alloc] init];
        [managers addObject:tempManager];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        StageAssetManager *tempManager = [StageAssetManager assetManager];
        [managers addObject:tempManager];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        StageAssetManager *tempManager = [StageAssetManager assetManager];
        [managers addObject:tempManager];
    });
    
    StageAssetManager *managerOne = [StageAssetManager assetManager];
    [managers enumerateObjectsUsingBlock:^(StageAssetManager *obj, NSUInteger idx, BOOL *_Nonnull stop) {
        XCTAssertEqual(managerOne, obj, FAILED_MESSAGE);
    }];
}

- (void)testModuleFilesWithbundleDirectory_0100 {
    XCTAssertNoThrow([testAssetManager moduleFilesWithbundleDirectory:TEST_BUNDLE_DIRECTORY], FAILED_MESSAGE);
}

- (void)testLaunchAbility_0100 {
    XCTAssertNoThrow([testAssetManager launchAbility], FAILED_MESSAGE);
}

- (void)testGetBundlePath_0100 {
    NSString *bundlePath = [NSString stringWithFormat:@"%@/%@", [NSBundle mainBundle].bundlePath, TEST_BUNDLE_DIRECTORY];
    NSString *testbundlePath = [testAssetManager getBundlePath];
    XCTAssertEqualObjects(bundlePath, testbundlePath, FAILED_MESSAGE);
}

- (void)testGetAssetAllFilePathList_0100 {
    NSArray *allFilePaths = [testAssetManager getAssetAllFilePathList];
    XCTAssertGreaterThan(allFilePaths.count, 0, FAILED_MESSAGE);
}

- (void)testGetModuleJsonFileList_0100 {
    NSArray *moduleJsonPaths = [testAssetManager getModuleJsonFileList];
    XCTAssertGreaterThan(moduleJsonPaths.count, 0, FAILED_MESSAGE);
}

- (void)testGetAbilityStageABCFile_0100 {
    NSString *modulePath = @"";
    NSString *abcFilePath = [testAssetManager getAbilityStageABCWithModuleName:TEST_MODULE_NAME
                                                                    modulePath:&modulePath];
    XCTAssertTrue(abcFilePath.length > 0, FAILED_MESSAGE);
}

- (void)testGetAbilityStageABCFile_0200 {
    NSString *modulePath = @"";
    NSString *abcFilePath = [testAssetManager getAbilityStageABCWithModuleName:TEST_MODULE_NAME
                                                                    modulePath:&modulePath];
    XCTAssertTrue(modulePath.length > 0, FAILED_MESSAGE);
}

- (void)testGetModuleResources_0100 {
    NSString *appResIndexPath = @"";
    NSString *sysResIndexPath = @"";
    [testAssetManager getModuleResourcesWithModuleName:TEST_MODULE_NAME
                                       appResIndexPath:&appResIndexPath
                                       sysResIndexPath:&sysResIndexPath];
    XCTAssertTrue(appResIndexPath.length > 0, FAILED_MESSAGE);
}

- (void)testGetModuleResources_0200 {
    NSString *appResIndexPath = @"";
    NSString *sysResIndexPath = @"";
    [testAssetManager getModuleResourcesWithModuleName:TEST_MODULE_NAME
                                       appResIndexPath:&appResIndexPath
                                       sysResIndexPath:&sysResIndexPath];
    XCTAssertTrue(sysResIndexPath.length > 0, FAILED_MESSAGE);
}

- (void)testGetModuleAbilityABCFile_0100 {
    NSString *modulePath = @"";
    NSString *moduleAbcFilePath = [testAssetManager getModuleAbilityABCWithModuleName:TEST_MODULE_NAME
                                                                          abilityName:TEST_ABILITY_NAME
                                                                           modulePath:&modulePath];
    XCTAssertTrue(moduleAbcFilePath.length > 0, FAILED_MESSAGE);
    XCTAssertTrue(modulePath.length > 0, FAILED_MESSAGE);
}

@end
