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
#import "BridgeSerializer.h"
#import "BridgeArray.h"
#import "BridgeCodecUtil.h"

uint8_t GetSizeForBridgeType(BridgeArrayType type) {
    switch (type) {
        case BridgeArrayTypeBooL:
            return 1;
        case BridgeArrayTypeInt32:
            return 4;
        case BridgeArrayTypeInt64:
            return 8;
        case BridgeArrayTypeDouble:
            return 8;
        default:
            return 1;
    }
}

BridgeCodecType BridgeCodecTypeForBridgeType(BridgeArrayType type) {
    switch (type) {
        case BridgeArrayTypeBooL:
            return T_LIST_BOOL;
        case BridgeArrayTypeInt32:
            return T_LIST_INT32;
        case BridgeArrayTypeInt64:
            return T_LIST_INT64;
        case BridgeArrayTypeDouble:
            return T_LIST_DOUBLE;
        case BridgeArrayTypeString:
            return T_LIST_STRING;
        default:
            return T_LIST_STRING;
    }
}

BridgeCodecObjectType BridgeCodecObjectTypeForBridge(BridgeArray* data) {
    if (data.arrayType != 0) {
        if (data.arrayType == BridgeArrayTypeBooL) {
            return BridgeCodecObjectTypeBoolList;
        } else if (data.arrayType == BridgeArrayTypeString) {
            return BridgeCodecObjectTypeStringList;
        } else {
            return BridgeCodecObjectTypeNumberListData;
        }
    }
    return BridgeCodecObjectTypeUnknown;
}

@implementation BridgeSerializer
- (BridgeStreamWriter*)writerWithData:(NSMutableData*)data {
    return [[BridgeStreamWriter alloc] initWithData:data];
}

- (BridgeStreamReader*)readerWithData:(NSData*)data {
    return [[BridgeStreamReader alloc] initWithData:data];
}
@end

/// BridgeStreamWriter
@interface BridgeStreamWriter()
{
    NSMutableData *_data;
}
@end

@implementation BridgeStreamWriter

- (instancetype)initWithData:(NSMutableData*)data {
    self = [super self];
    if (self) {
        _data = data;
    }
    return self;
}

- (bool)writeValue:(id)value {
    BridgeCodecObjectType type = GetWriteType(value);
    return WriteValueOfType((__bridge CFTypeRef)self,
                (__bridge CFMutableDataRef)_data, type, (__bridge CFTypeRef)value);
}

#pragma marked private

static BridgeCodecObjectType GetWriteType(id value) {
    if (value == nil || (__bridge CFNullRef)value == kCFNull || [value isKindOfClass:[NSNull class]]) {
        return BridgeCodecObjectTypeNil;
    } else if ([value isKindOfClass:[NSNumber class]]) {
        return BridgeCodecObjectTypeNSNumber;
    } else if ([value isKindOfClass:[NSString class]]) {
        return BridgeCodecObjectTypeNSString;
    } else if ([value isKindOfClass:[BridgeArray class]]) {
        return BridgeCodecObjectTypeForBridge(value);
    } else if ([value isKindOfClass:[NSData class]]) {
        return BridgeCodecObjectTypeNSData;
    } else if ([value isKindOfClass:[NSArray class]]) {
        return BridgeCodecObjectTypeNSArray;
    } else if ([value isKindOfClass:[NSDictionary class]]) {
        return BridgeCodecObjectTypeNSDictionary;
    }
    return BridgeCodecObjectTypeUnknown;
}

