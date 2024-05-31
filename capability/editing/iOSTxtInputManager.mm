// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "iOSTxtInputManager.h"
#import "KeyboardTypeMapper.h"

#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>

#include "flutter/fml/platform/darwin/string_range_sanitization.h"

static const char _kTextAffinityDownstream[] = "TextAffinity.downstream";
static const char _kTextAffinityUpstream[] = "TextAffinity.upstream";

#pragma mark - iOSTextPosition
@implementation iOSTextPosition

+ (instancetype)positionWithIndex:(NSUInteger)index {
    return [[[iOSTextPosition alloc] initWithIndex:index] autorelease];
}

- (instancetype)initWithIndex:(NSUInteger)index {
    self = [super init];
    if (self) {
        _index = index;
    }
    return self;
}

@end

#pragma mark - iOSTextRange

@implementation iOSTextRange

+ (instancetype)rangeWithNSRange:(NSRange)range {
    return [[[iOSTextRange alloc] initWithNSRange:range] autorelease];
}

- (instancetype)initWithNSRange:(NSRange)range {
    self = [super init];
    if (self) {
        _range = range;
    }
    return self;
}

- (UITextPosition*)start {
    return [iOSTextPosition positionWithIndex:self.range.location];
}

- (UITextPosition*)end {
    return [iOSTextPosition positionWithIndex:self.range.location + self.range.length];
}

- (BOOL)isEmpty {
    return self.range.length == 0;
}

- (id)copyWithZone:(NSZone*)zone {
    return [[iOSTextRange allocWithZone:zone] initWithNSRange:self.range];
}

@end

@interface iOSTextInputView : UIView <UITextInput>

// UITextInput
@property(nonatomic, readonly) NSMutableString* text;
@property(nonatomic, readonly) NSMutableString* markedText;
@property(readwrite, copy) UITextRange* selectedTextRange;
@property(nonatomic, strong) UITextRange* markedTextRange;
@property(nonatomic, copy) NSDictionary* markedTextStyle;
@property(nonatomic, assign) id<UITextInputDelegate> inputDelegate;
@property(nonatomic, copy) NSString* inputFilter;
@property(nonatomic) NSUInteger maxLength;
@property(nonatomic) NSUInteger markedTextLocation;
@property(nonatomic) NSUInteger markedTextLength;

// UITextInputTraits
@property(nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property(nonatomic) UITextAutocorrectionType autocorrectionType;
@property(nonatomic) UITextSpellCheckingType spellCheckingType;
@property(nonatomic) BOOL enablesReturnKeyAutomatically;
@property(nonatomic) UIKeyboardAppearance keyboardAppearance;
@property(nonatomic) UIKeyboardType keyboardType;
@property(nonatomic) UIReturnKeyType returnKeyType;
@property(nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;

@property (nonatomic, copy) updateEditingClientBlock textInputBlock;
@property (nonatomic, copy) updateErrorTextBlock errorTextBlock;
@property (nonatomic, copy) performActionBlock textPerformBlock;

@end

@implementation iOSTextInputView {
    int _textInputClient;
    const char* _selectionAffinity;
    iOSTextRange* _selectedTextRange;
}

@synthesize tokenizer = _tokenizer;

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _textInputClient = 0;
        _selectionAffinity = _kTextAffinityUpstream;
        
        // UITextInput
        _text = [[NSMutableString alloc] init];
        _markedText = [[NSMutableString alloc] init];
        _selectedTextRange = [[iOSTextRange alloc] initWithNSRange:NSMakeRange(0, 0)];
        _markedTextLocation = 0;
        _markedTextLength = 0;
        
        // UITextInputTraits
        _autocapitalizationType = UITextAutocapitalizationTypeSentences;
        _autocorrectionType = UITextAutocorrectionTypeDefault;
        _spellCheckingType = UITextSpellCheckingTypeDefault;
        _enablesReturnKeyAutomatically = NO;
        _keyboardAppearance = UIKeyboardAppearanceDefault;
        _keyboardType = UIKeyboardTypeDefault;
        _returnKeyType = UIReturnKeyDone;
        _secureTextEntry = NO;
        _inputFilter = @"";
    }
    
    return self;
}

