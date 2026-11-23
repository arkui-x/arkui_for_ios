/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025-2025. All rights reserved.
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

#import "iOSTxtInputManager.h"
#import "KeyboardTypeMapper.h"
#import "base/log/log.h"
#import "WindowView.h"

#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>

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

{
    // YES while a keyboard trackpad floating-cursor drag is in flight; UIKit
    // computes drag targets via characterRangeAtPoint:, which this adapter (no
    // text layout) cannot answer, so selection echoes it derives from the stale
    // answer are suppressed until the drag ends and the engine pushes the landed
    // caret back.
    BOOL _isFloatingCursorActive;
    // Last caret rect (window coordinates) pushed by the engine; the view itself
    // sits at the window origin, so window coordinates are view coordinates.
    CGRect _lastCaretRect;
}

// UITextInput
@property(nonatomic, readonly) NSMutableString* text;
@property(nonatomic, readonly) NSMutableString* markedText;
@property(nonatomic, readonly) NSMutableString* appendText;
@property(readwrite, copy) UITextRange* selectedTextRange;
@property(nonatomic, strong) UITextRange* markedTextRange;
@property(nonatomic, copy) NSDictionary* markedTextStyle;
@property(nonatomic, weak) id<UITextInputDelegate> inputDelegate;
@property(nonatomic, copy) NSString* inputFilter;
@property(nonatomic) NSUInteger maxLength;
@property(nonatomic) NSUInteger markedTextLocation;
@property(nonatomic) NSUInteger markedTextLength;
@property(nonatomic) NSUInteger textLength;
@property(nonatomic) BOOL insertNewlineOnEnter;

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
@property (nonatomic, copy) updateFloatingCursorBlock floatingCursorBlock;
@property (nonatomic, copy) lineMoveBlock lineMoveBlock;
@property (nonatomic, copy) caretIndexAtPointBlock caretIndexAtPointBlock;
- (int)lineMoveIndexFrom:(int)fromIndex isUp:(BOOL)isUp lines:(int)lines;
- (int)hitTestCaretIndexAtPoint:(CGPoint)point;
// Reset the floating-cursor drag state; called by the manager on teardown paths
// (hideTextInput) because UIKit does not guarantee endFloatingCursor when the
// drag is interrupted (e.g. keyboard dismissed mid-drag) - a stuck YES would
// permanently drop UIKit selections and freeze caretRect updates.
- (void)resetFloatingCursorState;

@end

// Line-granularity moves need glyph layout, which only the engine has; the stock
// string tokenizer degrades them to character moves computed from empty
// selection rects, which made hardware up/down arrows walk the caret sideways
// and then jump to random positions. Delegate line moves to the engine and keep
// the string tokenizer's character/word behavior for everything else.
@interface iOSTextLineTokenizer : UITextInputStringTokenizer
@property (nonatomic, weak) iOSTextInputView* owner;
@end

@implementation iOSTextInputView {
    int _textInputClient;
    const char* _selectionAffinity;
    iOSTextRange* _selectedTextRange;
    BOOL _isDelete;
    BOOL _unmarkText;
    BOOL _discardedMarkedText;
    BOOL _isSetSelectedTextRange;
}

// The view spans the window so UIKit's floating cursor is clamped to the
// visible area; it must not intercept touches meant for the ArkUI content.
- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
    return nil;
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
        _appendText = [[NSMutableString alloc] init];
        _selectedTextRange = [[iOSTextRange alloc] initWithNSRange:NSMakeRange(0, 0)];
        _markedTextLocation = 0;
        _markedTextLength = 0;
        _isDelete = NO;
        _unmarkText = NO;
        _discardedMarkedText = NO;
        _isSetSelectedTextRange = NO;
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

- (UITextSmartDashesType)smartDashesType API_AVAILABLE(ios(11.0)) {
    return self.isSecureTextEntry ? UITextSmartDashesTypeNo : UITextSmartDashesTypeDefault;
}

