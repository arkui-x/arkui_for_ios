// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <UIKit/UIKit.h>

#include "iOSTextInputDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface iOSTxtInputManager : NSObject

+ (instancetype)shareintance;
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
