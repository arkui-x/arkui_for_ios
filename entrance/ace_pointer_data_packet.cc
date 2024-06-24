/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

#include "ace_pointer_data_packet.h"
#include <cstring>

namespace OHOS::Ace::Platform {

AcePointerDataPacket::AcePointerDataPacket(size_t count)
    : data_(count * sizeof(AcePointerData)) {}

AcePointerDataPacket::AcePointerDataPacket(uint8_t* data, size_t bytes)
    : data_(data, data + bytes) {}

AcePointerDataPacket::~AcePointerDataPacket() = default;

void AcePointerDataPacket::SetPointerData(size_t i, const AcePointerData& data)
{
    memcpy(&data_[i * sizeof(AcePointerData)], &data, sizeof(AcePointerData));
}

}