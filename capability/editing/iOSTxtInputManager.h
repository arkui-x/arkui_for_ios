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

#import <UIKit/UIKit.h>

#include "iOSTextInputDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface iOSTxtInputManager : NSObject

+ (instancetype)sharedInstance;
@property(nonatomic, weak) id<iOSTextInputDelegate> textInputDelegate;
@property (nonatomic, copy) updateEditingClientBlock textInputBlock;
@property (nonatomic, copy) updateErrorTextBlock errorTextBlock;
@property (nonatomic, copy) performActionBlock textPerformBlock;
@property (nonatomic, assign) CGFloat inputBoxY;
@property (nonatomic, assign) CGFloat inputBoxTopY;
@property (nonatomic, assign) bool isDeclarative;

- (UIView<UITextInput>*)textInputView;
- (void)showTextInput;
- (void)hideTextInput;
- (void)setTextInputClient:(int)client withConfiguration:(NSDictionary*)configuration;
- (void)setTextInputEditingState:(NSDictionary*)state;
- (void)clearTextInputClient;
- (void)finishComposing;

@end

@interface iOSTextPosition : UITextPosition

@property(nonatomic, readonly) NSUInteger index;

+ (instancetype)positionWithIndex:(NSUInteger)index;
- (instancetype)initWithIndex:(NSUInteger)index;

@end

@interface iOSTextRange : UITextRange <NSCopying>

@property(nonatomic, readonly) NSRange range;
+ (instancetype)rangeWithNSRange:(NSRange)range;

@end

NS_ASSUME_NONNULL_END