- (void)dealloc {
    [_text release];
    [_markedText release];
    [_markedTextRange release];
    [_selectedTextRange release];
    [_tokenizer release];
    [super dealloc];
}

- (void)setTextInputClient:(int)client {
    _textInputClient = client;
}

- (void)setTextInputState:(NSDictionary*)state {
    
    if(self.markedTextRange!=nil){
        return;
    }
    
    NSString *newText = state[@"text"];
    BOOL textChanged = ![self.text isEqualToString:newText];
    if (textChanged) {
        [self.text setString:newText];
    }
    
    NSInteger selectionBase = [state[@"selectionBase"] intValue];
    NSInteger selectionExtent = [state[@"selectionExtent"] intValue];
    NSRange selectedRange = [self clampSelection:NSMakeRange(MIN(selectionBase, selectionExtent), ABS(selectionBase - selectionExtent)) forText:self.text];
    NSRange oldSelectedRange = [(iOSTextRange*)self.selectedTextRange range];
    if (selectedRange.location != oldSelectedRange.location || selectedRange.length != oldSelectedRange.length) {
        [self setSelectedTextRange:[iOSTextRange rangeWithNSRange:selectedRange] updateEditingState:NO];
        _selectionAffinity = _kTextAffinityDownstream;
        if ([state[@"selectionAffinity"] isEqualToString:@(_kTextAffinityUpstream)]){
           _selectionAffinity = _kTextAffinityUpstream;
        }
    }
}

- (NSRange)clampSelection:(NSRange)range forText:(NSString*)text {
    int start = MIN(MAX(range.location, 0), text.length);
    int length = MIN(range.length, text.length - start);
    return NSMakeRange(start, length);
}

#pragma mark - UIResponder Overrides

- (BOOL)canBecomeFirstResponder {
    return YES;
}

#pragma mark - UITextInput Overrides

- (id<UITextInputTokenizer>)tokenizer {
    if (_tokenizer == nil) {
        _tokenizer = [[UITextInputStringTokenizer alloc] initWithTextInput:self];
    }
    return _tokenizer;
}

- (UITextRange*)selectedTextRange {
    return [[_selectedTextRange copy] autorelease];
}

- (void)setSelectedTextRange:(UITextRange*)selectedTextRange {
    [self setSelectedTextRange:selectedTextRange updateEditingState:YES];
}

- (void)setSelectedTextRange:(UITextRange*)selectedTextRange updateEditingState:(BOOL)update {
    if (_selectedTextRange != selectedTextRange) {
        UITextRange* oldSelectedRange = _selectedTextRange;
        if (self.hasText) {
            iOSTextRange* iosTextRange = (iOSTextRange*)selectedTextRange;
            _selectedTextRange = [[iOSTextRange
                                   rangeWithNSRange:fml::RangeForCharactersInRange(self.text, iosTextRange.range)] copy];
        } else {
            _selectedTextRange = [selectedTextRange copy];
        }
        [oldSelectedRange release];
        
        if (update)
            [self updateEditingState];
    }
}

- (id)insertDictationResultPlaceholder {
    return @"";
}

- (void)removeDictationResultPlaceholder:(id)placeholder willInsertResult:(BOOL)willInsertResult {
}

- (NSString*)textInRange:(UITextRange*)range {
    NSRange textRange = ((iOSTextRange*)range).range;
    if (textRange.location < 0) {
        textRange.location = 0;
    }
    if (textRange.length + textRange.location > self.text.length) {
        textRange.length = self.text.length - textRange.location;
    }
    return [self.text substringWithRange:textRange];
}

- (void)replaceRange:(UITextRange*)range withText:(NSString*)text {
    NSRange replaceRange = ((iOSTextRange*)range).range;
    NSRange selectedRange = _selectedTextRange.range;
    // Adjust the text selection:
    // * reduce the length by the intersection length
    // * adjust the location by newLength - oldLength + intersectionLength
    NSRange intersectionRange = NSIntersectionRange(replaceRange, selectedRange);
    if (replaceRange.location <= selectedRange.location)
        selectedRange.location += text.length - replaceRange.length;
    if (intersectionRange.location != NSNotFound) {
        selectedRange.location += intersectionRange.length;
        selectedRange.length -= intersectionRange.length;
    }
    
    [self.text replaceCharactersInRange:[self clampSelection:replaceRange forText:self.text] withString:text];
    
    [self setSelectedTextRange:[iOSTextRange rangeWithNSRange:[self clampSelection:selectedRange forText:self.text]] updateEditingState:NO];
    
    [self updateEditingState];
    
}

