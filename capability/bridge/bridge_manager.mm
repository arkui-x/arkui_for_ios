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

#include "adapter/ios/capability/bridge/bridge_manager.h"

#include <memory>

#include "base/log/log.h"
#include "base/utils/utils.h"
#import "BridgeBinaryCodec.h"
#import "BridgePluginManager+internal.h"
#import "BridgeManagerHolder.h"

namespace OHOS::Ace::Platform {
std::map<int32_t, std::map<std::string, std::shared_ptr<BridgeReceiver>>> BridgeManager::bridgeList_;
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

BridgePluginManager* getBridgePluginManagerWithInstanceId(int32_t instanceId) {
    BridgePluginManager* bridgePluginManager = [BridgeManagerHolder getBridgeManagerWithInceId:instanceId];
    return bridgePluginManager;
}

std::shared_ptr<BridgeReceiver> BridgeManager::FindReceiver(int32_t instanceId, const std::string& bridgeName) {
    if (bridgeName.empty()) {
        return nullptr;
    }
    std::lock_guard<std::mutex> lock(bridgeLock_);
    auto instanceIdIter = bridgeList_.find(instanceId);
    if (instanceIdIter != bridgeList_.end()) {
        auto bridgeIter = instanceIdIter->second.find(bridgeName);
        if (bridgeIter != instanceIdIter->second.end()) {
            return bridgeIter->second;
        }
    }
    return nullptr;
}

bool BridgeManager::JSBridgeExists(int32_t instanceId, const std::string& bridgeName) {
    return FindReceiver(instanceId, bridgeName) != nullptr;
}

bool BridgeManager::JSRegisterBridge(int32_t instanceId, std::shared_ptr<BridgeReceiver> callback) {
    if (callback->bridgeName_.empty() || instanceId < 0) {
        return false;
    }
    std::lock_guard<std::mutex> lock(bridgeLock_);
    auto instanceIdIter = bridgeList_.find(instanceId);
    if (instanceIdIter == bridgeList_.end()) {
        std::map<std::string, std::shared_ptr<BridgeReceiver>> bridgeList;
        bridgeList[callback->bridgeName_] = callback;
        bridgeList_[instanceId] = bridgeList;
        return true;
    } else {
        auto bridgeIter = instanceIdIter->second.find(callback->bridgeName_);
        if (bridgeIter == instanceIdIter->second.end()) {
            instanceIdIter->second[callback->bridgeName_] = callback;
            return true;
        }
    }
    return false;
}

void BridgeManager::JSUnRegisterBridge(int32_t instanceId, const std::string& bridgeName) {
    if (bridgeName.empty() || instanceId < 0) {
        NSLog(@"%s, bridgeName or instanceId is null", __func__);
        return;
    }
    auto instanceIdIter = bridgeList_.find(instanceId);
    if (instanceIdIter == bridgeList_.end()) {
        return;
    }
    auto bridgeIter = instanceIdIter->second.find(bridgeName);
    if (bridgeIter != instanceIdIter->second.end()) {
        instanceIdIter->second.erase(bridgeIter);
    }
    if (!instanceIdIter->second.empty()) {
        bridgeList_.erase(instanceIdIter);
    }
}

void BridgeManager::JSCallMethod(int32_t instanceId, const std::string& bridgeName,
                const std::string& methodName, const std::string& parameter) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    NSString* oc_parameter = getOCstring(parameter);
    BridgePluginManager* bridgePluginManager = getBridgePluginManagerWithInstanceId(instanceId);
    if (bridgePluginManager) {
        [bridgePluginManager jsCallMethod:oc_bridgeName methodName:oc_methodName param:oc_parameter];
    }
}

void BridgeManager::JSSendMethodResult(int32_t instanceId, const std::string& bridgeName,
                const std::string& methodName, const std::string& resultValue) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    NSString* oc_resultValue = getOCstring(resultValue);
    BridgePluginManager* bridgePluginManager = getBridgePluginManagerWithInstanceId(instanceId);
    if (bridgePluginManager) {
        [bridgePluginManager jsSendMethodResult:oc_bridgeName methodName:oc_methodName result:oc_resultValue];
    }
}

void BridgeManager::JSSendMessage(int32_t instanceId, const std::string& bridgeName, const std::string& data) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_data = getOCstring(data);
    BridgePluginManager* bridgePluginManager = getBridgePluginManagerWithInstanceId(instanceId);
    if (bridgePluginManager) {
        [bridgePluginManager jsSendMessage:oc_bridgeName data:oc_data];
    }
}

void BridgeManager::JSSendMessageResponse(int32_t instanceId, const std::string& bridgeName, const std::string& data) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_data = getOCstring(data);
    BridgePluginManager* bridgePluginManager = getBridgePluginManagerWithInstanceId(instanceId);
    if (bridgePluginManager) {
        [bridgePluginManager jsSendMessageResponse:oc_bridgeName data:oc_data];
    }
}

void BridgeManager::JSCancelMethod(int32_t instanceId, const std::string& bridgeName, const std::string& methodName) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    BridgePluginManager* bridgePluginManager = getBridgePluginManagerWithInstanceId(instanceId);
    if (bridgePluginManager) {
        [bridgePluginManager jsCancelMethod:oc_bridgeName methodName:oc_methodName];
    }
}

