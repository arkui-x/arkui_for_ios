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

#include "BridgeCodecUtil.h"
#include <stdint.h>
#include <vector>

void BridgeCodecUtilWriteByte(CFMutableDataRef cData, uint8_t value) {
    CFDataAppendBytes(cData, &value, 1);
}

void BridgeCodecUtilWriteBytes(CFMutableDataRef cData, const void* bytes, unsigned long length) {
    CFDataAppendBytes(cData, static_cast<const uint8_t*>(bytes), length);
}

void BridgeCodecUtilWriteSize(CFMutableDataRef cData, uint32_t size) {
    if (size < 254) {
        BridgeCodecUtilWriteByte(cData, size);
    } else if (size <= 65535) {
        BridgeCodecUtilWriteByte(cData, 254);
        uint16_t value = (uint16_t)size;
        BridgeCodecUtilWriteBytes(cData, &value, 2);
    } else {
        BridgeCodecUtilWriteByte(cData, 255);
        BridgeCodecUtilWriteBytes(cData, &size, 4);
    }
}

void BridgeCodecUtilWriteAlignment(CFMutableDataRef cData, uint8_t alignment) {
    uint8_t md = CFDataGetLength(cData) % alignment;
    if (md) {
        for (int i = 0; i < (alignment - md); i++) {
            BridgeCodecUtilWriteByte(cData, 0);
        }
    }
}

void BridgeCodecUtilWriteUTF8(CFMutableDataRef cData, CFStringRef stringValue) {
    const char* utf8c = CFStringGetCStringPtr(stringValue, kCFStringEncodingUTF8);
    if (utf8c) {
        size_t length = strlen(utf8c);
        BridgeCodecUtilWriteByte(cData, length);
        BridgeCodecUtilWriteBytes(cData, utf8c, length);
    } else {
        CFIndex length = CFStringGetLength(stringValue);
        CFIndex used_length = 0;
        CFIndex buffer_length = length * 3;
        std::vector<uint8_t> buffer;
        buffer.reserve(buffer_length);
        CFStringGetBytes(stringValue, CFRangeMake(0, length), 
                kCFStringEncodingUTF8, 0, false, buffer.data(), buffer_length, &used_length);

        BridgeCodecUtilWriteByte(cData, length);
        BridgeCodecUtilWriteBytes(cData, buffer.data(), used_length);
    }
}

void BridgeCodecUtilWriteData(CFMutableDataRef cData, CFDataRef value) {
    const uint8_t* bytes = CFDataGetBytePtr(value);
    CFIndex length = CFDataGetLength(value);
    BridgeCodecUtilWriteBytes(cData, bytes, length);
}

bool BridgeCodecUtilWriteNumber(CFMutableDataRef cData, CFNumberRef number) {
    bool success = false;
    if (CFGetTypeID(number) == CFBooleanGetTypeID()) {
        bool b = CFBooleanGetValue((CFBooleanRef)number);
        BridgeCodecUtilWriteByte(cData, (b ? T_TRUE : T_FALSE));
        success = true;
    } else if (CFGetTypeID(number) == CFNumberGetTypeID() && CFNumberIsFloatType(number)) {
        double d;
        success = CFNumberGetValue(number, kCFNumberDoubleType, &d);
        if (success) {
            BridgeCodecUtilWriteByte(cData, T_DOUBLE);
            BridgeCodecUtilWriteAlignment(cData, 8);
            BridgeCodecUtilWriteBytes(cData, &d, 8);
        }
    } else if (CFNumberGetByteSize(number) <= 4) {
        int32_t n;
        success = CFNumberGetValue(number, kCFNumberSInt32Type, &n);
        if (success) {
            BridgeCodecUtilWriteByte(cData, T_INT32);
            BridgeCodecUtilWriteBytes(cData, &n, 4);
        }
    } else if (CFNumberGetByteSize(number) <= 8) {
        int64_t n;
        success = CFNumberGetValue(number, kCFNumberSInt64Type, &n);
        if (success) {
            BridgeCodecUtilWriteByte(cData, T_INT64);
            BridgeCodecUtilWriteBytes(cData, &n, 8);
        }
    }
    return success;
}

bool BridgeCodecUtilWriteNumberWithSize(CFMutableDataRef cData, CFNumberRef number, unsigned long length) {
    bool success = false;
    if (CFGetTypeID(number) == CFBooleanGetTypeID()) {
        bool b = CFBooleanGetValue((CFBooleanRef)number);
        BridgeCodecUtilWriteByte(cData, (b ? T_TRUE : T_FALSE));
        success = true;
    } else if (CFNumberIsFloatType(number) && length == 8) {
        double d;
        success = CFNumberGetValue(number, kCFNumberDoubleType, &d);
        if (success) {
            BridgeCodecUtilWriteBytes(cData, &d, 8);
        }
    } else if (length == 4) {
        int32_t n;
        success = CFNumberGetValue(number, kCFNumberSInt32Type, &n);
        if (success) {
            BridgeCodecUtilWriteBytes(cData, &n, 4);
        }
    } else if (length == 8) {
        int64_t n;
        success = CFNumberGetValue(number, kCFNumberSInt64Type, &n);
        if (success) {
            BridgeCodecUtilWriteBytes(cData, &n, 8);
        }
    }
    return success;
}

