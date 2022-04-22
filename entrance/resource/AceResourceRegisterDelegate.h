//
//  AceResourceRegisterDelegate.h
//  libAceDemo
//
//  Created by wuhuanlong 吴焕隆 on 2022/3/17.
//
#import <Foundation/Foundation.h>
#import "IAceOnCallResourceMethod.h"

#ifndef AceResourceRegisterDelegate_h
#define AceResourceRegisterDelegate_h

@protocol AceResourceRegisterDelegate <NSObject>

- (id)getObject:(NSString *)resourceType incId:(int64_t)incId;

- (void)registerCallMethod:(NSString *)methodId
                callMethod:(IAceOnCallResourceMethod)callMethod;

- (void)unregisterCallMethod:(NSString *)methodId;

@end

#endif /* AceResourceRegisterDelegate_h */
