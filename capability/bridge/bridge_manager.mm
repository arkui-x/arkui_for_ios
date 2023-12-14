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

#import "BridgeBinaryCodec.h"
#import "BridgeCodecUtil.h"
#import "BridgeJsonCodec.h"
#import "BridgePluginManager.h"

#include "adapter/ios/capability/bridge/bridge_manager.h"
#include "base/log/log.h"
#include "base/utils/utils.h"
#include <memory>

namespace OHOS::Ace::Platform {
std::map<std::string, std::shared_ptr<BridgeReceiver>> BridgeManager::bridgeList_;
std::mutex BridgeManager::bridgeLock_;

NSString* getOCstring(const std::string& c_string) {
    return [NSString stringWithCString:c_string.c_str() encoding:NSUTF8StringEncoding];
}

NSData* convertToNSData(const std::vector<uint8_t>& data) {
    if (&data == nullptr) {
        return nil;
    }
    return [NSData dataWithBytes:data.data() length:data.size()];
}

NSData* ConvertUniqueUNint8ToNSData(std::unique_ptr<std::vector<uint8_t>> result) {
    if (!result) {
        return nil;
    }
    const uint8_t* bytes = result->data();
    size_t length = result->size();

    return [NSData dataWithBytes:bytes length:length];
}

std::shared_ptr<BridgeReceiver> BridgeManager::FindReceiver(const std::string& bridgeName) {
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

bool BridgeManager::JSBridgeExists(const std::string& bridgeName) {
    return (FindReceiver(bridgeName) != nullptr);
}

bool BridgeManager::JSRegisterBridge(const std::string& bridgeName,
                                     std::shared_ptr<BridgeReceiver> callback) {
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

void BridgeManager::JSUnRegisterBridge(const std::string& bridgeName) {
    std::lock_guard<std::mutex> lock(bridgeLock_);
    auto iter = bridgeList_.find(bridgeName);
    if (iter != bridgeList_.end()) {
        bridgeList_.erase(iter);
        NSLog(@"%s, unregister success, bridgeName : %@", __func__, getOCstring(bridgeName));
    }
}

void BridgeManager::JSCallMethod(const std::string& bridgeName, 
                const std::string& methodName, const std::string& parameter) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    NSString* oc_parameter = getOCstring(parameter);
    NSLog(@"%s, oc_bridgeName : %@, oc_methodName : %@, oc_parameter : %@", __func__, 
                oc_bridgeName, oc_methodName, oc_parameter);
    [[BridgePluginManager shareManager] jsCallMethod:oc_bridgeName
                                          methodName:oc_methodName
                                               param:oc_parameter];
}

void BridgeManager::JSSendMethodResult(const std::string& bridgeName, 
                const std::string& methodName, const std::string& resultValue) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    NSString* oc_resultValue = getOCstring(resultValue);
    NSLog(@"%s, oc_bridgeName : %@, oc_methodName : %@, oc_resultValue : %@", __func__, 
                oc_bridgeName, oc_methodName, oc_resultValue);
    [[BridgePluginManager shareManager] jsSendMethodResult:oc_bridgeName
                                                methodName:oc_methodName
                                                    result:oc_resultValue];
}

void BridgeManager::JSSendMessage(const std::string& bridgeName, const std::string& data) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_data = getOCstring(data);
    NSLog(@"%s, oc_bridgeName : %@, oc_data : %@", __func__, oc_bridgeName, oc_data);
    RawValue* rawValue = [[BridgeJsonCodec sharedInstance] decode:oc_data];
    [[BridgePluginManager shareManager] jsSendMessage:oc_bridgeName
                                                 data:rawValue.result];
}

void BridgeManager::JSSendMessageResponse(const std::string& bridgeName, const std::string& data) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_data = getOCstring(data);
    NSLog(@"%s, oc_bridgeName : %@, oc_data : %@", __func__, oc_bridgeName, oc_data);
    [[BridgePluginManager shareManager] jsSendMessageResponse:oc_bridgeName
                                                         data:oc_data];
}

void BridgeManager::JSCancelMethod(const std::string& bridgeName, const std::string& methodName) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    NSLog(@"%s, oc_bridgeName : %@, oc_methodName : %@", __func__, oc_bridgeName, oc_methodName);
    [[BridgePluginManager shareManager] jsCancelMethod:oc_bridgeName
                                            methodName:oc_methodName];
}