- (UITextSmartQuotesType)smartQuotesType API_AVAILABLE(ios(11.0)) {
    return self.isSecureTextEntry ? UITextSmartQuotesTypeNo : UITextSmartQuotesTypeDefault;
}

- (void)dealloc {
    [_text release];
    [_markedText release];
    [_appendText release];
    [_markedTextRange release];
    [_selectedTextRange release];
    [_tokenizer release];
    [super dealloc];
}

- (void)setTextInputClient:(int)client {
    _textInputClient = client;
}

- (void)setTextInputState:(NSDictionary*)state {
    // Latest caret rect in window coordinates, pushed by the engine with every
    // editing state. Used by caretRectForPosition: to anchor the floating cursor.
    // Frozen while a trackpad drag is in flight: UIKit magnets the lens to the
    // rect answered by caretRectForPosition:, so feeding it the LIVE caret turns
    // the drag into a lens<->caret feedback loop - the lens can never lead the
    // caret by a full glyph, and the caret stalls partway (observed: cannot reach
    // the text start when dragging left). Anchoring at the pre-drag caret keeps
    // the magnet static and lets the lens track the finger freely.
    if (state[@"caretRectX"] != nil && !_isFloatingCursorActive) {
        _lastCaretRect = CGRectMake([state[@"caretRectX"] doubleValue], [state[@"caretRectY"] doubleValue],
            [state[@"caretRectWidth"] doubleValue], [state[@"caretRectHeight"] doubleValue]);
    }
    if (self.markedTextRange != nil) {
        return;
    }
    NSString *newText = state[@"text"];
    BOOL textChanged = ![self.text isEqualToString:newText];
    if (textChanged) {
        [self.inputDelegate textWillChange:self];
        [self.text setString:newText];
    }
    NSInteger selectionBase = [state[@"selectionBase"] intValue];
    NSInteger selectionExtent = [state[@"selectionExtent"] intValue];
    NSRange selectedRange = [self clampSelection:NSMakeRange(MIN(selectionBase, selectionExtent), ABS(selectionBase - selectionExtent)) forText:self.text];
    NSRange oldSelectedRange = [(iOSTextRange*)self.selectedTextRange range];
    if (selectedRange.location != oldSelectedRange.location || selectedRange.length != oldSelectedRange.length) {
        [self.inputDelegate selectionWillChange:self];
        [self setSelectedTextRange:[iOSTextRange rangeWithNSRange:selectedRange] updateEditingState:NO];
        _selectionAffinity = _kTextAffinityDownstream;
        if ([state[@"selectionAffinity"] isEqualToString:@(_kTextAffinityUpstream)]){
           _selectionAffinity = _kTextAffinityUpstream;
        }
        [self.inputDelegate selectionDidChange:self];
    }
    if (textChanged) {
        [self.inputDelegate textDidChange:self];
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
        iOSTextLineTokenizer* lineTokenizer = [[iOSTextLineTokenizer alloc] initWithTextInput:self];
        lineTokenizer.owner = self;
        _tokenizer = lineTokenizer;
    }
    return _tokenizer;
}

- (UITextRange*)selectedTextRange {
    return [_selectedTextRange copy];
}

- (void)setSelectedTextRange:(UITextRange*)selectedTextRange {
    if (_isFloatingCursorActive) {
        // Trackpad drag in flight: the engine owns the caret; drop UIKit's
        // echo selections derived from the stale characterRangeAtPoint: answer.
        return;
    }
    _isSetSelectedTextRange = YES;
    [self setSelectedTextRange:selectedTextRange updateEditingState:YES];
}