- (BOOL)shouldChangeTextInRange:(UITextRange*)range replacementText:(NSString*)text {
    if (self.returnKeyType != UIReturnKeyDefault && text.length > 0 && ![text isEqualToString:@"\n"]) {
        NSRange markedTextRange = ((iOSTextRange*)self.markedTextRange).range;
        NSRange selectedRange = _selectedTextRange.range;
        if (markedTextRange.length == 0 && selectedRange.length == 0) {
            if (self.text.length >= self.maxLength) {
                return NO;
            }
        }
    }
    if ((self.returnKeyType != UIReturnKeyDefault && ![text isEqualToString:@"\n"]) || self.returnKeyType == UIReturnKeyDefault) {
        if ([self.inputFilter length] > 0) {
            NSString *filteredText = @"";
            NSString *errorText = @"";
            NSRegularExpression *regex =
                [NSRegularExpression regularExpressionWithPattern:self.inputFilter options:NSRegularExpressionUseUnixLineSeparators error:nil];

            NSString *temp = nil;
            for(int i = 0; i < [text length]; i++) {
                temp = [text substringWithRange:NSMakeRange(i, 1)];
                auto hits = [regex matchesInString:temp options:0 range:NSMakeRange(0, [temp length])];                
                if ([hits count] > 0) {
                    filteredText = [filteredText stringByAppendingString: temp];
                } else {
                    errorText = [errorText stringByAppendingString: temp];
                }
            }
            if (![filteredText isEqualToString:text]) {
                [self updateInputFilterErrorText:errorText];
                return NO;
            }
        }
    }

    if (self.returnKeyType == UIReturnKeyDefault && [text isEqualToString:@"\n"]) {
        if(self.textPerformBlock){
            self.textPerformBlock(iOSTextInputActionNewline,_textInputClient);
        }
        return YES;
    }
    
    if ([text isEqualToString:@"\n"]) {
        iOSTextInputAction action;
        switch (self.returnKeyType) {
            case UIReturnKeyDefault:
                action = iOSTextInputActionUnspecified;
                break;
            case UIReturnKeyDone:
                action = iOSTextInputActionDone;
                break;
            case UIReturnKeyGo:
                action = iOSTextInputActionGo;
                break;
            case UIReturnKeySend:
                action = iOSTextInputActionSend;
                break;
            case UIReturnKeySearch:
            case UIReturnKeyGoogle:
            case UIReturnKeyYahoo:
                action = iOSTextInputActionSearch;
                break;
            case UIReturnKeyNext:
                action = iOSTextInputActionNext;
                break;
            case UIReturnKeyContinue:
                action = iOSTextInputActionContinue;
                break;
            case UIReturnKeyJoin:
                action = iOSTextInputActionJoin;
                break;
            case UIReturnKeyRoute:
                action = iOSTextInputActionRoute;
                break;
            case UIReturnKeyEmergencyCall:
                action = iOSTextInputActionEmergencyCall;
                break;
        }
        
        if(self.textPerformBlock){
            self.textPerformBlock(action,_textInputClient);
        }
        return NO;
    }
    
    return YES;
}

- (void)setMarkedText:(NSString*)markedText selectedRange:(NSRange)markedSelectedRange {
    NSRange selectedRange = _selectedTextRange.range;
    NSRange markedTextRange = ((iOSTextRange*)self.markedTextRange).range;
    
    if (markedText == nil)
        markedText = @"";
    
    if (markedTextRange.length > 0) {
        // Replace text in the marked range with the new text.
        [self replaceRange:self.markedTextRange withText:markedText];
        markedTextRange.length = markedText.length;
    } else {
        // Replace text in the selected range with the new text.
        [self replaceRange:_selectedTextRange withText:markedText];
        markedTextRange = NSMakeRange(selectedRange.location, markedText.length);
    }
    
    self.markedTextRange =
    markedTextRange.length > 0 ? [iOSTextRange rangeWithNSRange:markedTextRange] : nil;
    
    NSUInteger selectionLocation = markedSelectedRange.location + markedTextRange.location;
    selectedRange = NSMakeRange(selectionLocation, markedSelectedRange.length);
    [self setSelectedTextRange:[iOSTextRange rangeWithNSRange:[self clampSelection:selectedRange
                                                                           forText:self.text]]
            updateEditingState:YES];
}

