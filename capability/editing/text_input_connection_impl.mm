/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
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

#include "adapter/ios/capability/editing/text_input_connection_impl.h"

#include "iOSTextInputDelegate.h"
#include "iOSTxtInputManager.h"
#import "KeyboardTypeMapper.h"

#include "adapter/ios/capability/editing/text_input_client_handler.h"
#include "frameworks/base/json/json_util.h"
#include "frameworks/base/utils/string_utils.h"
#include "base/log/event_report.h"
#include "base/log/log.h"

namespace OHOS::Ace::Platform {

TextInputConnectionImpl::TextInputConnectionImpl(
    const WeakPtr<TextInputClient>& client, const RefPtr<TaskExecutor>& taskExecutor)
    : TextInputConnection(client, taskExecutor)
{}

TextInputConnectionImpl::TextInputConnectionImpl(
    const WeakPtr<TextInputClient>& client, const RefPtr<TaskExecutor>& taskExecutor,const TextInputConfiguration& config)
    : TextInputConnection(client, taskExecutor)
{
  config_ = config;
}

void TextInputConnectionImpl::Show(bool isFocusViewChanged, int32_t instanceId){
    auto renderTextField = client_.Upgrade();
    if (!renderTextField) {
        return;
    }
    
    TextInputAction actionType = config_.action;
    NSString *inputAction = TextInputActionUnspecified;
    if(actionType == TextInputAction::UNSPECIFIED){
        inputAction = TextInputActionUnspecified;
    }else if(actionType == TextInputAction::GO){
        inputAction = TextInputActionGo;
    }else if(actionType == TextInputAction::SEARCH){
        inputAction = TextInputActionSearch;
    }else if(actionType == TextInputAction::SEND){
        inputAction = TextInputActionSend;
    }else if(actionType == TextInputAction::NEXT){
        inputAction = TextInputActionNext;
    }else if(actionType == TextInputAction::DONE){
        inputAction = TextInputActionDone;
    }
    
    TextInputType inputType = config_.type;
    NSString *inputTypeName = TextInputTypeText;
    NSInteger obscureText = 0;
    if(inputType == TextInputType::TEXT){
        inputTypeName = TextInputTypeText;
    }else if(inputType == TextInputType::MULTILINE){
        inputTypeName = TextInputTypeMultiline;
    }else if(inputType == TextInputType::NUMBER){
        inputTypeName = TextInputTypeNumber;
    }else if(inputType == TextInputType::DATETIME){
        inputTypeName = TextInputTypeDatetime;
    }else if(inputType == TextInputType::PHONE){
        inputTypeName = TextInputTypePhone;
    }else if(inputType == TextInputType::EMAIL_ADDRESS){
        inputTypeName = TextInputTypeEmailAddress;
    }else if(inputType == TextInputType::URL){
        inputTypeName = TextInputTypeURL;
    }else if(inputType == TextInputType::VISIBLE_PASSWORD){
        inputTypeName = TextInputTypeVisiblePassword;
        obscureText = 1;
    }

    NSString* inputFilter = [NSString stringWithFormat:@"%s", config_.inputFilter.c_str()];
    int32_t maxLength = config_.maxLength;
    
    int32_t clientId = this->GetClientId();
    LOGE("vailclientid->Show clientId:%d inputaction:%d inputType:%d",clientId,actionType,inputType);
    NSDictionary *configure = @{
        @"actionLabel" : @"",
        @"autocorrect" : @(1),
        @"enableIMEPersonalizedLearning" : @(1),
        @"enableSuggestions" : @(1),
        @"inputAction" : inputAction,
        @"inputType" : @{@"decimal":@"",@"name":inputTypeName,@"signed":@""},
        @"keyboardAppearance" : @"Brightness.default",
        @"obscureText":@(obscureText),
        @"readOnly":@(0),
        @"smartDashesType":@(1),
        @"smartQuotesType":@(1),
        @"textCapitalization":@"TextCapitalization.none",
        @"inputFilter" : inputFilter,
        @"maxLength" : [NSNumber numberWithInt:maxLength]
    };
    
    auto value = renderTextField->GetInputEditingValue();
    NSString *text = [NSString stringWithCString:value.text.c_str() encoding:NSUTF8StringEncoding];
    NSString *selectionAffinity = @"TextAffinity.downstream";
    if(value.selection.affinity == TextAffinity::UPSTREAM){
        selectionAffinity = @"TextAffinity.upstream";
    }
    NSDictionary *stateDict = @{
        @"text":text?:@"",
        @"selectionBase":@(value.selection.baseOffset),
        @"selectionExtent":@(value.selection.extentOffset),
        @"selectionAffinity":selectionAffinity,
        @"composingBase":@(value.compose.baseOffset),
        @"composingExtent":@(value.compose.extentOffset),
        @"selectionIsDirectional":@(0)
    };
    LOGE("vailclientid->Show sb:%d,se:%d,cb:%d,ce:%d,text:%s",value.selection.baseOffset,value.selection.extentOffset,value.compose.baseOffset,value.compose.extentOffset,text.UTF8String);
    
    TextInputNoParamsBlock showCallback = ^{
        updateEditingClientBlock textInputCallback = ^(int client, NSDictionary *state){
            if(clientId == client && [state objectForKey:@"text"]){
                NSString *text = [state objectForKey:@"text"];
                NSInteger selectionBase = [state[@"selectionBase"] intValue];
                NSInteger selectionExtent = [state[@"selectionExtent"] intValue];
                NSInteger composingBase = [state[@"composingBase"] intValue];
                NSInteger composingExtent = [state[@"composingExtent"] intValue];
                LOGE("vailclientid->Show textInputBlock ace:%d nav:%d text:%s",clientId,client,text.UTF8String);
                LOGE("vailclientid->Show textInputBlock sb:%d se:%d cb:%d ce:%d",selectionBase,selectionExtent,composingBase,composingExtent);
                auto textEditingValue = std::make_shared<TextEditingValue>();
                textEditingValue->text = text.UTF8String;
                textEditingValue->UpdateSelection(selectionBase,selectionExtent);
                textEditingValue->UpdateCompose(composingBase,composingExtent);
                TextInputClientHandler::GetInstance().UpdateEditingValue(client, textEditingValue, needFireChangeEvent_);
                needFireChangeEvent_ = true;
            }
        };
        [iOSTxtInputManager shareintance].textInputBlock = textInputCallback;
        updateErrorTextBlock errorTextCallback = ^(int client, NSDictionary *state){
            if(clientId == client && [state objectForKey:@"errorText"]){
                NSString *errorText = [state objectForKey:@"errorText"];
                TextInputClientHandler::GetInstance().UpdateInputFilterErrorText(client, [errorText UTF8String]);
            }
        };
        [iOSTxtInputManager shareintance].errorTextBlock = errorTextCallback;
        performActionBlock textPerformCallback = ^(int action, int client){
            if(clientId == client){
                TextInputAction actionType = TextInputAction::DONE; 
                switch (action) {
                    case iOSTextInputActionUnspecified:
                        actionType = TextInputAction::UNSPECIFIED;
                        break;
                    case iOSTextInputActionGo:
                        actionType = TextInputAction::GO;
                        break;
                    case iOSTextInputActionSearch:
                        actionType = TextInputAction::SEARCH;
                        break;
                    case iOSTextInputActionSend:
                        actionType = TextInputAction::SEND;
                        break;
                    case iOSTextInputActionNext:
                        actionType = TextInputAction::NEXT;
                        break;
                    case iOSTextInputActionDone:
                        actionType = TextInputAction::DONE;
                        break;
                    default:
                        break;
                }
                TextInputClientHandler::GetInstance().PerformAction(client, actionType);
                if(action == iOSTextInputActionDone){
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([iOSTxtInputManager shareintance]) {
                            [[iOSTxtInputManager shareintance] hideTextInput];
                            [iOSTxtInputManager shareintance].inputBoxY = 0.0;
                            [iOSTxtInputManager shareintance].inputBoxTopY = 0.0;
                            [iOSTxtInputManager shareintance].isDeclarative = false;
                        }
                    });
                }
            }
        };
        [iOSTxtInputManager shareintance].textPerformBlock = textPerformCallback;
        [iOSTxtInputManager shareintance].inputBoxY = renderTextField->GetEditingBoxY();
        [iOSTxtInputManager shareintance].inputBoxTopY = renderTextField->GetEditingBoxTopY();
        [iOSTxtInputManager shareintance].isDeclarative = renderTextField->GetEditingBoxModel();
        [[iOSTxtInputManager shareintance] setTextInputClient:clientId withConfiguration:configure];
        [[iOSTxtInputManager shareintance] setTextInputEditingState:stateDict];
        [[iOSTxtInputManager shareintance] showTextInput];
    };
    dispatch_main_async_safe(showCallback);
}

