//
//  AceVideo.h
//  sources
//
//  Created by wuhuanlong 吴焕隆 on 2022/3/24.
//

#import <Foundation/Foundation.h>

#import "AceTexture.h"
#import "IAceOnCallResourceMethod.h"
#import "IAceOnResourceEvent.h"

NS_ASSUME_NONNULL_BEGIN

@interface AceVideo : NSObject

- (instancetype)init:(int64_t)incId onEvent:(IAceOnResourceEvent)callback texture:(AceTexture *)texture;
- (NSDictionary<NSString *, IAceOnCallResourceMethod> *)getCallMethod;

- (void)releaseObject;
@end

NS_ASSUME_NONNULL_END