- (void)unmarkText {
    self.markedTextRange = nil;
    [self updateEditingState];
}

- (UITextRange*)textRangeFromPosition:(UITextPosition*)fromPosition
                           toPosition:(UITextPosition*)toPosition {
    NSUInteger fromIndex = ((iOSTextPosition*)fromPosition).index;
    NSUInteger toIndex = ((iOSTextPosition*)toPosition).index;
    return [iOSTextRange rangeWithNSRange:NSMakeRange(fromIndex, toIndex - fromIndex)];
}

- (NSUInteger)decrementOffsetPosition:(NSUInteger)position {
    return fml::RangeForCharacterAtIndex(self.text, MAX(0, position - 1)).location;
}

- (NSUInteger)incrementOffsetPosition:(NSUInteger)position {
    NSRange charRange = fml::RangeForCharacterAtIndex(self.text, position);
    return MIN(position + charRange.length, self.text.length);
}

- (UITextPosition*)positionFromPosition:(UITextPosition*)position offset:(NSInteger)offset {
    NSUInteger offsetPosition = ((iOSTextPosition*)position).index;
    
    NSInteger newLocation = (NSInteger)offsetPosition + offset;
    if (newLocation < 0 || newLocation > (NSInteger)self.text.length) {
        return nil;
    }
    
    if (offset >= 0) {
        for (NSInteger i = 0; i < offset && offsetPosition < self.text.length; ++i)
            offsetPosition = [self incrementOffsetPosition:offsetPosition];
    } else {
        for (NSInteger i = 0; i < ABS(offset) && offsetPosition > 0; ++i)
            offsetPosition = [self decrementOffsetPosition:offsetPosition];
    }
    return [iOSTextPosition positionWithIndex:offsetPosition];
}

- (UITextPosition*)positionFromPosition:(UITextPosition*)position
                            inDirection:(UITextLayoutDirection)direction
                                 offset:(NSInteger)offset {
    switch (direction) {
        case UITextLayoutDirectionLeft:
        case UITextLayoutDirectionUp:
            return [self positionFromPosition:position offset:offset * -1];
        case UITextLayoutDirectionRight:
        case UITextLayoutDirectionDown:
            return [self positionFromPosition:position offset:1];
    }
}

- (UITextPosition*)beginningOfDocument {
    return [iOSTextPosition positionWithIndex:0];
}

- (UITextPosition*)endOfDocument {
    return [iOSTextPosition positionWithIndex:self.text.length];
}

- (NSComparisonResult)comparePosition:(UITextPosition*)position toPosition:(UITextPosition*)other {
    NSUInteger positionIndex = ((iOSTextPosition*)position).index;
    NSUInteger otherIndex = ((iOSTextPosition*)other).index;
    if (positionIndex < otherIndex)
        return NSOrderedAscending;
    if (positionIndex > otherIndex)
        return NSOrderedDescending;
    return NSOrderedSame;
}

- (NSInteger)offsetFromPosition:(UITextPosition*)from toPosition:(UITextPosition*)toPosition {
    return ((iOSTextPosition*)toPosition).index - ((iOSTextPosition*)from).index;
}

- (UITextPosition*)positionWithinRange:(UITextRange*)range
                   farthestInDirection:(UITextLayoutDirection)direction {
    NSUInteger index;
    switch (direction) {
        case UITextLayoutDirectionLeft:
        case UITextLayoutDirectionUp:
            index = ((iOSTextPosition*)range.start).index;
            break;
        case UITextLayoutDirectionRight:
        case UITextLayoutDirectionDown:
            index = ((iOSTextPosition*)range.end).index;
            break;
    }
    return [iOSTextPosition positionWithIndex:index];
}