- (void)setSelectedTextRange:(UITextRange*)selectedTextRange updateEditingState:(BOOL)update {
    if (_selectedTextRange != selectedTextRange) {
        if (self.hasText && !_isSetSelectedTextRange) {
            iOSTextRange* iosTextRange = (iOSTextRange*)selectedTextRange;
            _selectedTextRange = [[iOSTextRange
                                   rangeWithNSRange:[self RangeForCharactersInRange:self.text range:iosTextRange.range]] copy];
        } else {
            _selectedTextRange = [selectedTextRange copy];
        }
        if (update) {
            [self updateEditingState];
        }
    }
    _isSetSelectedTextRange = NO;
}

- (NSRange)RangeForCharactersInRange:(NSString* )text range:(NSRange)range {
    if (text == nil || range.location + range.length > text.length) {
        return NSMakeRange(NSNotFound, 0);
    }
    NSRange sanitizedRange = [text rangeOfComposedCharacterSequencesForRange:range];
    return NSMakeRange(sanitizedRange.location, range.length);
}

- (id)insertDictationResultPlaceholder {
    return @"";
}

- (void)removeDictationResultPlaceholder:(id)placeholder willInsertResult:(BOOL)willInsertResult {
}

- (NSString*)textInRange:(UITextRange*)range {
    if (range == nil || ![range isKindOfClass:[iOSTextRange class]] || self.text == nil) {
        LOGE("[iOSTxtInputManager] textInRange: invalid input (class=%{public}s, textIsNil=%{public}s)",
              range ? NSStringFromClass([range class]).UTF8String : "(null)",
              self.text ? "NO" : "YES");
        return @"";
    }
    NSRange textRange = ((iOSTextRange*)range).range;
    if (textRange.location == NSNotFound) {
        LOGE("[iOSTxtInputManager] textInRange: invalid textRange (location=NSNotFound)");
        return @"";
    }
    NSUInteger availableLength = self.text.length;
    if (self.maxLength > 0) {
        availableLength = MIN(availableLength, self.maxLength);
    }
    NSString* availableText = self.text;
    if (availableLength < self.text.length) {
        availableText = [self.text substringWithRange:NSMakeRange(0, availableLength)];
    }
    NSRange clampedRange = [self clampSelection:textRange forText:availableText];
    if (clampedRange.location == NSNotFound || clampedRange.location > availableText.length) {
        LOGE("[iOSTxtInputManager] textInRange: invalid clampedRange (loc=%{public}lu len=%{public}lu, availableLen=%{public}lu)",
              (unsigned long)clampedRange.location,
              (unsigned long)clampedRange.length,
              (unsigned long)availableText.length);
        return @"";
    }
    NSRange composedRange = [availableText rangeOfComposedCharacterSequencesForRange:clampedRange];
    if (composedRange.location == NSNotFound || composedRange.location + composedRange.length > availableText.length) {
        LOGE("[iOSTxtInputManager] textInRange: invalid composedRange (loc=%{public}lu len=%{public}lu, availableLen=%{public}lu)",
              (unsigned long)composedRange.location,
              (unsigned long)composedRange.length,
              (unsigned long)availableText.length);
        return @"";
    }
    return [availableText substringWithRange:composedRange];
}

