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

#include "adapter/ios/capability/bridge/bridge_manager.h"

#import <Foundation/Foundation.h>
#include <memory>

#import "BridgeBinaryCodec.h"
#import "BridgeManagerHolder.h"
#import "BridgePlugin+internal.h"
#import "BridgePlugin.h"
#import "BridgePluginManager+internal.h"
#import "BridgePluginManager.h"
#import "ResultValue.h"

#include "base/log/log.h"
#include "base/utils/utils.h"

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

std::unique_ptr<BufferMapping> ConvertNSDataToBufferMapping(NSData* nsData) {
    if (nsData == nil) {
        return std::make_unique<BufferMapping>(BufferMapping::Copy(nullptr, 0));
    }
    uint8_t* dataBytes = (uint8_t*)[nsData bytes];
    size_t dataSize = [nsData length];
    return std::make_unique<BufferMapping>(BufferMapping::Copy(dataBytes, dataSize));
}

BridgePluginManager* getBridgePluginManager() {
    BridgePluginManager* bridgePluginManager = [BridgeManagerHolder getBridgePluginManager];
    return bridgePluginManager;
}

std::shared_ptr<BridgeReceiver> BridgeManager::FindReceiver(const std::string& bridgeName) {
    if (bridgeName.empty()) {
        return nullptr;
    }
    std::lock_guard<std::mutex> lock(bridgeLock_);
    auto bridgeIter = bridgeList_.find(bridgeName);
    if (bridgeIter != bridgeList_.end()) {
        return bridgeIter->second;
    }
    return nullptr;
}

bool BridgeManager::JSBridgeExists(const std::string& bridgeName) {
    return FindReceiver(bridgeName) != nullptr;
}

bool BridgeManager::JSRegisterBridge(std::shared_ptr<BridgeReceiver> callback)
{
    if (callback == nullptr || callback->bridgeName_.empty()) {
        LOGE("JSRegisterBridge V2 failed, callback is null or bridgeName is empty");
        return false;
    }
    std::lock_guard<std::mutex> lock(bridgeLock_);
    auto bridgeIter = bridgeList_.find(callback->bridgeName_);
    if (bridgeIter == bridgeList_.end()) {
        bridgeList_[callback->bridgeName_] = callback;
        jsOnRegisterResult(callback->bridgeName_, true, callback->bridgeType_);
        return true;
    } else {
        bridgeList_[callback->bridgeName_] = callback;
        jsOnRegisterResult(callback->bridgeName_, true, callback->bridgeType_);
        return true;
    }
}

void BridgeManager::JSUnRegisterBridge(const std::string& bridgeName)
{
    std::lock_guard<std::mutex> lock(bridgeLock_);
    auto bridgeIter = bridgeList_.find(bridgeName);
    if (bridgeIter != bridgeList_.end()) {
        bridgeList_.erase(bridgeIter);
    }
    int32_t bridgeType = GetBridgeType(bridgeName);
    jsOnRegisterResult(bridgeName, false, bridgeType);
}

void BridgeManager::jsOnRegisterResult(const std::string& bridgeName, bool available, int32_t bridgeType)
{
    BridgePluginManager* bridgePluginManager = [BridgePluginManager sharedInstance];
    if (bridgePluginManager) {
        NSString* oc_bridgeName = getOCstring(bridgeName);
        BridgePlugin* bridgePlugin = [bridgePluginManager getPluginWithBridgeName:oc_bridgeName];
        if (bridgePlugin == nil) {
            return;
        }
        if (!available) {
            [bridgePlugin onRegisterResult:available];
            return;
        }
        if (bridgePlugin.type == bridgeType) {
            [bridgePlugin onRegisterResult:available];
        }
    }
}

void BridgeManager::JSCallMethod(const std::string& bridgeName,
                const std::string& methodName, const std::string& parameter) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    NSString* oc_parameter = getOCstring(parameter);
    BridgePluginManager* bridgePluginManager = getBridgePluginManager();
    if (bridgePluginManager) {
        [bridgePluginManager jsCallMethod:oc_bridgeName methodName:oc_methodName param:oc_parameter];
    }
}

std::string BridgeManager::JSCallMethodSync(
    const std::string& bridgeName, const std::string& methodName, const std::string& parameter) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    NSString* oc_parameter = getOCstring(parameter);
    BridgePluginManager* bridgePluginManager = getBridgePluginManager();
    if (bridgePluginManager) {
        NSString* result = [bridgePluginManager jsCallMethodSync:oc_bridgeName
                                                      methodName:oc_methodName
                                                           param:oc_parameter];
        return std::string([result UTF8String]);
    }
    return "";
}

void BridgeManager::JSSendMethodResult(const std::string& bridgeName,
                const std::string& methodName, const std::string& resultValue) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    NSString* oc_resultValue = getOCstring(resultValue);
    BridgePluginManager* bridgePluginManager = getBridgePluginManager();
    if (bridgePluginManager) {
        [bridgePluginManager jsSendMethodResult:oc_bridgeName methodName:oc_methodName result:oc_resultValue];
    }
}

void BridgeManager::JSSendMessage(const std::string& bridgeName, const std::string& data) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_data = getOCstring(data);
    BridgePluginManager* bridgePluginManager = getBridgePluginManager();
    if (bridgePluginManager) {
        [bridgePluginManager jsSendMessage:oc_bridgeName data:oc_data];
    }
}

void BridgeManager::JSSendMessageResponse(const std::string& bridgeName, const std::string& data) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_data = getOCstring(data);
    BridgePluginManager* bridgePluginManager = getBridgePluginManager();
    if (bridgePluginManager) {
        [bridgePluginManager jsSendMessageResponse:oc_bridgeName data:oc_data];
    }
}

