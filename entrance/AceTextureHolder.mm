/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

#import "AceTextureHolder.h"

@implementation AceTextureHolder

static NSMutableDictionary<NSString *, id> *textureMap = nil;

+ (void)initialize
{
    NSLog(@"AceTextureHolder initialize");
    textureMap = [[NSMutableDictionary alloc] init];
}

+ (id)getTextureWithId:(long)textureId inceId:(long)inceId
{
    if (![self isValidId:textureId]) {
        return nil;
    }

    id Texture = nil;
    @synchronized (self) {
        Texture = [textureMap objectForKey:[self formatKeyId:textureId inceId:inceId]];
    }

    return Texture;
}

+ (void)addTexture:(id)texture withId:(long)textureId inceId:(long)inceId
{
    if (![self isValidId:textureId] || !texture) {
        return;
    }
    NSLog(@"AceTextureHolder addTexture:%@  id:%ld", texture, textureId);

    @synchronized (self) {
        if ([textureMap objectForKey:[self formatKeyId:textureId inceId:inceId]]) {
            return;
        }

        [textureMap setObject:texture forKey:[self formatKeyId:textureId inceId:inceId]];
    }
}

+ (void)removeTextureWithId:(long)textureId inceId:(long)inceId
{
    if (![self isValidId:textureId]) {
        return;
    }

    @synchronized (self) {
        [textureMap removeObjectForKey:[self formatKeyId:textureId inceId:inceId]];
    }
}

+ (BOOL)isValidId:(long)textureId
{
    return textureId > 0;
}

+ (NSString *)formatKeyId:(long)textureId inceId:(long)inceId
{
    return [NSString stringWithFormat:@"%d_%d",textureId,inceId];
}

@end