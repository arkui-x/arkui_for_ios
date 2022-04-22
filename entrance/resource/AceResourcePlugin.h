//
//  AceResourcePlugin.h
//  libAceDemo
//
//  Created by wuhuanlong 吴焕隆 on 2022/3/17.
//

#import <Foundation/Foundation.h>
#import "AceResourceRegisterDelegate.h"
#import "IAceOnResourceEvent.h"
#import "IAceOnCallResourceMethod.h"

NS_ASSUME_NONNULL_BEGIN

@interface AceResourcePlugin : NSObject

@property (nonatomic, weak) id<AceResourceRegisterDelegate> resRegister;

@property (nonatomic, assign) int64_t version;

@property (nonatomic, copy) NSString* tag;

@property (nonatomic, weak) IAceOnResourceEvent callback;

- (instancetype)init:(NSString *)tag version:(int64_t)version;

- (int64_t)getAtomicId;

- (void)addResource:(int64_t)incId obj:(id)obj;

- (IAceOnResourceEvent)getEventCallback;

- (void)setEventCallback:(IAceOnResourceEvent)callback;

- (id)getObject:(int64_t)incId;

- (int64_t)create:(NSDictionary <NSString *, NSString *> *)param;

- (BOOL)release:(NSString *)incId;

- (void)releaseObject;

- (void)registerCallMethod:(NSDictionary<NSString *, IAceOnCallResourceMethod> *)methodMap;

- (void)unregisterCallMethod:(NSString *)method;

@end

NS_ASSUME_NONNULL_END
