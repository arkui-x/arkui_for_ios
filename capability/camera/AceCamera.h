//
//  AceCamera.h
//  sources
//
//  Created by vail 王军平 on 2022/4/8.
//

#import <Foundation/Foundation.h>
#import "AceTexture.h"
#import "IAceOnCallResourceMethod.h"
#import "IAceOnResourceEvent.h"

NS_ASSUME_NONNULL_BEGIN

@interface AceCamera : NSObject

- (instancetype)init:(int64_t)incId onEvent:(IAceOnResourceEvent)callback texture:(AceTexture *)texture;
- (NSDictionary<NSString *, IAceOnCallResourceMethod> *)getCallMethod;
- (void)releaseObject;

@end

NS_ASSUME_NONNULL_END
