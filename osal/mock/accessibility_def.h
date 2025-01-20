/*
 * Copyright (C) 2025 Huawei Device Co., Ltd.
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

#ifndef ACCESSIBILITY_DEFINE_H
#define ACCESSIBILITY_DEFINE_H

#include <cstdint>
#include <map>
#include <string>
#include <vector>

#include "accessibility_constants.h"

namespace OHOS {
namespace AccessibilityConfig {

enum DALTONIZATION_TYPE : uint32_t {
    Normal = 0,
    Protanomaly,
    Deuteranomaly,
    Tritanomaly,
};

enum CLICK_RESPONSE_TIME : uint32_t {
    ResponseDelayShort = 0,
    ResponseDelayMedium,
    ResponseDelayLong,
};

enum IGNORE_REPEAT_CLICK_TIME : uint32_t {
    RepeatClickTimeoutShortest = 0,
    RepeatClickTimeoutShort,
    RepeatClickTimeoutMedium,
    RepeatClickTimeoutLong,
    RepeatClickTimeoutLongest,
};
} // namespace AccessibilityConfig
} // namespace OHOS

namespace OHOS {
namespace Accessibility {
enum RetError : int32_t {
    RET_OK = 0,
    RET_ERR_FAILED = -1,
    RET_ERR_INVALID_PARAM = 1001,
    RET_ERR_NULLPTR,
    RET_ERR_IPC_FAILED,
    RET_ERR_SAMGR,
    RET_ERR_NO_PERMISSION,
    RET_ERR_NOT_SYSTEM_APP,
    RET_ERR_TIME_OUT,
    RET_ERR_TREE_TOO_BIG,
    RET_ERR_TOKEN_ID,

    RET_ERR_REGISTER_EXIST = 4001,
    RET_ERR_NO_REGISTER,
    RET_ERR_CONNECTION_EXIST,
    RET_ERR_NO_CONNECTION,
    RET_ERR_NO_WINDOW_CONNECTION,
    RET_ERR_NO_CAPABILITY,
    RET_ERR_INVALID_ELEMENT_INFO_FROM_ACE,
    RET_ERR_PERFORM_ACTION_FAILED_BY_ACE,
    RET_ERR_NO_INJECTOR,
    RET_ERR_NOT_INSTALLED,
    RET_ERR_NOT_ENABLED,
    RET_ERR_PROPERTY_NOT_EXIST,
    RET_ERR_ACTION_NOT_SUPPORT,
};

enum ActionType : int32_t {
    ACCESSIBILITY_ACTION_INVALID = 0,
    ACCESSIBILITY_ACTION_FOCUS = 0x00000001,
    ACCESSIBILITY_ACTION_CLEAR_FOCUS = 0x00000002,
    ACCESSIBILITY_ACTION_SELECT = 0x00000004,
    ACCESSIBILITY_ACTION_CLEAR_SELECTION = 0x00000008,
    ACCESSIBILITY_ACTION_CLICK = 0x00000010,
    ACCESSIBILITY_ACTION_LONG_CLICK = 0x00000020,
    ACCESSIBILITY_ACTION_ACCESSIBILITY_FOCUS = 0x00000040,
    ACCESSIBILITY_ACTION_CLEAR_ACCESSIBILITY_FOCUS = 0x00000080,
    ACCESSIBILITY_ACTION_SCROLL_FORWARD = 0x00000100,
    ACCESSIBILITY_ACTION_SCROLL_BACKWARD = 0x00000200,
    ACCESSIBILITY_ACTION_COPY = 0x00000400,
    ACCESSIBILITY_ACTION_PASTE = 0x00000800,
    ACCESSIBILITY_ACTION_CUT = 0x00001000,
    ACCESSIBILITY_ACTION_SET_SELECTION = 0x00002000,
    ACCESSIBILITY_ACTION_SET_TEXT = 0x00004000,
    ACCESSIBILITY_ACTION_SET_CURSOR_POSITION = 0x00100000,
    ACCESSIBILITY_ACTION_NEXT_TEXT = 0x00200000,
    ACCESSIBILITY_ACTION_PREVIOUS_TEXT = 0x00400000,
    ACCESSIBILITY_ACTION_UNFOLD = 0x00800000,
    ACCESSIBILITY_ACTION_FOLD = 0x01000000,
    ACCESSIBILITY_ACTION_NEXT_HTML_ITEM = 0x02000000,
    ACCESSIBILITY_ACTION_PREVIOUS_HTML_ITEM = 0x04000000,
    ACCESSIBILITY_ACTION_DELETED = 0x08000000,
    ACCESSIBILITY_ACTION_COMMON = 0x10000000,
    ACCESSIBILITY_ACTION_HOME = 0x00010000,
    ACCESSIBILITY_ACTION_BACK = 0x00020000,
    ACCESSIBILITY_ACTION_RECENTTASK = 0x00040000,
    ACCESSIBILITY_ACTION_NOTIFICATIONCENTER = 0x00080000,
    ACCESSIBILITY_ACTION_CONTROLCENTER = 0x00008000,
    ACCESSIBILITY_ACTION_TYPE_MASK = 0x1FFFFFFF,
};

enum TextMoveUnit : int32_t {
    STEP_INVALID = 0,
    STEP_CHARACTER = 0x00000001,
    STEP_WORD = 0x00000002,
    STEP_LINE = 0x00000004,
    STEP_PAGE = 0x00000008,
    STEP_PARAGRAPH = 0x00000010,
};
} // namespace Accessibility
} // namespace OHOS

const std::string ERROR_MESSAGE_PARAMETER_ERROR =
    "Parameter error. Possible causes:"
    "1. Mandatory parameters are left unspecified; 2. Incorrect parameter types; 3. Parameter verification failed.";
const std::string ERROR_MESSAGE_NO_PERMISSION =
    "Permission verification failed."
    "The application does not have the permission required to call the API.";
const std::string ERROR_MESSAGE_NOT_SYSTEM_APP = "Permission verification failed."
                                                 "A non-system application calls a system API.";
const std::string ERROR_MESSAGE_NO_RIGHT = "No accessibility permission to perform the operation";
const std::string ERROR_MESSAGE_SYSTEM_ABNORMALITY = "System abnormality";
const std::string ERROR_MESSAGE_PROPERTY_NOT_EXIST = "This property does not exist";
const std::string ERROR_MESSAGE_ACTION_NOT_SUPPORT = "This action is not supported";
const std::string ERROR_MESSAGE_INVALID_BUNDLE_NAME_OR_ABILITY_NAME = "Invalid bundle name or ability name";
const std::string ERROR_MESSAGE_TARGET_ABILITY_ALREADY_ENABLED = "Target ability already enabled";

enum class NAccessibilityErrorCode : int32_t {
    ACCESSIBILITY_OK = 0,
    ACCESSIBILITY_ERROR_NO_PERMISSION = 201,
    ACCESSIBILITY_ERROR_NOT_SYSTEM_APP = 202,
    ACCESSIBILITY_ERROR_INVALID_PARAM = 401,
    ACCESSIBILITY_ERROR_SYSTEM_ABNORMALITY = 9300000,
    ACCESSIBILITY_ERROR_ERROR_EXTENSION_NAME = 9300001,
    ACCESSIBILITY_ERROR_TARGET_ABILITY_ALREADY_ENABLED = 9300002,
    ACCESSIBILITY_ERROR_NO_RIGHT = 9300003,
    ACCESSIBILITY_ERROR_PROPERTY_NOT_EXIST = 9300004,
    ACCESSIBILITY_ERROR_ACTION_NOT_SUPPORT = 9300005,
};

struct NAccessibilityErrMsg {
    NAccessibilityErrorCode errCode;
    std::string message;
};

const std::map<OHOS::Accessibility::RetError, NAccessibilityErrMsg> ACCESSIBILITY_JS_TO_ERROR_CODE_MAP {
    { OHOS::Accessibility::RetError::RET_OK, { NAccessibilityErrorCode::ACCESSIBILITY_OK, "" } },
    { OHOS::Accessibility::RetError::RET_ERR_FAILED,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_SYSTEM_ABNORMALITY, ERROR_MESSAGE_SYSTEM_ABNORMALITY } },
    { OHOS::Accessibility::RetError::RET_ERR_INVALID_PARAM,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_INVALID_PARAM, ERROR_MESSAGE_PARAMETER_ERROR } },
    { OHOS::Accessibility::RetError::RET_ERR_NULLPTR,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_SYSTEM_ABNORMALITY, ERROR_MESSAGE_SYSTEM_ABNORMALITY } },
    { OHOS::Accessibility::RetError::RET_ERR_IPC_FAILED,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_SYSTEM_ABNORMALITY, ERROR_MESSAGE_SYSTEM_ABNORMALITY } },
    { OHOS::Accessibility::RetError::RET_ERR_SAMGR,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_SYSTEM_ABNORMALITY, ERROR_MESSAGE_SYSTEM_ABNORMALITY } },
    { OHOS::Accessibility::RetError::RET_ERR_NO_PERMISSION,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_NO_PERMISSION, ERROR_MESSAGE_NO_PERMISSION } },
    { OHOS::Accessibility::RetError::RET_ERR_TIME_OUT,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_SYSTEM_ABNORMALITY, ERROR_MESSAGE_SYSTEM_ABNORMALITY } },
    { OHOS::Accessibility::RetError::RET_ERR_REGISTER_EXIST,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_SYSTEM_ABNORMALITY, ERROR_MESSAGE_SYSTEM_ABNORMALITY } },
    { OHOS::Accessibility::RetError::RET_ERR_NO_REGISTER,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_SYSTEM_ABNORMALITY, ERROR_MESSAGE_SYSTEM_ABNORMALITY } },
    { OHOS::Accessibility::RetError::RET_ERR_CONNECTION_EXIST,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_TARGET_ABILITY_ALREADY_ENABLED,
            ERROR_MESSAGE_TARGET_ABILITY_ALREADY_ENABLED } },
    { OHOS::Accessibility::RetError::RET_ERR_NO_CONNECTION,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_SYSTEM_ABNORMALITY, ERROR_MESSAGE_SYSTEM_ABNORMALITY } },
    { OHOS::Accessibility::RetError::RET_ERR_NO_WINDOW_CONNECTION,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_SYSTEM_ABNORMALITY, ERROR_MESSAGE_SYSTEM_ABNORMALITY } },
    { OHOS::Accessibility::RetError::RET_ERR_NO_CAPABILITY,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_NO_RIGHT, ERROR_MESSAGE_NO_RIGHT } },
    { OHOS::Accessibility::RetError::RET_ERR_INVALID_ELEMENT_INFO_FROM_ACE,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_SYSTEM_ABNORMALITY, ERROR_MESSAGE_SYSTEM_ABNORMALITY } },
    { OHOS::Accessibility::RetError::RET_ERR_PERFORM_ACTION_FAILED_BY_ACE,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_SYSTEM_ABNORMALITY, ERROR_MESSAGE_SYSTEM_ABNORMALITY } },
    { OHOS::Accessibility::RetError::RET_ERR_NO_INJECTOR,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_SYSTEM_ABNORMALITY, ERROR_MESSAGE_SYSTEM_ABNORMALITY } },
    { OHOS::Accessibility::RetError::RET_ERR_NOT_INSTALLED,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_ERROR_EXTENSION_NAME,
            ERROR_MESSAGE_INVALID_BUNDLE_NAME_OR_ABILITY_NAME } },
    { OHOS::Accessibility::RetError::RET_ERR_NOT_ENABLED,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_ERROR_EXTENSION_NAME,
            ERROR_MESSAGE_INVALID_BUNDLE_NAME_OR_ABILITY_NAME } },
    { OHOS::Accessibility::RetError::RET_ERR_PROPERTY_NOT_EXIST,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_PROPERTY_NOT_EXIST, ERROR_MESSAGE_PROPERTY_NOT_EXIST } },
    { OHOS::Accessibility::RetError::RET_ERR_ACTION_NOT_SUPPORT,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_ACTION_NOT_SUPPORT, ERROR_MESSAGE_ACTION_NOT_SUPPORT } },
    { OHOS::Accessibility::RetError::RET_ERR_NOT_SYSTEM_APP,
        { NAccessibilityErrorCode::ACCESSIBILITY_ERROR_NOT_SYSTEM_APP, ERROR_MESSAGE_NOT_SYSTEM_APP } },
};
#endif // ACCESSIBILITY_DEFINE_H