- (void)replaceRange:(UITextRange*)range withText:(NSString*)text {
    // Note: do NOT block '\n' here. The keyboard's autocorrect/candidate-commit replay
    // re-inserts the whole text (including newlines) via replaceRange on an internal
    // path that bypasses shouldChangeTextInRange; dropping the newline desyncs the
    // adapter text and the keyboard replaces the content with a fused string.
    // The Enter key is handled in shouldChangeTextInRange (local mirror + return NO),
    // so '\n' reaching this method must be applied.
    NSRange replaceRange = ((iOSTextRange*)range).range;
    NSRange selectedRange = _selectedTextRange.range;
    // Adjust the text selection:
    // * reduce the length by the intersection length
    // * adjust the location by newLength - oldLength + intersectionLength
    NSRange intersectionRange = NSIntersectionRange(replaceRange, selectedRange);
    if (replaceRange.location <= selectedRange.location) {
        selectedRange.location += text.length - replaceRange.length;
    }
    if (intersectionRange.location != NSNotFound) {
        selectedRange.location += intersectionRange.length;
        selectedRange.length -= intersectionRange.length;
    }
    [self.text replaceCharactersInRange:[self clampSelection:replaceRange forText:self.text] withString:text];
    [self setSelectedTextRange:
        [iOSTextRange rangeWithNSRange:
        [self clampSelection:selectedRange forText:self.text]] updateEditingState:NO];
    if (text.length == 0 && replaceRange.length != 0) {
        _unmarkText = YES;
        self.markedTextRange = [iOSTextRange rangeWithNSRange:replaceRange];
    } else {
        [self.appendText setString:text];
        self.markedTextRange = replaceRange.length > 0 ? [iOSTextRange rangeWithNSRange:replaceRange] : nil;
        if ((self.markedText.length == 0) && (self.text.length >= self.maxLength)) {
            NSRange range =  NSMakeRange(self.markedTextLocation, self.maxLength);
            if (range.location + range.length < self.text.length) {
                [self.appendText setString:[self.text substringWithRange:range]];
            }
        }
    }
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
            for (int i = 0; i < [text length]; i++) {
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
        if (self.textPerformBlock) {
            self.textPerformBlock(iOSTextInputActionNewline, _textInputClient, self.insertNewlineOnEnter);
        }
        // Let the keyboard execute insertText("\n") when a newline should be inserted:
        // if the insert is rejected the keyboard keeps its autocorrect session across
        // the line break and later rolls back/rebuilds text from the previous line,
        // dropping the newline. The engine receives '\n' through the appendText event
        // (replaceRange below), so PerformAction must not insert it again.
        return self.insertNewlineOnEnter;
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
        if (self.textPerformBlock) {
            // This branch returns NO below: the native editor never inserts the
            // newline, so the engine must not be told otherwise.
            self.textPerformBlock(action, _textInputClient, NO);
        }
        return NO;
    }
    
    return YES;
}

- (void)setMarkedText:(NSString*)markedText selectedRange:(NSRange)markedSelectedRange {
    NSRange selectedRange = _selectedTextRange.range;
    NSRange markedTextRange = ((iOSTextRange*)self.markedTextRange).range;
    if (markedText == nil) {
        markedText = @"";
    }
    [self.markedText setString:markedText];
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
    [self setSelectedTextRange:
        [iOSTextRange rangeWithNSRange:[self clampSelection:selectedRange forText:self.text]] updateEditingState:YES];
}

- (void)unmarkText {
    _unmarkText = YES;
    if (self.text.length >= self.maxLength) {
        NSInteger length = self.maxLength - self.textLength;
        NSRange range =  NSMakeRange(self.markedTextLocation, length > 0 ? length : 0);
        if (range.location + range.length > self.text.length) {
            return;
        }
        [self.appendText setString:[self.text substringWithRange:range]];
    } else {
        self.markedTextRange = nil;
    }
    [self updateEditingState];
}

- (UITextRange*)textRangeFromPosition:(UITextPosition*)fromPosition
                           toPosition:(UITextPosition*)toPosition {
    NSUInteger fromIndex = ((iOSTextPosition*)fromPosition).index;
    NSUInteger toIndex = ((iOSTextPosition*)toPosition).index;
    return [iOSTextRange rangeWithNSRange:NSMakeRange(fromIndex, toIndex - fromIndex)];
}

- (NSRange)RangeForCharacterAtIndex:(NSString* )text index:(NSUInteger)index {
    if (text == nil || index >= text.length) {
        return NSMakeRange(NSNotFound, 0);
    }
    if (index < text.length) {
        return [text rangeOfComposedCharacterSequenceAtIndex:index];
    }
    return NSMakeRange(index, 0);
}

- (NSUInteger)decrementOffsetPosition:(NSUInteger)position {
    return [self RangeForCharacterAtIndex:self.text index:MAX(0, position - 1)].location;
}

