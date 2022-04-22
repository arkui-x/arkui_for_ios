//
//  AceCameraResoucePlugin.h
//  sources
//
//  Created by vail 王军平 on 2022/4/8.
//

#import "AceResourcePlugin.h"

NS_ASSUME_NONNULL_BEGIN

@interface AceCameraResoucePlugin : AceResourcePlugin

- (id)getObject:(NSString *)id;
- (int64_t)create:(NSDictionary <NSString *, NSString *> *)param;
- (BOOL)release:(NSString *)id;
- (void)releaseObject;

@end

NS_ASSUME_NONNULL_END
