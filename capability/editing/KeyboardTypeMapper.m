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

#import "KeyboardTypeMapper.h"

// TextInputType
NSString *const TextInputTypeText = @"TextInputType.text";
NSString *const TextInputTypeMultiline = @"TextInputType.multiline";
NSString *const TextInputTypeDatetime = @"TextInputType.datetime";
NSString *const TextInputTypeNumber = @"TextInputType.number";
NSString *const TextInputTypePhone = @"TextInputType.phone";
NSString *const TextInputTypeEmailAddress = @"TextInputType.emailAddress";
NSString *const TextInputTypeURL = @"TextInputType.url";
NSString *const TextInputTypeVisiblePassword = @"TextInputType.visiblePassword";

// TextCapitalization
NSString *const TextCapitalizationCharacters = @"TextCapitalization.characters";
NSString *const TextCapitalizationSentences = @"TextCapitalization.sentences";
NSString *const TextCapitalizationWords = @"TextCapitalization.words";

// TextInputAction
NSString *const TextInputActionUnspecified = @"TextInputAction.unspecified";
NSString *const TextInputActionDone = @"TextInputAction.done";
NSString *const TextInputActionGo = @"TextInputAction.go";
NSString *const TextInputActionSend = @"TextInputAction.send";
NSString *const TextInputActionSearch = @"TextInputAction.search";
NSString *const TextInputActionNext = @"TextInputAction.next";
NSString *const TextInputActionContinue = @"TextInputAction.continueAction";
NSString *const TextInputActionJoin = @"TextInputAction.join";
NSString *const TextInputActionRoute = @"TextInputAction.route";
NSString *const TextInputActionEmergencyCall = @"TextInputAction.emergencyCall";
NSString *const TextInputActionNewline = @"TextInputAction.newline";

@implementation KeyboardTypeMapper

+ (NSDictionary *)inputTypeMap {
    return @{
        TextInputTypeText: @(UIKeyboardTypeDefault),
        TextInputTypeMultiline: @(UIKeyboardTypeDefault),
        TextInputTypeDatetime: @(UIKeyboardTypeNumbersAndPunctuation),
        TextInputTypeNumber: @(UIKeyboardTypeDecimalPad),
        TextInputTypePhone: @(UIKeyboardTypePhonePad),
        TextInputTypeEmailAddress: @(UIKeyboardTypeEmailAddress),
        TextInputTypeURL: @(UIKeyboardTypeURL)
    };
}

+ (NSDictionary *)textCapitalizationMap {
    return @{
        TextCapitalizationCharacters: @(UITextAutocapitalizationTypeAllCharacters),
        TextCapitalizationSentences: @(UITextAutocapitalizationTypeSentences),
        TextCapitalizationWords: @(UITextAutocapitalizationTypeWords)
    };
}

+ (NSDictionary *)returnKeyTypeMap {
    return @{
        TextInputActionUnspecified: @(UIReturnKeyDefault),
        TextInputActionDone: @(UIReturnKeyDone),
        TextInputActionGo: @(UIReturnKeyGo),
        TextInputActionSend: @(UIReturnKeySend),
        TextInputActionSearch: @(UIReturnKeySearch),
        TextInputActionNext: @(UIReturnKeyNext),
        TextInputActionContinue: @(UIReturnKeyContinue),
        TextInputActionJoin: @(UIReturnKeyJoin),
        TextInputActionRoute: @(UIReturnKeyRoute),
        TextInputActionEmergencyCall: @(UIReturnKeyEmergencyCall),
        TextInputActionNewline: @(UIReturnKeyDefault)
    };
}

+ (UIKeyboardType)toUIKeyboardType:(NSString *)inputType {
    NSNumber *keyboardTypeNumber = self.inputTypeMap[inputType];
    return (keyboardTypeNumber != nil) ? (UIKeyboardType)[keyboardTypeNumber integerValue] : UIKeyboardTypeDefault;
}

+ (UITextAutocapitalizationType)toUITextAutoCapitalizationType:(NSString *)textCapitalization {
    NSNumber *autocapitalizationTypeNumber = self.textCapitalizationMap[textCapitalization];
    return (autocapitalizationTypeNumber != nil) ? (UITextAutocapitalizationType)[autocapitalizationTypeNumber integerValue] : UITextAutocapitalizationTypeNone;
}

+ (UIReturnKeyType)toUIReturnKeyType:(NSString *)inputType {
    NSNumber *returnKeyTypeNumber = self.returnKeyTypeMap[inputType];
    return (returnKeyTypeNumber != nil) ? (UIReturnKeyType)[returnKeyTypeNumber integerValue] : UIReturnKeyDefault;
}

@end

