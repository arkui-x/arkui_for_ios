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

#import "AceSurfaceHolder.h"

@implementation AceSurfaceHolder

static NSMutableDictionary<NSString *, UIView *> *surfaceMap = nil;

+ (void)initialize
{
    NSLog(@"AceSurfaceHolder initialize");
    surfaceMap = [[NSMutableDictionary alloc] init];
}

+ (UIView *)getLayerWithId:(long)layerId inceId:(long)inceId
{
    if (![self isValidId:layerId]) {
        return nil;
    }
    
    UIView *layer = nil;
    @synchronized (self) {
        layer = [surfaceMap objectForKey:[self formatKeyId:layerId inceId:inceId]];
    }
    
    return layer;
}

+ (void)addLayer:(UIView *)layer withId:(long)layerId inceId:(long)inceId
{
    if (![self isValidId:layerId] || !layer) {
        return;
    }
    NSLog(@"AceSurfaceHolder addLayer:%@  id:%ld", layer, layerId);
    
    @synchronized (self) {
        if ([surfaceMap objectForKey:[self formatKeyId:layerId inceId:inceId]]) {
            return;
        }
        
        [surfaceMap setObject:layer forKey:[self formatKeyId:layerId inceId:inceId]];
    }
}

+ (void)removeLayerWithId:(long)layerId inceId:(long)inceId
{
    if (![self isValidId:layerId]) {
        return;
    }
    
    @synchronized (self) {
        [surfaceMap removeObjectForKey:[self formatKeyId:layerId inceId:inceId]];
    }
}

+ (BOOL)isValidId:(long)layerId
{
    return layerId > 0;
}

+ (NSString *)formatKeyId:(long)layerId inceId:(long)inceId
{
    return [NSString stringWithFormat:@"%d_%d",layerId,inceId];
}

@end