- (UITextRange*)characterRangeByExtendingPosition:(UITextPosition*)position
                                      inDirection:(UITextLayoutDirection)direction {
    NSUInteger positionIndex = ((iOSTextPosition*)position).index;
    NSUInteger startIndex;
    NSUInteger endIndex;
    switch (direction) {
        case UITextLayoutDirectionLeft:
        case UITextLayoutDirectionUp:
            startIndex = [self decrementOffsetPosition:positionIndex];
            endIndex = positionIndex;
            break;
        case UITextLayoutDirectionRight:
        case UITextLayoutDirectionDown:
            startIndex = positionIndex;
            endIndex = [self incrementOffsetPosition:positionIndex];
            break;
    }
    return [iOSTextRange rangeWithNSRange:NSMakeRange(startIndex, endIndex - startIndex)];
}

#pragma mark - UITextInput text direction handling

- (UITextWritingDirection)baseWritingDirectionForPosition:(UITextPosition*)position
                                              inDirection:(UITextStorageDirection)direction {
    return UITextWritingDirectionNatural;
}

- (void)setBaseWritingDirection:(UITextWritingDirection)writingDirection
                       forRange:(UITextRange*)range {}

#pragma mark - UITextInput cursor, selection rect handling

// The following methods are required to support force-touch cursor positioning
// and to position the
// candidates view for multi-stage input methods (e.g., Japanese) when using a
// physical keyboard.

- (CGRect)firstRectForRange:(UITextRange*)range {
    return CGRectZero;
}

- (CGRect)caretRectForPosition:(UITextPosition*)position {
    return CGRectZero;
}

- (UITextPosition*)closestPositionToPoint:(CGPoint)point {
    NSUInteger currentIndex = ((iOSTextPosition*)_selectedTextRange.start).index;
    return [iOSTextPosition positionWithIndex:currentIndex];
}

- (NSArray*)selectionRectsForRange:(UITextRange*)range {
    return @[];
}

- (UITextPosition*)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange*)range {
    return range.start;
}

- (UITextRange*)characterRangeAtPoint:(CGPoint)point {
    NSUInteger currentIndex = ((iOSTextPosition*)_selectedTextRange.start).index;
    return [iOSTextRange rangeWithNSRange:fml::RangeForCharacterAtIndex(self.text, currentIndex)];
}

- (void)beginFloatingCursorAtPoint:(CGPoint)point {}

- (void)updateFloatingCursorAtPoint:(CGPoint)point {}

- (void)endFloatingCursor {}

#pragma mark - UIKeyInput Overrides

- (void)updateEditingState {
    NSUInteger selectionBase = ((iOSTextPosition*)_selectedTextRange.start).index;
    NSUInteger selectionExtent = ((iOSTextPosition*)_selectedTextRange.end).index;
    
    // Empty compositing range is represented by the framework's TextRange.empty.
    NSInteger composingBase = -1;
    NSInteger composingExtent = -1;
    if (self.markedTextRange != nil) {
        composingBase = ((iOSTextPosition*)self.markedTextRange.start).index;
        composingExtent = ((iOSTextPosition*)self.markedTextRange.end).index;
    }

    NSRange markedTextRange = ((iOSTextRange*)self.markedTextRange).range;          
    if (markedTextRange.length == 0) {
        if (self.text.length > self.maxLength) {
            if (self.markedTextLength > 0) {
                NSString *prefixText = @"";
                NSString *insertText = @"";
                NSString *suffixText = @"";
                if (self.text.length >= self.markedTextLocation) {
                    prefixText = [self.text substringWithRange:NSMakeRange(0, self.markedTextLocation)];
                }
                if (self.text.length >= self.markedTextLocation + self.markedTextLocation) {
                    insertText = [self.text substringWithRange:NSMakeRange(self.markedTextLocation, self.markedTextLength)];
                    suffixText = [self.text substringWithRange:NSMakeRange(self.markedTextLocation + self.markedTextLength, self.text.length - (self.markedTextLocation + self.markedTextLength))];
                }
                NSUInteger insertLength = self.maxLength - (self.text.length - self.markedTextLength);
                if (insertLength < insertText.length) {
                    insertText = [insertText substringWithRange:NSMakeRange(0, insertLength)];
                }

                NSString *newText = [prefixText stringByAppendingString: insertText];
                selectionBase = newText.length;
                selectionExtent = newText.length;
                newText = [newText stringByAppendingString: suffixText];
                [self.text setString:newText];                
            } else {
                NSString *newText = [self.text substringWithRange:NSMakeRange(0, self.maxLength)];
                [self.text setString:newText];
                selectionBase = self.maxLength;
                selectionExtent = self.maxLength;
            }
        }
        self.markedTextLocation = 0;
        self.markedTextLength = 0;
    } else {
        self.markedTextLocation = markedTextRange.location;
        self.markedTextLength = markedTextRange.length;
    }
    
    NSDictionary *dict = @{
        @"selectionBase" : @(selectionBase),
        @"selectionExtent" : @(selectionExtent),
        @"selectionAffinity" : @(_selectionAffinity),
        @"selectionIsDirectional" : @(false),
        @"composingBase" : @(composingBase),
        @"composingExtent" : @(composingExtent),
        @"text" : [NSString stringWithString:self.text],
    };
    
    if(self.textInputBlock){
        self.textInputBlock(_textInputClient,dict);
    }
    
}

