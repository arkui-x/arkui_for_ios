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
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ACE_VERSION) {
    ACE_VERSION_JS = 1,    // default. web like js app version
    ACE_VERSION_ETS = 2,   // declarative ets app version
};

@interface AceViewController : UIViewController

/**
 * create AceViewController instance
 *
 * @param version  Ace version.
 * @param bundleDirectory js bundle directory.Can not be null
 * @return AceViewController instance
 */
-(instancetype)initWithVersion:(ACE_VERSION)version
               bundleDirectory:(nonnull NSString*)bundleDirectory;

@property(nonatomic,readonly) ACE_VERSION version;
@property(nonatomic,readonly) NSString *bundleDirectory;

@end

NS_ASSUME_NONNULL_END
