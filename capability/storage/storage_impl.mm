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

#include "adapter/ios/capability/storage/storage_impl.h"

#import <Foundation/Foundation.h>

namespace OHOS::Ace::Platform {

StorageImpl::StorageImpl(const RefPtr<TaskExecutor>& taskExecutor) : Storage(taskExecutor) {}

void StorageImpl::SetString(const std::string& key, const std::string& value)
{
    if (taskExecutor_) {
        taskExecutor_->PostSyncTask([key, value] {
          NSString *strKey = [NSString stringWithCString:key.c_str() encoding:NSUTF8StringEncoding];
          NSString *strVal = [NSString stringWithCString:value.c_str() encoding:NSUTF8StringEncoding];
          [[NSUserDefaults standardUserDefaults] setObject:strVal?:@"" forKey:strKey];
          [[NSUserDefaults standardUserDefaults] synchronize]; 
        }, TaskExecutor::TaskType::JS);
    }
}

std::string StorageImpl::GetString(const std::string& key)
{
    std::string result;
    if (taskExecutor_) {
        taskExecutor_->PostSyncTask([key, &result] {
           result = "";
           NSString *strKey = [NSString stringWithCString:key.c_str() encoding:NSUTF8StringEncoding];
           NSObject *strObj =[[NSUserDefaults standardUserDefaults] objectForKey:strKey];
            if ([strObj isKindOfClass:[NSString class]]) {
               NSString *strValue = (NSString *)strObj;
               result = strValue.UTF8String;
            }
        }, TaskExecutor::TaskType::JS);
    }
    return result;
}

void StorageImpl::SetDouble(const std::string& key, const double value)
{
    if (taskExecutor_) {
        taskExecutor_->PostSyncTask([key, value] {
            NSString *strKey = [NSString stringWithCString:key.c_str() encoding:NSUTF8StringEncoding];
            [[NSUserDefaults standardUserDefaults] setDouble:value forKey:strKey];
            [[NSUserDefaults standardUserDefaults] synchronize]; 
        }, TaskExecutor::TaskType::JS);
    }
}

bool StorageImpl::GetDouble(const std::string& key, double& value)
{
    if (taskExecutor_) {
        taskExecutor_->PostSyncTask([key, &value] { 
           NSString *strKey = [NSString stringWithCString:key.c_str() encoding:NSUTF8StringEncoding];
           value =[[NSUserDefaults standardUserDefaults] doubleForKey:strKey]; 
        }, TaskExecutor::TaskType::JS);
    }
    return true;
}

void StorageImpl::SetBoolean(const std::string& key, const bool value)
{
    if (taskExecutor_) {
        taskExecutor_->PostSyncTask([key, value] {
            NSString *strKey = [NSString stringWithCString:key.c_str() encoding:NSUTF8StringEncoding];
            [[NSUserDefaults standardUserDefaults] setBool:value ? YES : NO forKey:strKey];
            [[NSUserDefaults standardUserDefaults] synchronize]; 
        }, TaskExecutor::TaskType::JS);
    }
}

bool StorageImpl::GetBoolean(const std::string& key, bool& value)
{
    if (taskExecutor_) {
        taskExecutor_->PostSyncTask([key, &value] { 
           NSString *strKey = [NSString stringWithCString:key.c_str() encoding:NSUTF8StringEncoding];
           value = [[NSUserDefaults standardUserDefaults] boolForKey:strKey] ? true : false; 
        }, TaskExecutor::TaskType::JS);
    }
    return true;
}

void StorageImpl::Clear()
{
    if (taskExecutor_) {
        taskExecutor_->PostSyncTask([] {
            NSUserDefaults *defatluts = [NSUserDefaults standardUserDefaults];
            NSDictionary *dictionary = [defatluts dictionaryRepresentation];
            for(NSString *key in [dictionary allKeys]){
              [defatluts removeObjectForKey:key];
            }
            [defatluts synchronize];
        }, TaskExecutor::TaskType::JS);
    }
}

void StorageImpl::Delete(const std::string& key)
{
    if (taskExecutor_) {
        taskExecutor_->PostSyncTask([key] {
            NSString *strKey = [NSString stringWithCString:key.c_str() encoding:NSUTF8StringEncoding];
            NSObject *strObj =[[NSUserDefaults standardUserDefaults] objectForKey:strKey];
            if (strObj) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:strKey];
            }
        }, TaskExecutor::TaskType::JS);
    }
}

} // namespace OHOS::Ace::Platform
