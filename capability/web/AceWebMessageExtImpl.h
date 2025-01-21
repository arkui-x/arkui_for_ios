/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#ifndef AceWebMessageExtImpl_hpp
#define AceWebMessageExtImpl_hpp

#include <string>
#include <vector>
#include "foundation/arkui/ace_engine/frameworks/base/utils/macros.h"

union data_union {
    int n;
    double f;
    bool b;

    data_union() {}
    data_union(int value) : n(value) {}
    data_union(double value) : f(value) {}
    data_union(bool value) : b(value) {}
};

enum class ACE_EXPORT AceWebMessageType : int {
    NONE = 0,
    BOOLEAN,
    INTEGER,
    DOUBLE,
    STRING,
    BINARY,
    ERROR,
    STRINGARRAY,
    BOOLEANARRAY,
    DOUBLEARRAY,
    INT64ARRAY
};

class ACE_EXPORT AceWebMessageExtImpl {
public:
    AceWebMessageExtImpl();
    ~AceWebMessageExtImpl() = default;

    void SetType(AceWebMessageType type);
    AceWebMessageType GetType();

    void SetBoolean(bool b);
    bool GetBoolean();
    
    void SetString(const std::string& str);
    std::string GetString();

    void SetDouble(double dou);
    double GetDouble();

    void SetInt(int num);
    int GetInt();

    void SetStringArray(const std::vector<std::string>& value);
    std::vector<std::string> GetStringArray();
    
    void SetBooleanArray(const std::vector<bool>& value);
    std::vector<bool> GetBooleanArray();

    void SetDoubleArray(const std::vector<double>& value);
    std::vector<double> GetDoubleArray();

    void SetInt64Array(const std::vector<int64_t>& value);
    std::vector<int64_t> GetInt64Array();

    void SetArrayBuffer(const std::vector<uint8_t>& value);
    std::vector<uint8_t> GetArrayBuffer();
    

    void SetError(const std::string& name, const std::string& message);
    std::pair<std::string, std::string> GetError();
private:
    AceWebMessageType type_ = AceWebMessageType::NONE;
    std::vector<uint8_t> binary_data_;
    std::string err_name_;
    std::string err_msg_;
    data_union data_;
    std::string str_;
    std::vector<std::string> string_arr_;
    std::vector<bool> bool_arr_;
    std::vector<double> double_arr_;
    std::vector<int64_t> int64_arr_;
};
#endif /* AceWebMessageExtImpl_hpp */