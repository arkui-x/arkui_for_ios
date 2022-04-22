//
//  ace_resource_register_oc.m
//  libAceDemo
//
//  Created by wuhuanlong 吴焕隆 on 2022/3/17.
//

#import "AceResourceRegisterOC.h"

#define PARAM_AND @"#HWJS-&-#"
#define PARMA_EQUALS @"#HWJS-=-#"
#define PARAM_AT @"@"

@interface AceResourceRegisterOC () <AceResourceRegisterDelegate>

@property (nonatomic, strong) NSDictionary<NSString*, AceResourcePlugin *> *pluginMap;
@property (nonatomic, strong) NSDictionary<NSString*, IAceOnCallResourceMethod> *callMethodMap;

@end

@implementation AceResourceRegisterOC
- (instancetype)initWithParent:(id<IAceOnCallEvent>)parent{
    if (self = [super init]) {
        self.parent = parent;
        self.pluginMap = [NSDictionary new];
        self.callMethodMap = [NSDictionary new];
 
        __weak AceResourceRegisterOC *weakSelf = self;
        self.callbackHandler = ^(NSString* eventId, NSString* param){
            __strong AceResourceRegisterOC *strongSelf = weakSelf;
            [strongSelf.parent onEvent:eventId param:param];
        };
    }
    
    return self;
}

- (void)registerCallMethod:(NSString *)methodId
                callMethod:(IAceOnCallResourceMethod)callMethod {
    NSMutableDictionary *callMethodMap = [[NSMutableDictionary alloc]
                                          initWithDictionary:self.callMethodMap];
    [callMethodMap setObject:callMethod forKey:methodId];
    self.callMethodMap = callMethodMap.copy;
}

- (void)unregisterCallMethod:(NSString *)methodId {
     NSMutableDictionary *callMethodMap = [[NSMutableDictionary alloc]
                                           initWithDictionary:self.callMethodMap];
     [callMethodMap removeObjectForKey:methodId];
     self.callMethodMap = callMethodMap.copy;
}

// show time
- (void)registerPlugin:(AceResourcePlugin *)plugin{
    if (plugin == NULL) {
        return;
    }
    
    AceResourcePlugin *oldPlugin = [self.pluginMap objectForKey:plugin.tag];
    if (oldPlugin) {
        if (plugin.version <= oldPlugin.version) {
            return;
        }
    }
    
    NSMutableDictionary *pluginMap = [[NSMutableDictionary alloc] initWithDictionary:self.pluginMap];
    [pluginMap setObject:plugin forKey:plugin.tag];
    self.pluginMap = pluginMap.copy;
    [plugin setEventCallback:self.callbackHandler];
}

- (int64_t)createResource:(NSString *)resourceType param:(NSString *)param{
    NSLog(@"vailcamera->RegisterOC createResource:%@", resourceType);
    AceResourcePlugin *plugin = [self.pluginMap objectForKey:resourceType];
    if (plugin) {
        __weak __typeof(&*self) weakSelf = self;
        plugin.resRegister = weakSelf;
        return [plugin create:[self buildParamMap:param]];
    }
    return -1;
}

- (NSDictionary *)buildParamMap:(NSString *)param{
    NSMutableDictionary *paramMap = [NSMutableDictionary dictionary];
    
    NSArray<NSString *> *paramSplit = [param componentsSeparatedByString:PARAM_AND];
    [paramSplit enumerateObjectsUsingBlock:^(NSString * _Nonnull pa, NSUInteger idx, BOOL * _Nonnull stop) {
        NSArray<NSString *> *valueSplit = [pa componentsSeparatedByString:PARMA_EQUALS];
        if (valueSplit.count == 2) {
            [paramMap setObject:valueSplit[1] forKey:valueSplit[0]];
        }
    }];
    
    return paramMap.copy;
}

- (id)getObject:(NSString *)resourceHash{
    NSArray<NSString *> *split = [resourceHash componentsSeparatedByString:PARAM_AT];
    if (split.count == 2) {
        return [self getObject:split[0] incId:split[1]];
    }
    return nil;
}

- (id)getObject:(NSString *)resourceType incId:(NSString *)incId{
    AceResourcePlugin *plugin = [self.pluginMap objectForKey:resourceType];
    if (plugin) {
        return [plugin getObject:incId];
    }
    return nil;
}

- (NSString *)onCallMethod:(NSString *)methodId param:(NSString *)param{
    IAceOnCallResourceMethod resourceMethod = [self.callMethodMap objectForKey:methodId];
    if (resourceMethod) {
        return resourceMethod([self buildParamMap:param]);
    }

    return @"no method found";
} 

- (BOOL)releaseObject:(NSString *)resourceHash {
    NSArray <NSString *> *split = [resourceHash componentsSeparatedByString:PARAM_AT];
    if (split.count == 2) {
        AceResourcePlugin *plugin = [self.pluginMap objectForKey:split[0]];
        if (plugin) {
            [plugin release:[NSString stringWithFormat:@"%lld", [split[1] longLongValue]]];
        }
    }
    return NO;
}

@end