void TextInputConnectionImpl::SetEditingState(const TextEditingValue& value, int32_t instanceId, bool needFireChangeEvent){
    needFireChangeEvent_ = needFireChangeEvent;
    NSString *text = [NSString stringWithCString:value.text.c_str() encoding:NSUTF8StringEncoding];
    NSString *selectionAffinity = @"TextAffinity.downstream";
    if(value.selection.affinity == TextAffinity::UPSTREAM){
        selectionAffinity = @"TextAffinity.upstream";
    }
    
    LOGE("vailclientid->SetEditingState sb:%d,se:%d,cb:%d,ce:%d,text:%s",value.selection.baseOffset,value.selection.extentOffset,value.compose.baseOffset,value.compose.extentOffset,text.UTF8String);
    
    NSDictionary *stateDict = @{
        @"text":text?:@"",
        @"selectionBase":@(value.selection.baseOffset),
        @"selectionExtent":@(value.selection.extentOffset),
        @"selectionAffinity":selectionAffinity,
        @"composingBase":@(value.compose.baseOffset),
        @"composingExtent":@(value.compose.extentOffset),
        @"selectionIsDirectional":@(0)
    };
    
    dispatch_main_async_safe(^{
        [[iOSTxtInputManager shareintance] setTextInputEditingState:stateDict];
    });
}

void TextInputConnectionImpl::Close(int32_t instanceId){
    LOGE("vail->iOSTxtInput::Close");
    TextInputNoParamsBlock closeCallback = ^{
        [[iOSTxtInputManager shareintance] clearTextInputClient];
        [[iOSTxtInputManager shareintance] hideTextInput];
        [iOSTxtInputManager shareintance].inputBoxY = 0.0;
        [iOSTxtInputManager shareintance].inputBoxTopY = 0.0;
        [iOSTxtInputManager shareintance].isDeclarative = false;
    };
    dispatch_main_async_safe(closeCallback);
}

}
// namespace OHOS::Ace::Platform
