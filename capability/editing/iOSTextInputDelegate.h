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

#ifndef iOSTextInputDelegate_h
#define iOSTextInputDelegate_h

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, iOSTextInputAction) {
  iOSTextInputActionUnspecified,
  iOSTextInputActionDone,
  iOSTextInputActionGo,
  iOSTextInputActionSend,
  iOSTextInputActionSearch,
  iOSTextInputActionNext,
  iOSTextInputActionContinue,
  iOSTextInputActionJoin,
  iOSTextInputActionRoute,
  iOSTextInputActionEmergencyCall,
  iOSTextInputActionNewline,
};

typedef NS_ENUM(NSInteger, iOSFloatingCursorDragState) {
  iOSFloatingCursorDragStateStart,
  iOSFloatingCursorDragStateUpdate,
  iOSFloatingCursorDragStateEnd,
};

typedef void (^updateEditingClientBlock)(int client, NSDictionary *state);
typedef void (^updateErrorTextBlock)(int client, NSDictionary *state);
// iOS keyboard trackpad caret drag (UIKit floating cursor). state: 0 = begin,
// 1 = update, 2 = end; (x, y) is the drag point in the window coordinate space.
typedef void (^updateFloatingCursorBlock)(int client, int state, double x, double y);
// Line-granularity caret move query (hardware keyboard up/down arrows).
// `fromIndex` is the anchor index carried in the query's UITextPosition (UIKit
// accumulates consecutive presses as growing offsets from the pre-gesture
// caret). Returns the target caret index, or -1 when the engine cannot answer.
typedef int (^lineMoveBlock)(int client, int fromIndex, BOOL isUp, int lines);
// Synchronous hit-test: caret index for a window-space point (the same space
// updateFloatingCursorBlock reports), or -1 when the engine cannot answer.
// Used to answer closestPositionToPoint: / characterRangeAtPoint: with real
// layout data instead of echoing the current selection.
typedef int (^caretIndexAtPointBlock)(int client, double x, double y);
// platformWillInsertNewline: the native text editor will insert the '\n' itself
// right after this callback returns (shouldChangeTextInRange returns YES), so
// the engine must not insert the newline again.
typedef void (^performActionBlock)(int action, int client, BOOL platformWillInsertNewline);

@protocol iOSTextInputDelegate <NSObject>

- (void)updateEditingClient:(int)client withState:(NSDictionary*)state;
- (void)performAction:(iOSTextInputAction)action withClient:(int)client;
- (void)updateFloatingCursor:(iOSFloatingCursorDragState)state
                  withClient:(int)client
                withPosition:(NSDictionary*)point;

@end

#endif /* iOSTextInputDelegate_h */
