// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
typedef void (^performActionBlock)(int action, int client);

@protocol iOSTextInputDelegate <NSObject>

- (void)updateEditingClient:(int)client withState:(NSDictionary*)state;
- (void)performAction:(iOSTextInputAction)action withClient:(int)client;
- (void)updateFloatingCursor:(iOSFloatingCursorDragState)state
                  withClient:(int)client
                withPosition:(NSDictionary*)point;

@end

#endif /* iOSTextInputDelegate_h */