void BridgeManager::PlatformCallMethod(const std::string& bridgeName,
                const std::string& methodName, const std::string& parameter) {
    NSLog(@"%s, bridgeName : %@, methodName : %@,para : %@", __func__, 
            getOCstring(bridgeName), getOCstring(methodName), getOCstring(parameter));

    if (!JSBridgeExists(bridgeName)) {
        std::string errorData = "{\"result\":\"errorCode\",\"errorCode\":1}";
        JSSendMethodResult(bridgeName, methodName, errorData);
        return;
    }
    auto receiver = FindReceiver(bridgeName);
    if (receiver && receiver->callMethodCallback_) {
        receiver->callMethodCallback_(methodName, parameter);
    }
}

void BridgeManager::PlatformSendMethodResult(const std::string& bridgeName,
                const std::string& methodName,
                const std::string& result) {
    NSLog(@"%s, bridgeName : %@, methodName : %@, result : %@", __func__, 
            getOCstring(bridgeName), getOCstring(methodName), getOCstring(result));
    auto receiver = FindReceiver(bridgeName);
    if (receiver && receiver->methodResultCallback_) {
        receiver->methodResultCallback_(methodName, result);
    }
}

void BridgeManager::PlatformSendMessage(const std::string& bridgeName, const std::string& data) {
    NSLog(@"%s, bridgeName : %@, data : %@", __func__, getOCstring(bridgeName), getOCstring(data));
    if (!JSBridgeExists(bridgeName)) {
        std::string errorData = "{\"result\":\"errorCode\",\"errorCode\":1}";
        JSSendMessageResponse(bridgeName, errorData);
        return;
    }
    auto receiver = FindReceiver(bridgeName);
    if (receiver && receiver->sendMessageCallback_) {
        receiver->sendMessageCallback_(data);
    }
}

void BridgeManager::PlatformSendMessageResponse(const std::string& bridgeName,
                                                const std::string& data) {
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

void BridgeManager::JSSendMessageBinary(const std::string& bridgeName, const std::vector<uint8_t>& data) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    [[BridgePluginManager shareManager] jsSendMessageBinary:oc_bridgeName
                                                       data:convertToNSData(data)];
}

void BridgeManager::JSCallMethodBinary(const std::string& bridgeName,
                                       const std::string& methodName,
                                       const std::vector<uint8_t>& data) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    NSData* oc_data = convertToNSData(data);
    [[BridgePluginManager shareManager] jsCallMethodBinary:oc_bridgeName
                                                methodName:oc_methodName
                                                     param:oc_data];
}

void BridgeManager::JSSendMethodResultBinary(const std::string& bridgeName, 
                const std::string& methodName, 
                int errorCode, 
                const std::string& errorMessage, std::unique_ptr<std::vector<uint8_t>> result) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    NSString* oc_errorMessage = getOCstring(errorMessage);
    NSData* oc_data = ConvertUniqueUNint8ToNSData(std::move(result));
    [[BridgePluginManager shareManager] jsSendMethodResultBinary:oc_bridgeName
                                                      methodName:oc_methodName
                                                       errorCode:errorCode
                                                    errorMessage:oc_errorMessage
                                                          result:oc_data];
}

void BridgeManager::PlatformSendMethodResultBinary(const std::string& bridgeName,
                const std::string& methodName,
                int errorCode, const std::string& errorMessage, std::unique_ptr<BufferMapping> result) {
    auto receiver = FindReceiver(bridgeName);
    if (receiver && receiver->methodResultBinaryCallback_) {
        receiver->methodResultBinaryCallback_(methodName, errorCode, errorMessage, std::move(result));
    }
}

void BridgeManager::PlatformCallMethodBinary(const std::string& bridgeName,
                                             const std::string& methodName,
                                             std::unique_ptr<BufferMapping> parameter) {
    auto receiver = FindReceiver(bridgeName);
    if (receiver && receiver->callMethodBinaryCallback_) {
        receiver->callMethodBinaryCallback_(methodName, std::move(parameter));
    }
}

void BridgeManager::PlatformSendMessageBinary(const std::string& bridgeName, std::unique_ptr<BufferMapping> data) {
    auto receiver = FindReceiver(bridgeName);
    if (receiver && receiver->sendMessageBinaryCallback_) {
        receiver->sendMessageBinaryCallback_(std::move(data));
    }
}
} // namespace OHOS::Ace::Platform