- (NSUInteger)incrementOffsetPosition:(NSUInteger)position {
    NSRange charRange = [self RangeForCharacterAtIndex:self.text index:position];
    return MIN(position + charRange.length, self.text.length);
}

- (UITextPosition*)positionFromPosition:(UITextPosition*)position offset:(NSInteger)offset {
    NSUInteger offsetPosition = ((iOSTextPosition*)position).index;
    NSInteger newLocation = (NSInteger)offsetPosition + offset;
    if (newLocation < 0 || newLocation > (NSInteger)self.text.length) {
        return nil;
    }
    if (offset >= 0) {
        for (NSInteger i = 0; i < offset && offsetPosition < self.text.length; ++i) {
            offsetPosition = [self incrementOffsetPosition:offsetPosition];
        }
    } else {
        for (NSInteger i = 0; i < ABS(offset) && offsetPosition > 0; ++i) {
            offsetPosition = [self decrementOffsetPosition:offsetPosition];
        }
    }
    return [iOSTextPosition positionWithIndex:offsetPosition];
}

- (UITextPosition*)positionFromPosition:(UITextPosition*)position
                            inDirection:(UITextLayoutDirection)direction
                                 offset:(NSInteger)offset {
    switch (direction) {
        case UITextLayoutDirectionLeft:
            return [self positionFromPosition:position offset:offset * -1];
        case UITextLayoutDirectionRight:
            return [self positionFromPosition:position offset:offset];
        case UITextLayoutDirectionUp:
        case UITextLayoutDirectionDown: {
            // The adapter owns no text layout, so up/down must not degrade to
            // character moves (that made hardware arrows walk the caret sideways).
            // Delegate the line-granularity move to the engine, anchored at the
            // queried position (UIKit accumulates consecutive presses as growing
            // offsets from the pre-gesture caret, so the answer must be relative
            // to the anchor, not to the already-moved caret).
            if (self.lineMoveBlock && offset >= 1) {
                BOOL isUp = (direction == UITextLayoutDirectionUp);
                int fromIndex = static_cast<int>(static_cast<iOSTextPosition*>(position).index);
                int index = self.lineMoveBlock(_textInputClient, fromIndex, isUp, static_cast<int>(offset));
                if (index >= 0) {
                    return [iOSTextPosition positionWithIndex:index];
                }
            }
            // offset 0 (gesture counter back at the anchor) and unanswerable
            // queries keep the queried position: this matches the native iOS
            // behavior where reversing direction returns to the pre-gesture
            // caret (verified against Apple Notes).
            return position;
        }
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
    if (positionIndex < otherIndex) {
        return NSOrderedAscending;
    }
    if (positionIndex > otherIndex) {
        return NSOrderedDescending;
    }
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
    // UIKit anchors the floating cursor here at trackpad-drag start; the engine
    // keeps this rect in sync with the real caret via the editing state push.
    return _lastCaretRect;
}

- (UITextPosition*)closestPositionToPoint:(CGPoint)point {
    // Real layout hit test: echoing the current selection here left UIKit's
    // floating cursor magnet/target planning blind (a real UITextView answers
    // with the character actually under the point).
    int index = [self hitTestCaretIndexAtPoint:point];
    if (index < 0) {
        index = static_cast<int>(static_cast<iOSTextPosition*>(_selectedTextRange.start).index);
    }
    return [iOSTextPosition positionWithIndex:index];
}

- (NSArray*)selectionRectsForRange:(UITextRange*)range {
    return @[];
}

- (UITextPosition*)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange*)range {
    int index = [self hitTestCaretIndexAtPoint:point];
    if (index < 0) {
        return range.start;
    }
    NSUInteger lo = static_cast<iOSTextPosition*>(range.start).index;
    NSUInteger hi = static_cast<iOSTextPosition*>(range.end).index;
    NSUInteger clamped = MIN(MAX(static_cast<NSUInteger>(index), lo), hi);
    return [iOSTextPosition positionWithIndex:clamped];
}

