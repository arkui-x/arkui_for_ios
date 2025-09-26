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

#ifndef FOUNDATION_ADAPTER_CAPABILITY_EDITING_KEYBOARDTYPEMAPPER_H
#define FOUNDATION_ADAPTER_CAPABILITY_EDITING_KEYBOARDTYPEMAPPER_H

#import <Foundation/Foundation.h>
#include <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

// TextInputType
FOUNDATION_EXPORT NSString *const TextInputTypeText;
FOUNDATION_EXPORT NSString *const TextInputTypeMultiline;
FOUNDATION_EXPORT NSString *const TextInputTypeDatetime;
FOUNDATION_EXPORT NSString *const TextInputTypeNumber;
FOUNDATION_EXPORT NSString *const TextInputTypePhone;
FOUNDATION_EXPORT NSString *const TextInputTypeEmailAddress;
FOUNDATION_EXPORT NSString *const TextInputTypeURL;
FOUNDATION_EXPORT NSString *const TextInputTypeVisiblePassword;

// TextCapitalization
FOUNDATION_EXPORT NSString *const TextCapitalizationCharacters;
FOUNDATION_EXPORT NSString *const TextCapitalizationSentences;
FOUNDATION_EXPORT NSString *const TextCapitalizationWords;

// TextInputAction
FOUNDATION_EXPORT NSString *const TextInputActionUnspecified;
FOUNDATION_EXPORT NSString *const TextInputActionDone;
FOUNDATION_EXPORT NSString *const TextInputActionGo;
FOUNDATION_EXPORT NSString *const TextInputActionSend;
FOUNDATION_EXPORT NSString *const TextInputActionSearch;
FOUNDATION_EXPORT NSString *const TextInputActionNext;
FOUNDATION_EXPORT NSString *const TextInputActionContinue;
FOUNDATION_EXPORT NSString *const TextInputActionJoin;
FOUNDATION_EXPORT NSString *const TextInputActionRoute;
FOUNDATION_EXPORT NSString *const TextInputActionEmergencyCall;
FOUNDATION_EXPORT NSString *const TextInputActionNewline;


@interface KeyboardTypeMapper : NSObject
+ (UIKeyboardType)toUIKeyboardType:(NSString *)inputType;
+ (UITextAutocapitalizationType)toUITextAutoCapitalizationType:(NSString *)textCapitalization;
+ (UIReturnKeyType)toUIReturnKeyType:(NSString *)inputType;
@end

NS_ASSUME_NONNULL_END

#endif // FOUNDATION_ADAPTER_CAPABILITY_EDITING_KEYBOARDTYPEMAPPER_H