- (void)updateInputFilterErrorText: (NSString*)errorText {
    NSDictionary *dict = @{
        @"errorText" : errorText,
    };
    if(self.errorTextBlock){
        self.errorTextBlock(_textInputClient, dict);
    }
}

- (BOOL)hasText {
    return self.text.length > 0;
}

- (void)insertText:(NSString*)text {
    if ([self.inputFilter length] > 0) {
        NSString *filteredText = @"";
        NSString *errorText = @"";
        NSRegularExpression *regex =
            [NSRegularExpression regularExpressionWithPattern:self.inputFilter options:NSRegularExpressionUseUnixLineSeparators error:nil];

        NSString *temp = nil;
        for(int i = 0; i < [text length]; i++) {
            temp = [text substringWithRange:NSMakeRange(i, 1)];
            auto hits = [regex matchesInString:temp options:0 range:NSMakeRange(0, [temp length])];                
            if ([hits count] > 0) {
                filteredText = [filteredText stringByAppendingString: temp];
            } else {
                errorText = [errorText stringByAppendingString: temp];
            }
        }
        if (![filteredText isEqualToString:text]) {
            [self updateInputFilterErrorText:errorText];
        }
        text = filteredText;
    }

    if (self.text.length + text.length > self.maxLength && self.maxLength - self.text.length > 0) {
        text = [text substringWithRange:NSMakeRange(0, self.maxLength - self.text.length)];
    }

    _selectionAffinity = _kTextAffinityDownstream;
    [self replaceRange:_selectedTextRange withText:text];
}

- (void)deleteBackward {
    _selectionAffinity = _kTextAffinityDownstream;
    if (_selectedTextRange.isEmpty && [self hasText]) {
        NSRange oldRange = ((iOSTextRange*)_selectedTextRange).range;
        if (oldRange.location > 0) {
            NSRange newRange = NSMakeRange(oldRange.location - 1, 1);
            [self setSelectedTextRange:[iOSTextRange rangeWithNSRange:newRange]
                    updateEditingState:false];
        }
    }
    
    if (!_selectedTextRange.isEmpty)
        [self replaceRange:_selectedTextRange withText:@""];
}

@end


@interface TextInputHideView : UIView {
}

@end

@implementation TextInputHideView {
}

- (BOOL)accessibilityElementsHidden {
    return YES;
}

@end

@implementation iOSTxtInputManager{
    iOSTextInputView* _view;
    iOSTextInputView* _secureView;
    iOSTextInputView* _activeView;
    TextInputHideView* _inputHider;
}

@synthesize textInputBlock = _textInputBlock;
@synthesize errorTextBlock = _errorTextBlock;
@synthesize textPerformBlock = _textPerformBlock;

+ (instancetype)shareintance{
    static dispatch_once_t onceToken;
    static iOSTxtInputManager *instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [iOSTxtInputManager new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        _view = [[iOSTextInputView alloc] init];
        _view.secureTextEntry = NO;
        _secureView = [[iOSTextInputView alloc] init];
        _secureView.secureTextEntry = YES;
        _activeView = _view;
        _inputHider = [[TextInputHideView alloc] init];
    }
    return self;
}

