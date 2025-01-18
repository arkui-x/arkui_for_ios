/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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
#include "AceWebMessageExtImpl.h"

AceWebMessageExtImpl::AceWebMessageExtImpl()
{
    this->type_ = AceWebMessageType::NONE;
    this->data_.n = 0;
    this->data_.b = false;
    this->data_.f = 0.0f;
    this->str_ = "";
    this->string_arr_ = {};
    this->double_arr_ = {};
    this->int64_arr_ = {};
    this->bool_arr_ = {};
    this->err_name_ = "";
    this->err_msg_ = "";

}

void AceWebMessageExtImpl::SetType(AceWebMessageType type)
{
    this->type_ = type;
}

AceWebMessageType AceWebMessageExtImpl::GetType()
{
    return this->type_;
}

void AceWebMessageExtImpl::SetBoolean(bool b)
{
    SetType(AceWebMessageType::BOOLEAN);
    this->data_.b = b;
}

bool AceWebMessageExtImpl::GetBoolean()
{
    return this->data_.b;
}

void AceWebMessageExtImpl::SetString(std::string str)
{
    SetType(AceWebMessageType::STRING);
    this->str_ = str;
}

std::string AceWebMessageExtImpl::GetString()
{
    return this->str_;
}

void AceWebMessageExtImpl::SetDouble(double dou)
{
    SetType(AceWebMessageType::DOUBLE);
    this->data_.f = dou;
}

double AceWebMessageExtImpl::GetDouble()
{
    return this->data_.f;
}

void AceWebMessageExtImpl::SetInt(int num)
{
    SetType(AceWebMessageType::INTEGER);
    this->data_.n = num;
}

int AceWebMessageExtImpl::GetInt()
{
    return this->data_.n;
}

void AceWebMessageExtImpl::SetStringArray(std::vector<std::string> value)
{
    SetType(AceWebMessageType::STRINGARRAY);
    this->string_arr_ = value;
}

std::vector<std::string> AceWebMessageExtImpl::GetStringArray()
{
    return this->string_arr_;
}

void AceWebMessageExtImpl::SetDoubleArray(std::vector<double> value)
{
    SetType(AceWebMessageType::DOUBLEARRAY);
    this->double_arr_ = value;
}

std::vector<double> AceWebMessageExtImpl::GetDoubleArray()
{
    return this->double_arr_;
}

void AceWebMessageExtImpl::SetInt64Array(std::vector<int64_t> value)
{
    SetType(AceWebMessageType::INT64ARRAY);
    this->int64_arr_ = value;
}

std::vector<int64_t> AceWebMessageExtImpl::GetInt64Array()
{
    return this->int64_arr_;
}

void AceWebMessageExtImpl::SetBooleanArray(std::vector<bool> value)
{
    SetType(AceWebMessageType::BOOLEANARRAY);
    this->bool_arr_ = value;
}

std::vector<bool> AceWebMessageExtImpl::GetBooleanArray()
{
    return this->bool_arr_;
}

void AceWebMessageExtImpl::SetArrayBuffer(std::vector<uint8_t>& value)
{
    SetType(AceWebMessageType::BINARY);
    this->binary_data_.reserve(value.size());
    this->binary_data_ = value;
}

std::vector<uint8_t> AceWebMessageExtImpl::GetArrayBuffer()
{
    return this->binary_data_;
}

void AceWebMessageExtImpl::SetError(std::string name, std::string message)
{
    SetType(AceWebMessageType::ERROR);
    this->err_name_ = name;
    this->err_msg_ = message;
}

std::pair<std::string, std::string> AceWebMessageExtImpl::GetError()
{
    return std::make_pair(this->err_name_, this->err_msg_);
}