void BridgeManager::PlatformCallMethod(int32_t instanceId, const std::string& bridgeName,
                const std::string& methodName, const std::string& parameter) {
    if (!JSBridgeExists(instanceId, bridgeName)) {
        std::string errorData = "{\"result\":\"errorCode\",\"errorCode\":1}";
        JSSendMethodResult(instanceId, bridgeName, methodName, errorData);
        return;
    }
    auto receiver = FindReceiver(instanceId, bridgeName);
    if (receiver && receiver->callMethodCallback_) {
        receiver->callMethodCallback_(methodName, parameter);
    }
}

void BridgeManager::PlatformSendMethodResult(int32_t instanceId, const std::string& bridgeName,
                const std::string& methodName,
                const std::string& result) {
    auto receiver = FindReceiver(instanceId, bridgeName);
    if (receiver && receiver->methodResultCallback_) {
        receiver->methodResultCallback_(methodName, result);
    }
}

void BridgeManager::PlatformSendMessage(int32_t instanceId, const std::string& bridgeName, const std::string& data) {
    if (!JSBridgeExists(instanceId, bridgeName)) {
        std::string errorData = "{\"result\":\"errorCode\",\"errorCode\":1}";
        JSSendMessageResponse(instanceId, bridgeName, errorData);
        return;
    }
    auto receiver = FindReceiver(instanceId, bridgeName);
    if (receiver && receiver->sendMessageCallback_) {
        receiver->sendMessageCallback_(data);
    }
}

void BridgeManager::PlatformSendMessageResponse(int32_t instanceId, const std::string& bridgeName,
                                                const std::string& data) {
    auto receiver = FindReceiver(instanceId, bridgeName);
    if (receiver && receiver->sendMessageResponseCallback_) {
        receiver->sendMessageResponseCallback_(data);
    }
}

void BridgeManager::PlatformSendWillTerminate() {
    if (!bridgeList_.empty()) {
        auto iter = bridgeList_.begin();
        while (iter != bridgeList_.end()) {
            auto mapIter = iter->second;
            auto receiverIter = mapIter.begin();
            while (receiverIter != mapIter.end()) {
                auto receiver = receiverIter->second;
                if (receiver && receiver->sendWillTerminateResponseCallback_) {
                    receiver->sendWillTerminateResponseCallback_(true);
                }
                ++receiverIter;
            }
            ++iter;
        }
    }
}

void BridgeManager::JSSendMessageBinary(int32_t instanceId,
    const std::string& bridgeName, const std::vector<uint8_t>& data) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    BridgePluginManager* bridgePluginManager = getBridgePluginManagerWithInstanceId(instanceId);
    if (bridgePluginManager) {
        [bridgePluginManager jsSendMessageBinary:oc_bridgeName data:convertToNSData(data)];
    }

}

void BridgeManager::JSCallMethodBinary(int32_t instanceId, const std::string& bridgeName,
                                        const std::string& methodName,
                                        const std::vector<uint8_t>& data) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    NSData* oc_data = convertToNSData(data);
    BridgePluginManager* bridgePluginManager = getBridgePluginManagerWithInstanceId(instanceId);
    if (bridgePluginManager) {
        [bridgePluginManager jsCallMethodBinary:oc_bridgeName methodName:oc_methodName param:oc_data];
    }
}

void BridgeManager::JSSendMethodResultBinary(int32_t instanceId, const std::string& bridgeName,
                const std::string& methodName,
                int errorCode,
                const std::string& errorMessage, std::unique_ptr<std::vector<uint8_t>> result) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    NSString* oc_errorMessage = getOCstring(errorMessage);
    NSData* oc_data = ConvertUniqueUNint8ToNSData(std::move(result));
    BridgePluginManager* bridgePluginManager = getBridgePluginManagerWithInstanceId(instanceId);
    if (bridgePluginManager) {
        [bridgePluginManager jsSendMethodResultBinary:oc_bridgeName
                                                    methodName:oc_methodName
                                                    errorCode:errorCode
                                                    errorMessage:oc_errorMessage
                                                    result:oc_data];
    }
}

void BridgeManager::PlatformSendMethodResultBinary(int32_t instanceId, const std::string& bridgeName,
                const std::string& methodName,
                int errorCode, const std::string& errorMessage, std::unique_ptr<BufferMapping> result) {
    auto receiver = FindReceiver(instanceId, bridgeName);
    if (receiver && receiver->methodResultBinaryCallback_) {
        receiver->methodResultBinaryCallback_(methodName, errorCode, errorMessage, std::move(result));
    }
}

void BridgeManager::PlatformCallMethodBinary(int32_t instanceId, const std::string& bridgeName,
                                            const std::string& methodName,
                                            std::unique_ptr<BufferMapping> parameter) {
    auto receiver = FindReceiver(instanceId, bridgeName);
    if (receiver && receiver->callMethodBinaryCallback_) {
        receiver->callMethodBinaryCallback_(methodName, std::move(parameter));
    }
}

void BridgeManager::PlatformSendMessageBinary(int32_t instanceId,
    const std::string& bridgeName, std::unique_ptr<BufferMapping> data) {
    auto receiver = FindReceiver(instanceId, bridgeName);
    if (receiver && receiver->sendMessageBinaryCallback_) {
        receiver->sendMessageBinaryCallback_(std::move(data));
    }
}
} // namespace OHOS::Ace::Platform
