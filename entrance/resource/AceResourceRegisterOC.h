//
//  AceResourceRegister.h
//  libAceDemo
//
//  Created by wuhuanlong 吴焕隆 on 2022/3/17.
//

#import <Foundation/Foundation.h>
#import "AceResourcePlugin.h"
#import "FlutterEngine.h"
#import "IAceOnCallResourceMethod.h"
#import "IAceOnResourceEvent.h"

NS_ASSUME_NONNULL_BEGIN

@protocol IAceOnCallEvent <NSObject>
@required
- (void)onEvent:(NSString *)eventId param:(NSString *)param; 

@end

@interface AceResourceRegisterOC : NSObject

@property (nonatomic, assign) id<IAceOnCallEvent> parent;
@property (nonatomic, strong) IAceOnResourceEvent callbackHandler;

- (instancetype)initWithParent:(id<IAceOnCallEvent>)parent;

- (void)registerCallMethod:(NSString *)methodId
                callMethod:(IAceOnCallResourceMethod)callMethod;

- (void)unregisterCallMethod:(NSString *)methodId;


// show time
- (void)registerPlugin:(AceResourcePlugin *)plugin;

- (int64_t)createResource:(NSString *)resourceType
                    param:(NSString *)param;

- (id)getObject:(NSString *)resourceHash;

- (id)getObject:(NSString *)resourceType incId:(int64_t)incId;

- (NSString *)onCallMethod:(NSString *)methodId param:(NSString *)param;

- (BOOL)releaseObject:(NSString *)resourceHash;

@end

NS_ASSUME_NONNULL_END
