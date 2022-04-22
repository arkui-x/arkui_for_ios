//
//  AceResourcePlugin.m
//  libAceDemo
//
//  Created by wuhuanlong 吴焕隆 on 2022/3/17.
//

#import "AceResourcePlugin.h"

@interface AceResourcePlugin()

@property (atomic, assign) int64_t nextVideoId;

@end

@implementation AceResourcePlugin

- (instancetype)init:(NSString *)tag version:(int64_t)version {
    if (self = [super init]) {
        self.tag = tag;
        self.version = version;
        self.nextVideoId = 0;
        self.resRegister = nil;
    }
    return self;
}

- (int64_t)getAtomicId{
    return ++self.nextVideoId;
}


 - (void)setEventCallback:(IAceOnResourceEvent)callback {
     self.callback = callback;
 }

- (IAceOnResourceEvent)getEventCallback{
    return self.callback;
}

- (void)registerCallMethod:(NSDictionary<NSString *, IAceOnCallResourceMethod> *)methodMap{
    if (self.resRegister == nil) {
        return;
    }
    
    [methodMap enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, IAceOnCallResourceMethod  _Nonnull callback, BOOL * _Nonnull stop) {
        [self.resRegister registerCallMethod:key callMethod:callback];
    }];
}

- (void)unregisterCallMethod:(NSString *)method{
    if (self.resRegister == nil) {
        return;
    }
    
    [self.resRegister unregisterCallMethod:method];
}

@end