// --------------------------------------------------------
// reader Utils
static inline bool IsBridgeCodecType(uint8_t type) {
    return type <= T_MAP && type >= T_NULL;
}

static uint8_t PeekByte(unsigned long location, CFDataRef data) {
    uint8_t result;
    CFRange range = CFRangeMake(location, 1);
    CFDataGetBytes(data, range, &result);
    return result;
}

static inline CFTypeRef GetReadValue(unsigned long* location, CFDataRef data,
        CFTypeRef (*ReadValue)(CFTypeRef),
        CFTypeRef user_data) {
    uint8_t type = PeekByte(*location, data);
    if (IsBridgeCodecType(type)) {
        *location += 1;
        return BridgeCodecUtilReadValueOfType(location, data, type, ReadValue, user_data);
    } else {
        return ReadValue(user_data);
    }
}

static inline CFTypeRef ReadTypedDataOfType(unsigned long* location, CFDataRef data) {
    uint64_t elementCount = BridgeCodecUtilReadSize(location, data);
    uint64_t elementSize = 1;
    BridgeCodecUtilReadAlignment(location, elementSize);
    UInt64 length = elementCount * elementSize;

    CFDataRef result = CFDataCreateWithBytesNoCopy(
        kCFAllocatorDefault, CFDataGetBytePtr(data) + *location, length, kCFAllocatorNull);

    *location += length;
    return static_cast<CFDataRef>(CFAutorelease(result));
}

static inline CFMutableArrayRef GetReadNumberListValue(unsigned long* location, CFDataRef data, 
        CFTypeRef (*ReadValue)(CFTypeRef),
        CFTypeRef user_data, uint8_t type) {
    BridgeCodecType codecType = (BridgeCodecType)type;
    uint8_t size;
    if (codecType == T_INT32) {
        size = 4;
    } else {
        size = 8;
    }

    UInt32 length = BridgeCodecUtilReadSize(location, data);
    BridgeCodecUtilReadAlignment(location, size);
    CFMutableArrayRef array = CFArrayCreateMutable(kCFAllocatorDefault, length, &kCFTypeArrayCallBacks);
    for (int32_t i = 0; i < length; i++) {
        CFTypeRef value = BridgeCodecUtilReadValueOfType(location, data,
                type, ReadValue, user_data);
        CFArrayAppendValue(array, (value == nil ? kCFNull : value));
    }
    return array;
}

void BridgeCodecUtilReadBytes(unsigned long* location, unsigned long length, void* destination, CFDataRef cData) {
    CFRange range = CFRangeMake(*location, length);
    CFDataGetBytes(cData, range, static_cast<uint8_t*>(destination));
    *location += length;
}

uint8_t BridgeCodecUtilReadByte(unsigned long* location, CFDataRef cData) {
    uint8_t value;
    BridgeCodecUtilReadBytes(location, 1, &value, cData);
    return value;
}

uint32_t BridgeCodecUtilReadSize(unsigned long* location, CFDataRef cData) {
    uint8_t byte = BridgeCodecUtilReadByte(location, cData);
    if (byte < 254) {
        return (uint32_t)byte;
    } else if (byte == 254) {
        uint16_t value;
        BridgeCodecUtilReadBytes(location, 2, &value, cData);
        return value;
    } else {
        int32_t value;
        BridgeCodecUtilReadBytes(location, 4, &value, cData);
        return value;
    }
}

void BridgeCodecUtilReadAlignment(unsigned long* location, uint8_t alignment) {
    uint8_t md = *location % alignment;
    if (md) {
        *location += (alignment - md);
    }
}

static CFDataRef ReadDataNoCopy(unsigned long* location, unsigned long length, CFDataRef data) {
    CFDataRef result = CFDataCreateWithBytesNoCopy(
        kCFAllocatorDefault, CFDataGetBytePtr(data) + *location, length, kCFAllocatorNull);
    *location += length;
    return static_cast<CFDataRef>(CFAutorelease(result));
}

CFNumberRef ReadInt32(unsigned long* location, CFDataRef cData) {
    int32_t value;
    BridgeCodecUtilReadBytes(location, 4, &value, cData);
    return CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &value);
}

CFNumberRef ReadInt64(unsigned long* location, CFDataRef cData) {
    int64_t value;
    BridgeCodecUtilReadBytes(location, 8, &value, cData);
    return CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &value);
}

CFNumberRef ReadDouble(unsigned long* location, CFDataRef cData) {
    double value;
    BridgeCodecUtilReadAlignment(location, 8);
    BridgeCodecUtilReadBytes(location, 8, &value, cData);
    return CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &value);
}

