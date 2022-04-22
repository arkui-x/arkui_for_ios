//
//  AceVideoResourcePlugin.h
//  libAceDemo
//
//  Created by wuhuanlong 吴焕隆 on 2022/3/17.
//

#import <Foundation/Foundation.h>
#import "AceResourcePlugin.h"
#import "AceVideo.h"

NS_ASSUME_NONNULL_BEGIN

@interface AceVideoResourcePlugin : AceResourcePlugin
- (id)getObject:(NSString *)id;
- (int64_t)create:(NSDictionary <NSString *, NSString *> *)param;
- (BOOL)release:(NSString *)id;
- (void)releaseObject;
@end

NS_ASSUME_NONNULL_END
