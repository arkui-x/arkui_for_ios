// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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