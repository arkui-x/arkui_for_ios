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

#ifndef FOUNDATION_ACE_ADAPTER_CAPABILITY_BRIDGE_BRIDGE_MANAGER_H
#define FOUNDATION_ACE_ADAPTER_CAPABILITY_BRIDGE_BRIDGE_MANAGER_H

#include <map>
#include <mutex>
#include <string>

#include "base/utils/macros.h"
#include "bridge_receiver.h"

namespace OHOS::Ace::Platform {
class ACE_EXPORT BridgeManager final {
public:
    BridgeManager() = default;
    ~BridgeManager() = default;

    static bool JSBridgeExists(const std::string& bridgeName);
    static bool JSRegisterBridge(const std::string& bridgeName,
        std::shared_ptr<BridgeReceiver> callback);
    static void JSUnRegisterBridge(const std::string& bridgeName);
    static void JSCallMethod(const std::string& bridgeName, const std::string& methodName,
        const std::string& parameter);
    static void JSSendMethodResult(const std::string& bridgeName, const std::string& methodName,
        const std::string& resultValue);
    static void JSSendMessage(const std::string& bridgeName, const std::string& data);
    static void JSSendMessageResponse(const std::string& bridgeName, const std::string& data);
    static void PlatformCallMethod(const std::string& bridgeName, const std::string& methodName,
        const std::string& parameter);
    static void PlatformSendMethodResult(const std::string& bridgeName,
        const std::string& methodName, const std::string& result);
    static void PlatformSendMessage(const std::string& bridgeName, const std::string& data);
    static void PlatformSendMessageResponse(const std::string& bridgeName, const std::string& data);
    static void JSCancelMethod(const std::string& bridgeName, const std::string& methodName);
    
private:
    static std::map<std::string, std::shared_ptr<BridgeReceiver>> bridgeList_;
    static std::mutex bridgeLock_;
    static std::shared_ptr<BridgeReceiver> FindReceiver(const std::string& bridgeName);
};
} // namespace OHOS::Ace::Platform
#endif // FOUNDATION_ACE_ADAPTER_CAPABILITY_BRIDGE_BRIDGE_MANAGER_H