CFStringRef BridgeCodecUtilReadUTF8(unsigned long* location, CFDataRef cData) {
    uint32_t size = BridgeCodecUtilReadSize(location, cData);
    CFDataRef bytes = ReadDataNoCopy(location, size, cData);
    CFStringRef result = CFStringCreateFromExternalRepresentation(kCFAllocatorDefault, bytes, kCFStringEncodingUTF8);
    return static_cast<CFStringRef>(CFAutorelease(result));
}

CFMutableArrayRef ReadListBool(unsigned long* location,
                               CFDataRef cData) {
    int32_t length = BridgeCodecUtilReadSize(location, cData);
    CFMutableArrayRef array = CFArrayCreateMutable(kCFAllocatorDefault, length, &kCFTypeArrayCallBacks);
    for (int32_t i = 0; i < length; i++) {
        uint8_t byte = BridgeCodecUtilReadByte(location, cData) == T_TRUE ? 1 : 0;
        CFTypeRef value = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt8Type, &byte);
        CFArrayAppendValue(array, (value == nil ? kCFNull : value));
    }
    return array;
}

CFMutableArrayRef ReadListString(unsigned long* location,
                                 CFDataRef cData) {
    int32_t length = BridgeCodecUtilReadSize(location, cData);
    CFMutableArrayRef array = CFArrayCreateMutable(kCFAllocatorDefault, length, &kCFTypeArrayCallBacks);
    for (int32_t i = 0; i < length; i++) {
        CFTypeRef value = BridgeCodecUtilReadUTF8(location, cData);
        CFArrayAppendValue(array, (value == nil ? kCFNull : value));
    }
    return array;
}

CFMutableDictionaryRef ReadMap(unsigned long* location,
                               CFDataRef cData,
                               CFTypeRef (*ReadValue)(CFTypeRef),
                               CFTypeRef user_data) {
    int32_t size = BridgeCodecUtilReadSize(location, cData);
    CFMutableDictionaryRef dict = CFDictionaryCreateMutable(
        kCFAllocatorDefault, size, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    for (int32_t i = 0; i < size; i++) {
        CFTypeRef key = GetReadValue(location, cData, ReadValue, user_data);
        CFTypeRef val = GetReadValue(location, cData, ReadValue, user_data);
        CFDictionaryAddValue(dict, (key == nil ? kCFNull : key), (val == nil ? kCFNull : val));
    }
    return dict;
}

CFMutableArrayRef ReadCompositeList(unsigned long* location,
                                    CFDataRef cData,
                                    CFTypeRef (*ReadValue)(CFTypeRef),
                                    CFTypeRef user_data) {
    int32_t length = BridgeCodecUtilReadSize(location, cData);
    CFMutableArrayRef array = CFArrayCreateMutable(kCFAllocatorDefault, length, &kCFTypeArrayCallBacks);
    for (int32_t i = 0; i < length; i++) {
        CFTypeRef value = GetReadValue(location, cData, ReadValue, user_data);
        CFArrayAppendValue(array, (value == nil ? kCFNull : value));
    }
    return array;
}

CFTypeRef BridgeCodecUtilReadValueOfType(unsigned long* location,
                                         CFDataRef cData,
                                         uint8_t type,
                                         CFTypeRef (*ReadValue)(CFTypeRef),
                                         CFTypeRef user_data) {
    BridgeCodecType codecType = (BridgeCodecType)type;
    switch (codecType) {
        case T_NULL: return nil;
        case T_TRUE: return kCFBooleanTrue;
        case T_FALSE: return kCFBooleanFalse;
        case T_INT32: return CFAutorelease(ReadInt32(location, cData));
        case T_INT64: return CFAutorelease(ReadInt64(location, cData));
        case T_DOUBLE: return CFAutorelease(ReadDouble(location, cData));
        case T_STRING: return BridgeCodecUtilReadUTF8(location, cData);
        case T_LIST_UINT8: return ReadTypedDataOfType(location, cData);
        case T_LIST_INT64: {
            CFMutableArrayRef array = GetReadNumberListValue(location, cData,
                ReadValue, user_data, T_INT64);
            return CFAutorelease(array);
        }
        case T_LIST_DOUBLE: {
            CFMutableArrayRef array = GetReadNumberListValue(location, cData,
                ReadValue, user_data, T_DOUBLE);
            return CFAutorelease(array);
        }
        case T_LIST_INT32: {
            CFMutableArrayRef array = GetReadNumberListValue(location, cData,
                ReadValue, user_data, T_INT32);
            return CFAutorelease(array);
        }
        case T_LIST_BOOL: return CFAutorelease(ReadListBool(location, cData));
        case T_LIST_STRING: return CFAutorelease(ReadListString(location, cData));
        case T_MAP: return CFAutorelease(ReadMap(location, cData, ReadValue, user_data));
        case T_COMPOSITE_LIST:
            return CFAutorelease(ReadCompositeList(location, cData,
                ReadValue, user_data));
        default:
            return nil;
    }
}