- (UITextRange*)characterRangeAtPoint:(CGPoint)point {
    int index = [self hitTestCaretIndexAtPoint:point];
    if (index < 0) {
        index = static_cast<int>(static_cast<iOSTextPosition*>(_selectedTextRange.start).index);
    }
    // RangeForCharacterAtIndex: answers NSNotFound for index == length; at the
    // text end report the last character instead.
    if (self.text.length > 0 && index >= static_cast<int>(self.text.length)) {
        index = static_cast<int>(self.text.length) - 1;
    }
    return [iOSTextRange rangeWithNSRange:[self RangeForCharacterAtIndex:self.text index:index]];
}

// iOS keyboard trackpad caret drag. The adapter owns no text layout so it cannot
// answer characterRangeAtPoint:; forward the drag to the engine, which hit-tests
// the point against its own text layout and moves the caret.
- (void)beginFloatingCursorAtPoint:(CGPoint)point {
    _isFloatingCursorActive = YES;
    if (self.floatingCursorBlock) {
        CGPoint windowPoint = [self convertPoint:point toView:nil];
        self.floatingCursorBlock(_textInputClient, 0, windowPoint.x, windowPoint.y);
    }
}

- (void)updateFloatingCursorAtPoint:(CGPoint)point {
    if (self.floatingCursorBlock) {
        CGPoint windowPoint = [self convertPoint:point toView:nil];
        self.floatingCursorBlock(_textInputClient, 1, windowPoint.x, windowPoint.y);
    }
}

- (void)endFloatingCursor {
    _isFloatingCursorActive = NO;
    if (self.floatingCursorBlock) {
        self.floatingCursorBlock(_textInputClient, 2, 0.0, 0.0);
    }
}

- (void)resetFloatingCursorState {
    // Bare reset, no endFloatingCursor callback: the connection may already be
    // detached when the manager tears the input down mid-drag.
    _isFloatingCursorActive = NO;
}

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
                if (self.text.length >= self.markedTextLocation + self.markedTextLength) {
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
                // NOTE: When discarding marked text, we skip maxLength trimming to avoid unintended extra truncation.
                if (self.appendText.length == 0 || (_unmarkText && !_discardedMarkedText)) {
                    NSString *newText = [self.text substringWithRange:NSMakeRange(0, self.maxLength)];
                    [self.text setString:newText];
                }
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
        @"appendText" : [NSString stringWithString:self.appendText],
        @"isDelete" : @(_isDelete),
        @"unmarkText" : @(_unmarkText),
        @"discardedMarkedText" : @(_discardedMarkedText),
    };
    if (_unmarkText || _discardedMarkedText) {
        _unmarkText = NO;
        self.markedTextRange = nil;
        self.markedTextLocation = 0;
        self.markedTextLength = 0;
        self.textLength = self.text.length > self.maxLength && !_discardedMarkedText ? self.maxLength : self.text.length;
    } else {
        self.textLength = self.text.length - self.markedTextLength;
    }
    if  (_isDelete) {
        _isDelete = NO;
        self.textLength = self.text.length;
    }
    _discardedMarkedText = NO;
    [self.appendText setString:@""];
    [self.markedText setString:@""];
    if (self.textInputBlock) {
        self.textInputBlock(_textInputClient, dict);
    }
}