void BridgeManager::JSCancelMethod(const std::string& bridgeName, const std::string& methodName) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    BridgePluginManager* bridgePluginManager = getBridgePluginManager();
    if (bridgePluginManager) {
        [bridgePluginManager jsCancelMethod:oc_bridgeName methodName:oc_methodName];
    }
}

void BridgeManager::PlatformCallMethod(const std::string& bridgeName,
                const std::string& methodName, const std::string& parameter) {
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

std::string BridgeManager::PlatformCallMethodResult(const std::string& bridgeName,
                const std::string& methodName, const std::string& parameter)
{
    if (!JSBridgeExists(bridgeName)) {
        std::string errorData = "{\"result\":\"errorCode\",\"errorCode\":1}";
        return errorData;
    }
    auto receiver = FindReceiver(bridgeName);
    if (receiver && receiver->callMethodSyncCallback_) {
        std::string result = receiver->callMethodSyncCallback_(methodName, parameter);
        return result;
    }
    return "";
}

void BridgeManager::PlatformSendMethodResult(const std::string& bridgeName,
                const std::string& methodName,
                const std::string& result) {
    auto receiver = FindReceiver(bridgeName);
    if (receiver && receiver->methodResultCallback_) {
        receiver->methodResultCallback_(methodName, result);
    }
}

void BridgeManager::PlatformSendMessage(const std::string& bridgeName, const std::string& data) {
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
    auto receiver = FindReceiver(bridgeName);
    if (receiver && receiver->sendMessageResponseCallback_) {
        receiver->sendMessageResponseCallback_(data);
    }
}

void BridgeManager::PlatformSendWillTerminate()
{
    std::lock_guard<std::mutex> lock(bridgeLock_);
    for (const auto& pair : bridgeList_) {
        const auto& receiver = pair.second;
        if (receiver && receiver->sendWillTerminateResponseCallback_) {
            receiver->sendWillTerminateResponseCallback_(true);
        }
    }
}

void BridgeManager::JSSendMessageBinary(
    const std::string& bridgeName, const std::vector<uint8_t>& data) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    BridgePluginManager* bridgePluginManager = getBridgePluginManager();
    if (bridgePluginManager) {
        [bridgePluginManager jsSendMessageBinary:oc_bridgeName data:convertToNSData(data)];
    }

}

void BridgeManager::JSCallMethodBinary(const std::string& bridgeName,
                                        const std::string& methodName,
                                        const std::vector<uint8_t>& data)
{
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    NSData* oc_data = convertToNSData(data);
    BridgePluginManager* bridgePluginManager = getBridgePluginManager();
    if (bridgePluginManager) {
        [bridgePluginManager jsCallMethodBinary:oc_bridgeName methodName:oc_methodName param:oc_data];
    }
}

BinaryResultHolder BridgeManager::JSCallMethodBinarySync(
    const std::string& bridgeName, const std::string& methodName, const std::vector<uint8_t>& data) {
    BinaryResultHolder resultHolder;
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    NSData* oc_data = convertToNSData(data);
    BridgePluginManager* bridgePluginManager = getBridgePluginManager();
    ResultValue* resultValue = [bridgePluginManager jsCallMethodBinarySync:oc_bridgeName
                                                                methodName:oc_methodName
                                                                     param:oc_data];
    if (resultValue == nil) {
        resultHolder.errorCode = BRIDGE_DATA_ERROR;
        return resultHolder;
    }
    resultHolder.errorCode = resultValue.errorCode;
    if ([resultValue.result isKindOfClass:[NSData class]]) {
        NSData* data = (NSData*)resultValue.result;
        resultHolder.buffer = ConvertNSDataToBufferMapping(data);
    }
    return resultHolder;
}

void BridgeManager::JSSendMethodResultBinary(const std::string& bridgeName,
                const std::string& methodName,
                int errorCode,
                const std::string& errorMessage, std::unique_ptr<std::vector<uint8_t>> result) {
    NSString* oc_bridgeName = getOCstring(bridgeName);
    NSString* oc_methodName = getOCstring(methodName);
    NSString* oc_errorMessage = getOCstring(errorMessage);
    NSData* oc_data = ConvertUniqueUNint8ToNSData(std::move(result));
    BridgePluginManager* bridgePluginManager = getBridgePluginManager();
    if (bridgePluginManager) {
        [bridgePluginManager jsSendMethodResultBinary:oc_bridgeName
                                                    methodName:oc_methodName
                                                    errorCode:errorCode
                                                    errorMessage:oc_errorMessage
                                                    result:oc_data];
    }
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

std::unique_ptr<BufferMapping> BridgeManager::PlatformCallMethodBinarySync(const std::string& bridgeName,
    const std::string& methodName, std::unique_ptr<BufferMapping> parameter, int32_t& errorCode)
{
    auto receiver = FindReceiver(bridgeName);
    if (receiver && receiver->callMethodSyncBinaryCallback_) {
        return receiver->callMethodSyncBinaryCallback_(methodName, std::move(parameter), errorCode);
    }
    LOGE("PlatformCallMethodBinarySync: receiver or callback null, bridgeName=%{public}s, method=%{public}s",
        bridgeName.c_str(), methodName.c_str());
    return nullptr;
}

void BridgeManager::PlatformSendMessageBinary(
    const std::string& bridgeName, std::unique_ptr<BufferMapping> data) {
    auto receiver = FindReceiver(bridgeName);
    if (receiver && receiver->sendMessageBinaryCallback_) {
        receiver->sendMessageBinaryCallback_(std::move(data));
    }
}

int32_t BridgeManager::GetBridgeType(const std::string& bridgeName)
{
    auto receiver = FindReceiver(bridgeName);
    if (!receiver) {
        return -1;
    }
    return receiver->bridgeType_;
}
} // namespace OHOS::Ace::Platform
