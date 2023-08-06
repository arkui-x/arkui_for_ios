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
 
#import "BridgePluginManager.h"

#include <memory>
#include "base/log/log.h"
#include "base/utils/utils.h"
#include "adapter/ios/capability/bridge/bridge_manager.h"

namespace OHOS::Ace::Platform {
std::map<std::string, std::shared_ptr<BridgeReceiver>> BridgeManager::bridgeList_;
std::mutex BridgeManager::bridgeLock_;

NSString *getOCstring(const std::string& c_string)
{ 
    return [NSString stringWithCString:c_string.c_str() encoding:NSUTF8StringEncoding];
}

std::shared_ptr<BridgeReceiver> BridgeManager::FindReceiver(const std::string& bridgeName)
{
    if (bridgeName.empty()) {
        return nullptr;
    } 
    std::lock_guard<std::mutex> lock(bridgeLock_);
    auto iter = bridgeList_.find(bridgeName);
    if (iter != bridgeList_.end()) {
        return iter->second;
    }
    return nullptr;
}

bool BridgeManager::JSBridgeExists(const std::string& bridgeName)
{
    return (FindReceiver(bridgeName) != nullptr);
}

bool BridgeManager::JSRegisterBridge(const std::string& bridgeName,
    std::shared_ptr<BridgeReceiver> callback)
{
    if (bridgeName.empty()) {
        return false;
    }
    std::lock_guard<std::mutex> lock(bridgeLock_);
    auto iter = bridgeList_.find(bridgeName);
    if (iter == bridgeList_.end()) {
        bridgeList_[bridgeName] = callback;
        NSLog(@"%s, register success, bridgeName : %@", __func__, getOCstring(bridgeName));
        return true;
    }
    return false;
}

void BridgeManager::JSUnRegisterBridge(const std::string& bridgeName)
{
    std::lock_guard<std::mutex> lock(bridgeLock_);
    auto iter = bridgeList_.find(bridgeName);
    if (iter != bridgeList_.end()) {
        bridgeList_.erase(iter);
    }
}

void BridgeManager::JSCallMethod(const std::string& bridgeName, const std::string& methodName,
    const std::string& parameter)
{
    NSString *oc_bridgeName = getOCstring(bridgeName);
    NSString *oc_methodName = getOCstring(methodName);
    NSString *oc_parameter = getOCstring(parameter);
    NSLog(@"%s, oc_bridgeName : %@, oc_methodName : %@, oc_parameter : %@", __func__,
        oc_bridgeName, oc_methodName, oc_parameter);
    [[BridgePluginManager shareManager] jsCallMethod:oc_bridgeName 
                                             methodName:oc_methodName
                                                  param:oc_parameter];
}

void BridgeManager::JSSendMethodResult(const std::string& bridgeName,const std::string& methodName,
    const std::string& resultValue)
{
    NSString *oc_bridgeName = getOCstring(bridgeName);
    NSString *oc_methodName = getOCstring(methodName);
    NSString *oc_resultValue = getOCstring(resultValue);
    NSLog(@"%s, oc_bridgeName : %@, oc_methodName : %@, oc_resultValue : %@", __func__,
        oc_bridgeName, oc_methodName, oc_resultValue);
    [[BridgePluginManager shareManager] jsSendMethodResult:oc_bridgeName 
                                                   methodName:oc_methodName 
                                                       result:oc_resultValue];
}

void BridgeManager::JSSendMessage(const std::string& bridgeName, const std::string& data)
{
    NSString *oc_bridgeName = getOCstring(bridgeName);
    NSString *oc_data = getOCstring(data);
    NSLog(@"%s, oc_bridgeName : %@, oc_data : %@", __func__, oc_bridgeName, oc_data);
    [[BridgePluginManager shareManager] jsSendMessage:oc_bridgeName
                                                    data:oc_data];
}

void BridgeManager::JSSendMessageResponse(const std::string& bridgeName, const std::string& data)
{
    NSString *oc_bridgeName = getOCstring(bridgeName);
    NSString *oc_data = getOCstring(data);
    NSLog(@"%s, oc_bridgeName : %@, oc_data : %@", __func__, oc_bridgeName, oc_data);
    [[BridgePluginManager shareManager] jsSendMessageResponse:oc_bridgeName
                                                            data:oc_data];
}

void BridgeManager::JSCancelMethod(const std::string& bridgeName, const std::string& methodName)
{
    NSString *oc_bridgeName = getOCstring(bridgeName);
    NSString *oc_methodName = getOCstring(methodName);
    NSLog(@"%s, oc_bridgeName : %@, oc_methodName : %@", __func__, oc_bridgeName, oc_methodName);
    [[BridgePluginManager shareManager] jsCancelMethod:oc_bridgeName
                                               methodName:oc_methodName];

}

void BridgeManager::PlatformCallMethod(const std::string& bridgeName, const std::string& methodName,
    const std::string& parameter)
{
    NSLog(@"%s, bridgeName : %@, methodName : %@,para : %@", __func__,
    getOCstring(bridgeName), getOCstring(methodName), getOCstring(parameter));

    if (!JSBridgeExists(bridgeName)) {
        std::string errorData = "{\"result\":\"errorcode\",\"errorcode\":1}";
        JSSendMethodResult(bridgeName, methodName, errorData);
        return;
    }
    auto receiver = FindReceiver(bridgeName);
    if (receiver && receiver->callMethodCallback_) {
        receiver->callMethodCallback_(methodName, parameter);
    }
}

void BridgeManager::PlatformSendMethodResult(const std::string& bridgeName,
    const std::string& methodName, const std::string& result)
{
    NSLog(@"%s, bridgeName : %@, methodName : %@, result : %@", __func__,
    getOCstring(bridgeName), getOCstring(methodName), getOCstring(result));
    auto receiver = FindReceiver(bridgeName);
    if (receiver && receiver->methodResultCallback_) {
        receiver->methodResultCallback_(methodName, result);
    }
}

void BridgeManager::PlatformSendMessage(const std::string& bridgeName, const std::string& data)
{
    NSLog(@"%s, bridgeName : %@, data : %@", __func__, getOCstring(bridgeName), getOCstring(data));

    if (!JSBridgeExists(bridgeName)) {
        std::string errorData = "{\"result\":\"errorcode\",\"errorcode\":1}";
        JSSendMessageResponse(bridgeName, errorData);
        return;
    }
    auto receiver = FindReceiver(bridgeName);
    if (receiver && receiver->sendMessageCallback_) {
        receiver->sendMessageCallback_(data);
    }
}

void BridgeManager::PlatformSendMessageResponse(const std::string& bridgeName,
    const std::string& data)
{
    NSLog(@"%s, bridgeName : %@, data : %@", __func__, getOCstring(bridgeName), getOCstring(data));
    auto receiver = FindReceiver(bridgeName);
    if (receiver && receiver->sendMessageResponseCallback_) {
        receiver->sendMessageResponseCallback_(data);
    }
}

void BridgeManager::PlatformSendWillTerminate() {
    if (!bridgeList_.empty()) {
        auto iter = bridgeList_.begin();
        while (iter != bridgeList_.end()) {
            auto receiver = iter->second;
            if (receiver && receiver->sendWillTerminateResponseCallback_) {
                receiver->sendWillTerminateResponseCallback_(true);
            }
            ++iter;
        }
    }
}
} // namespace OHOS::Ace::Platform
