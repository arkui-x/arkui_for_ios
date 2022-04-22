//
//  iOSTxtInputManager.h
//  sources
//
//  Created by vail 王军平 on 2022/1/12.
//

#import <UIKit/UIKit.h>
#include "iOSTextInputDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface iOSTxtInputManager : NSObject

+ (instancetype)shareintance;
@property(nonatomic, assign) id<iOSTextInputDelegate> textInputDelegate;
@property (nonatomic, copy) updateEditingClientBlock textInputBlock;
@property (nonatomic, copy) performActionBlock textPerformBlock;
//@property (nonatomic, copy) insertTextBlock insertTextBlock;
//@property (nonatomic, copy) deleteTextBlock deleteTextBlock;


-(UIView<UITextInput>*)textInputView;
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