- (void)updateInputFilterErrorText:(NSString*)errorText {
    NSDictionary *dict = @{
        @"errorText" : errorText,
    };
    if (self.errorTextBlock) {
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
        for (int i = 0; i < [text length]; i++) {
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
    NSInteger length = self.maxLength - self.text.length;
    if (self.text.length + text.length > self.maxLength && length > 0) {
        text = [text substringWithRange:NSMakeRange(0, length)];
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
    if (!_selectedTextRange.isEmpty) {
        _isDelete = YES;
        [self replaceRange:_selectedTextRange withText:@""];
    }
}

- (void)discardMarkedText {
    [self.inputDelegate textWillChange:self];
    [self.inputDelegate selectionWillChange:self];
    _discardedMarkedText = YES;
    _unmarkText = YES;
    [self setMarkedText:nil selectedRange:NSMakeRange(0, 0)];
    [self.inputDelegate selectionDidChange:self];
    [self.inputDelegate textDidChange:self];
}

// Line-granularity caret move, delegated to the engine (which owns the text
// layout) through the connection's block; -1 when no engine is attached.
- (int)lineMoveIndexFrom:(int)fromIndex isUp:(BOOL)isUp lines:(int)lines {
    if (self.lineMoveBlock) {
        return self.lineMoveBlock(_textInputClient, fromIndex, isUp, lines);
    }
    return -1;
}

// Caret hit test, delegated to the engine (which owns the text layout) through
// the connection's block; -1 when no engine is attached. Called synchronously
// from UIKit (tokenizer/floating cursor queries on the main thread). `point`
// arrives in view coordinates; the block contract is window coordinates (the
// engine hit-tests against the window space), so convert here once for every
// caller instead of relying on the view happening to span the window at origin.
- (int)hitTestCaretIndexAtPoint:(CGPoint)point {
    if (self.caretIndexAtPointBlock) {
        CGPoint windowPoint = [self convertPoint:point toView:nil];
        return self.caretIndexAtPointBlock(_textInputClient, windowPoint.x, windowPoint.y);
    }
    return -1;
}

@end

@implementation iOSTextLineTokenizer

- (UITextPosition*)positionFromPosition:(UITextPosition*)position
                     toLineGranularity:(UITextLayoutDirection)direction {
    if (self.owner != nil && (direction == UITextLayoutDirectionUp ||
        direction == UITextLayoutDirectionDown)) {
        int fromIndex = static_cast<int>(static_cast<iOSTextPosition*>(position).index);
        int index = [self.owner lineMoveIndexFrom:fromIndex
            isUp:(direction == UITextLayoutDirectionUp) lines:1];
        if (index >= 0) {
            return [iOSTextPosition positionWithIndex:index];
        }
    }
    return [super positionFromPosition:position toLineGranularity:direction];
}

@end

@interface TextInputHideView : UIView

@end

@implementation TextInputHideView

- (BOOL)accessibilityElementsHidden {
    return YES;
}

// The hider spans the window so the input view's frame can track window bounds
// changes via autoresizing; claim no touches, they belong to the ArkUI content.
- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
    return nil;
}

@end

@implementation iOSTxtInputManager {
    iOSTextInputView* _view;
    iOSTextInputView* _secureView;
    iOSTextInputView* _activeView;
    TextInputHideView* _inputHider;
}

@synthesize textInputBlock = _textInputBlock;
@synthesize errorTextBlock = _errorTextBlock;
@synthesize textPerformBlock = _textPerformBlock;
@synthesize floatingCursorBlock = _floatingCursorBlock;
@synthesize lineMoveBlock = _lineMoveBlock;
@synthesize caretIndexAtPointBlock = _caretIndexAtPointBlock;

+ (instancetype)sharedInstance {
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
    [self clearTextInputClient];
    [super dealloc];
}

- (UIView<UITextInput>*)textInputView {
    return _activeView;
}

- (void)showTextInput {
    NSAssert([UIApplication sharedApplication].keyWindow != nullptr,
             @"The application must have a key window since the keyboard client "
             @"must be part of the responder chain to function");
    UIView<UITextInput>* textInputView = [self textInputView];
    if (textInputView == nil) {
        return;
    }
    UIView* parentView = textInputView.superview;
    while (parentView != nil) {
        if ([parentView isKindOfClass:[WindowView class]]) {
            WindowView* windowView = (WindowView*)parentView;
            if (!windowView.focusable) {
                LOGI("[iOSTxtInputManager] showTextInput skipped: view is not focusable");
                [self hideTextInput];
                return;
            }
            break;
        }
        parentView = parentView.superview;
    }
    if (self.textInputBlock) {
        _activeView.textInputBlock = self.textInputBlock;
    }
    if (self.errorTextBlock) {
        _activeView.errorTextBlock = self.errorTextBlock;
    }
    if (self.textPerformBlock) {
        _activeView.textPerformBlock = self.textPerformBlock;
    }
    if (self.floatingCursorBlock) {
        _activeView.floatingCursorBlock = self.floatingCursorBlock;
    }
    if (self.lineMoveBlock) {
        _activeView.lineMoveBlock = self.lineMoveBlock;
    }
    if (self.caretIndexAtPointBlock) {
        _activeView.caretIndexAtPointBlock = self.caretIndexAtPointBlock;
    }
    if (![_activeView isFirstResponder]) {
        [self addToInputParentViewIfNeeded:_activeView];
        [_activeView becomeFirstResponder];
    }
}

- (UIWindow*)keyWindowInSceneWithActivationState:(UISceneActivationState)state API_AVAILABLE(ios(13.0)) {
    for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
        if (windowScene.activationState == state && [windowScene isKindOfClass:UIWindowScene.class]) {
            for (UIWindow *window in windowScene.windows) {
                if (!window.hidden && window.isKeyWindow) {
                    return window;
                }
            }
        }
    }
    return nil;
}

- (UIWindow*)keyWindow {
    if (@available(iOS 13.0, *)) {
        UIWindow *keyWindow = [self keyWindowInSceneWithActivationState:UISceneActivationStateForegroundActive];
        if (!keyWindow) {
            keyWindow = [self keyWindowInSceneWithActivationState:UISceneActivationStateForegroundInactive];
        }
        return keyWindow;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
}

- (void)addToInputParentViewIfNeeded:(iOSTextInputView*)inputView {
    if ([inputView isDescendantOfView:_inputHider]) {
        [inputView removeFromSuperview];
    }
    [_inputHider addSubview:inputView];
    UIView* parentView = self.keyWindow;
    if (parentView == nil) {
        return;
    }
    if ([_inputHider isDescendantOfView:parentView]) {
        [_inputHider removeFromSuperview];
    }
    [parentView addSubview:_inputHider];
    // Span the window so UIKit clamps the floating cursor to the visible area
    // (a zero-size frame biases its coordinate math); hitTest: passes touches
    // through to the ArkUI content below. Track window bounds changes (rotation,
    // split screen) via autoresizing so the floating-cursor clamp never relies
    // on a stale frame: the hider follows the window, the input view follows
    // the hider.
    _inputHider.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _inputHider.frame = parentView.bounds;
    inputView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    inputView.frame = parentView.bounds;
}

- (void)hideTextInput {
    // Fallback reset: a trackpad drag interrupted by keyboard teardown never
    // receives endFloatingCursor, which would leave the drag flag stuck and
    // permanently suppress UIKit selections and caretRect updates.
    [_activeView resetFloatingCursorState];
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
        if ([inputType[@"signed"] boolValue]) {
            keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        }
        if ([inputType[@"decimal"] boolValue]) {
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
    _activeView.insertNewlineOnEnter = [configuration[@"insertNewlineOnEnter"] boolValue];
}

- (void)setTextInputEditingState:(NSDictionary*)state {
    [_activeView setTextInputState:state];
}

- (void)clearTextInputClient {
    [_activeView resetFloatingCursorState];
    [_activeView setTextInputClient:0];
    _activeView.textInputBlock = NULL;
    _activeView.errorTextBlock = NULL;
    _activeView.textPerformBlock = NULL;
    _activeView.floatingCursorBlock = NULL;
    _activeView.lineMoveBlock = NULL;
    _activeView.caretIndexAtPointBlock = NULL;
}

- (void)finishComposing {
    [_activeView discardMarkedText];
}

@end