- (void)dealloc {
    [self hideTextInput];
    [_view release];
    [_secureView release];
    [_inputHider release];
    
    [super dealloc];
}

- (UIView<UITextInput>*)textInputView {
    return _activeView;
}

- (void)showTextInput {
    NSAssert([UIApplication sharedApplication].keyWindow != nullptr,
             @"The application must have a key window since the keyboard client "
             @"must be part of the responder chain to function");
    if ([_activeView isFirstResponder]) {
       return;
    }
    _activeView.textInputBlock = _textInputBlock;
    _activeView.errorTextBlock = _errorTextBlock;
    _activeView.textPerformBlock = _textPerformBlock;
    [self addToInputParentViewIfNeeded:_activeView];
    [_activeView becomeFirstResponder];
}

- (UIView*)keyWindow {
    UIApplication *sharedApplication = [UIApplication sharedApplication];
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *windowScene in sharedApplication.connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive && [windowScene isKindOfClass:UIWindowScene.class]) {
                keyWindow = windowScene.windows.firstObject;
                break;
            }
        }
    } else {
        keyWindow = sharedApplication.keyWindow;
    }
  NSAssert(keyWindow != nullptr,
           @"The application must have a key window since the keyboard client "
           @"must be part of the responder chain to function");
  return keyWindow;
}

- (void)addToInputParentViewIfNeeded:(iOSTextInputView*)inputView {
    if ([inputView isDescendantOfView:_inputHider]) {
        [inputView removeFromSuperview];
    }
    [_inputHider addSubview:inputView];
    
    UIView* parentView = self.keyWindow;
    if ([_inputHider isDescendantOfView:parentView]) {
         [_inputHider removeFromSuperview];
      }
    [parentView addSubview:_inputHider];
}

- (void)hideTextInput {
    [_activeView resignFirstResponder];
    [_activeView removeFromSuperview];
    [_inputHider removeFromSuperview];
}

- (void)setTextInputClient:(int)client withConfiguration:(NSDictionary*)configuration {
    NSDictionary* inputType = configuration[@"inputType"];
    NSString* keyboardAppearance = configuration[@"keyboardAppearance"];
    if ([configuration[@"obscureText"] boolValue]) {
        _activeView = _secureView;
    } else {
        _activeView = _view;
    }
    
    NSString* inputTypeName = inputType[@"name"];
    UIKeyboardType keyboardType = [KeyboardTypeMapper toUIKeyboardType:inputTypeName];
    if (keyboardType == UIKeyboardTypeNumberPad) {
        if ([inputType[@"signed"] boolValue]){
            keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        }
        if ([inputType[@"decimal"] boolValue]){
            keyboardType = UIKeyboardTypeDecimalPad;
        }   
    }
    _activeView.keyboardType = keyboardType;

    NSString* inputActionName = configuration[@"inputAction"];
    _activeView.returnKeyType = [KeyboardTypeMapper toUIReturnKeyType:inputActionName];

    NSString* textCapitalizationName = configuration[@"textCapitalization"];
    _activeView.autocapitalizationType = [KeyboardTypeMapper toUITextAutoCapitalizationType:textCapitalizationName];

    if ([keyboardAppearance isEqualToString:@"Brightness.dark"]) {
        _activeView.keyboardAppearance = UIKeyboardAppearanceDark;
    } else if ([keyboardAppearance isEqualToString:@"Brightness.light"]) {
        _activeView.keyboardAppearance = UIKeyboardAppearanceLight;
    } else {
        _activeView.keyboardAppearance = UIKeyboardAppearanceDefault;
    }
    NSString* autocorrect = configuration[@"autocorrect"];
    _activeView.autocorrectionType = autocorrect && ![autocorrect boolValue]
    ? UITextAutocorrectionTypeNo
    : UITextAutocorrectionTypeDefault;
    [_activeView setTextInputClient:client];
    [_activeView reloadInputViews];
    _activeView.inputFilter = configuration[@"inputFilter"];
    _activeView.maxLength = [configuration[@"maxLength"] intValue];
}

- (void)setTextInputEditingState:(NSDictionary*)state {
    [_activeView setTextInputState:state];
}

- (void)clearTextInputClient {
    [_activeView setTextInputClient:0];
}

@end