static bool WriteValueOfType(CFTypeRef writer,
                            CFMutableDataRef data,
                            BridgeCodecObjectType type,
                            CFTypeRef value) {
    switch (type) {
        case BridgeCodecObjectTypeNil:
            BridgeCodecUtilWriteByte(data, T_NULL);
            return true;
        case BridgeCodecObjectTypeNSNumber: {
            CFNumberRef number = (CFNumberRef)value;
            return BridgeCodecUtilWriteNumber(data, number);
        }
        case BridgeCodecObjectTypeNSString: {
            CFStringRef string = (CFStringRef)value;
            BridgeCodecUtilWriteByte(data, T_STRING);
            BridgeCodecUtilWriteUTF8(data, string);
            return true;
        }
        case BridgeCodecObjectTypeNumberListData:
            return WriteValueOfNumber(data, value);
        case BridgeCodecObjectTypeNSData: {
            WriteValueOfNSData(data, value);
            return true;
        } 
        case BridgeCodecObjectTypeBoolList:
            return WriteValueOfBoolList(data, value);
        case BridgeCodecObjectTypeStringList:
            WriteValueOfStringList(data, value);
            return true;
        case BridgeCodecObjectTypeNSArray:
            WriteValueOfNSArray(writer, data, value);
            return true;
        case BridgeCodecObjectTypeNSDictionary:
            WriteValueOfNSDictionary(writer, data, value);
            return true;
        case BridgeCodecObjectTypeUnknown:{
            id objc_value = (__bridge id)value;
            NSLog(@"BridgeStreamWriter::Unsupported value: %@ of type %@", objc_value, [objc_value class]);
            return false;
        }
        default:
            return false;
        break;
    }
}

static bool WriteValueOfNumber(CFMutableDataRef data, CFTypeRef value) {
    BridgeArray* bridgeData = (__bridge BridgeArray*)value;
    BridgeCodecUtilWriteByte(data, BridgeCodecTypeForBridgeType(bridgeData.arrayType));
    CFArrayRef array = (__bridge CFArrayRef)bridgeData.array;
    CFIndex size = CFArrayGetCount(array);
    uint8_t byteSize = GetSizeForBridgeType(bridgeData.arrayType);

    BridgeCodecUtilWriteSize(data, (uint32_t)size);
    BridgeCodecUtilWriteAlignment(data, byteSize);
    bool success = true;
    for (CFIndex i = 0; i < size; ++i) {
        CFNumberRef number = (CFNumberRef)CFArrayGetValueAtIndex(array, i);
        success = BridgeCodecUtilWriteNumberWithSize(data, number, byteSize);
        if (!success) {
            NSLog(@"BridgeStreamWriter::codec Unsupported value: %@ of number type %ld",
                value, CFNumberGetType(number));
            break;
        }
    }
    return success;
}

static void WriteValueOfNSData(CFMutableDataRef data, CFTypeRef value) {
        NSData* ocData = (__bridge NSData*)value;
        BridgeCodecUtilWriteByte(data, T_LIST_UINT8);
        BridgeCodecUtilWriteSize(data, (uint32_t)ocData.length);
        BridgeCodecUtilWriteAlignment(data, 1);
        BridgeCodecUtilWriteData(data, (__bridge CFDataRef)ocData);
}

static bool WriteValueOfBoolList(CFMutableDataRef data, CFTypeRef value) {
    BridgeCodecUtilWriteByte(data, T_LIST_BOOL);
    BridgeArray* bridgeData = (__bridge BridgeArray*)value;
    CFArrayRef array = (__bridge CFArrayRef)bridgeData.array;
    CFIndex size = CFArrayGetCount(array);
    BridgeCodecUtilWriteSize(data, (uint32_t)size);
    bool success = true;
    for (CFIndex i = 0; i < size; ++i) {
        CFNumberRef number = (CFNumberRef)CFArrayGetValueAtIndex(array, i);
        success = BridgeCodecUtilWriteNumber(data, number);
        if (!success) {
            NSLog(@"BridgeStreamWriter::codec Unsupported value: %@ of number type %ld",
                    value, CFNumberGetType(number));
            break;
        }
    }
    return success;
}

static void WriteValueOfStringList(CFMutableDataRef data, CFTypeRef value) {
    BridgeCodecUtilWriteByte(data, T_LIST_STRING);
    BridgeArray* bridgeData = (__bridge BridgeArray*)value;
    CFArrayRef array = (__bridge CFArrayRef)bridgeData.array;
    CFIndex size = CFArrayGetCount(array);
    BridgeCodecUtilWriteSize(data, (uint32_t)size);
    for (CFIndex i = 0; i < size; ++i) {
        CFStringRef string = (CFStringRef)CFArrayGetValueAtIndex(array, i);
        BridgeCodecUtilWriteUTF8(data, string);
    }
}

