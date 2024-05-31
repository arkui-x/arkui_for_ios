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

#ifndef FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_CODEC_BridgeCodecUtil_H
#define FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_CODEC_BridgeCodecUtil_H

#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>
#include <stdint.h>

#if defined(__cplusplus)
extern "C" {
#endif

typedef enum {
    T_NULL = 0,
    T_TRUE,
    T_FALSE,
    T_INT32,
    T_INT64,
    T_DOUBLE,
    T_STRING,
    T_LIST_UINT8,
    T_LIST_BOOL,
    T_LIST_INT32,
    T_LIST_INT64,
    T_LIST_DOUBLE,
    T_LIST_STRING,
    T_MAP,
    T_COMPOSITE_LIST,
} BridgeCodecType;

typedef enum {
    BridgeCodecObjectTypeNil = 0,
    BridgeCodecObjectTypeNSNumber,
    BridgeCodecObjectTypeNSString,
    BridgeCodecObjectTypeNumberListData,
    BridgeCodecObjectTypeNSData,
    BridgeCodecObjectTypeBoolList,
    BridgeCodecObjectTypeStringList,
    BridgeCodecObjectTypeNSArray,
    BridgeCodecObjectTypeNSDictionary,
    BridgeCodecObjectTypeUnknown,
} BridgeCodecObjectType;

void BridgeCodecUtilWriteByte(CFMutableDataRef cData, uint8_t value);

void BridgeCodecUtilWriteBytes(CFMutableDataRef cData, const void* bytes, unsigned long length);

void BridgeCodecUtilWriteSize(CFMutableDataRef cData, uint32_t size);

void BridgeCodecUtilWriteAlignment(CFMutableDataRef cData, uint8_t alignment);

void BridgeCodecUtilWriteUTF8(CFMutableDataRef cData, CFStringRef stringValue);

void BridgeCodecUtilWriteData(CFMutableDataRef cData, CFDataRef value);

bool BridgeCodecUtilWriteNumber(CFMutableDataRef cData, CFNumberRef number);

bool BridgeCodecUtilWriteNumberWithSize(CFMutableDataRef cData, CFNumberRef number, unsigned long length);

void BridgeCodecUtilReadBytes(unsigned long* location, unsigned long length, void* destination, CFDataRef cData);

uint8_t BridgeCodecUtilReadByte(unsigned long* location, CFDataRef cData);

uint32_t BridgeCodecUtilReadSize(unsigned long* location, CFDataRef cData);

void BridgeCodecUtilReadAlignment(unsigned long* location, uint8_t alignment);

CFStringRef BridgeCodecUtilReadUTF8(unsigned long* location, CFDataRef cData);

CFTypeRef BridgeCodecUtilReadValueOfType(unsigned long* location, CFDataRef cData, uint8_t type,
    CFTypeRef (*ReadValue)(CFTypeRef), CFTypeRef user_data);

#if defined(__cplusplus)
}
#endif

#endif // FOUNDATION_ADAPTER_CAPABILITY_BRIDGE_CODEC_BridgeCodecUtil_H