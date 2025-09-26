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
typedef void (^performActionBlock)(int action, int client);

@protocol iOSTextInputDelegate <NSObject>

- (void)updateEditingClient:(int)client withState:(NSDictionary*)state;
- (void)performAction:(iOSTextInputAction)action withClient:(int)client;
- (void)updateFloatingCursor:(iOSFloatingCursorDragState)state
                  withClient:(int)client
                withPosition:(NSDictionary*)point;

@end

#endif /* iOSTextInputDelegate_h */