static void WriteValueOfNSArray(CFTypeRef writer, CFMutableDataRef data, CFTypeRef value) {
    BridgeCodecUtilWriteByte(data, T_COMPOSITE_LIST);
    CFArrayRef array = (CFArrayRef)value;
    CFIndex size = CFArrayGetCount(array);
    BridgeCodecUtilWriteSize(data, (uint32_t)size);
    for (CFIndex i = 0; i < size; ++i) {
        RecursivelyWriteValueOfType(writer, data, CFArrayGetValueAtIndex(array, i));
    }
}

static void WriteValueOfNSDictionary(CFTypeRef writer, CFMutableDataRef data, CFTypeRef value) {
    CFDictionaryRef dict = (CFDictionaryRef)value;
    BridgeCodecUtilWriteByte(data, T_MAP);
    CFIndex size = CFDictionaryGetCount(dict);
    BridgeCodecUtilWriteSize(data, (UInt32)size);
    DicWriteKeyValuesInfo info = {
        .writer = writer,
        .data = data,
    };
    CFDictionaryApplyFunction(dict, DicWriteKeyValues, (void*)&info);
}

static void RecursivelyWriteValueOfType(CFTypeRef writer, CFMutableDataRef data, CFTypeRef value) {
    BridgeCodecObjectType type = GetWriteType((__bridge id)value);
    if (type != BridgeCodecObjectTypeUnknown) {
        WriteValueOfType(writer, data, type, value);
    } else {
        NSLog(@"BridgeStreamWriter::List Unsupported value: %u", type);
    }
}

struct DicWriteKeyValuesInfo {
    CFTypeRef writer;
    CFMutableDataRef data;
};

static void DicWriteKeyValues(CFTypeRef key, CFTypeRef value, void* context) {
    DicWriteKeyValuesInfo* info = (DicWriteKeyValuesInfo*)context;
    RecursivelyWriteValueOfType(info->writer, info->data, key);
    RecursivelyWriteValueOfType(info->writer, info->data, value);
}

@end

/// BridgeStreamReader
@interface BridgeStreamReader () {
    NSData* _data;
    NSRange _dataRange;
}
@end
@implementation BridgeStreamReader

- (instancetype)initWithData:(NSData*)data {
    self = [super self];
    if (self) {
        _data = data;
        _dataRange = NSMakeRange(0, 0);
    }
    return self;
}

- (BOOL)isNoMoreData {
    return _dataRange.location < _data.length;
}

- (uint8_t)readUnitByte {
    return BridgeCodecUtilReadByte(&_dataRange.location, (__bridge CFDataRef)_data);
}

- (void)readBytes:(void*)destination length:(NSUInteger)length {
    BridgeCodecUtilReadBytes(&_dataRange.location, length, destination, (__bridge CFDataRef)_data);
}

- (NSString*)readUTF8 {
    return (__bridge NSString*)BridgeCodecUtilReadUTF8(&_dataRange.location, (__bridge CFDataRef)_data);
}

- (nullable id)readValue {
    return (__bridge id)InnerReadValue((__bridge CFTypeRef)self);
}

- (nullable id)readValueWithType:(uint8_t)type {
    return (__bridge id)BridgeCodecUtilReadValueOfType(
        &_dataRange.location, (__bridge CFDataRef)_data, 
        type, InnerReadValue, (__bridge CFTypeRef)self);
}

static CFTypeRef InnerReadValue(CFTypeRef user_data) {
    BridgeStreamReader* reader = (__bridge BridgeStreamReader*)user_data;
    uint8_t type = BridgeCodecUtilReadByte(&reader->_dataRange.location,
                                           (__bridge CFDataRef)reader->_data);
    return (__bridge CFTypeRef)[reader readValueWithType:type];
}
@end