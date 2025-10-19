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

#import "AceWebResourcePlugin.h"
#import "AceWebPatternOCBridge.h"

void SetScrollLockedRegisterOC(int webId, const bool& value)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", webId]];
    if (web == nil) {
        return;
    }
    web.webScrollEnabled = !value;
}
void SetNestedScrollOptionsExtOC(int webId, void* options)
{
    AceWeb* web = [AceWebResourcePlugin.getObjectMap objectForKey:[NSString stringWithFormat:@"%d", webId]];
    if (web == nil) {
        return;
    }
    [web setNestedScrollOptionsExt:options];
}