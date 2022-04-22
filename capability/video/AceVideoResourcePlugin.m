//
//  AceVideoResourcePlugin.m
//  libAceDemo
//
//  Created by wuhuanlong 吴焕隆 on 2022/3/17.
//

#import "AceVideoResourcePlugin.h"
#import  "AceTexture.h"
#define KEY_TEXTURE @"texture"

@interface AceVideoResourcePlugin()

@property (nonatomic, strong) NSMutableDictionary<AceVideo *, NSString*> *objectMap;

@end

@implementation AceVideoResourcePlugin

- (instancetype)init{
    self = [super init:@"video" version:1];

    if (self) {
        self.objectMap = [NSMutableDictionary dictionary];
    }

    return self;
}

- (void)addResource:(int64_t)incId video:(AceVideo *)video{
    [self.objectMap setObject:video forKey:[NSString stringWithFormat:@"%lld", incId]];
    [self registerCallMethod:[video getCallMethod]];
}

- (int64_t)create:(NSDictionary<NSString *,NSString *> *)param{
    
    if (![param valueForKey:KEY_TEXTURE]) {
        return -1;
    }
    NSString *textureId = [param valueForKey:KEY_TEXTURE];
    id obj = [self.resRegister getObject:KEY_TEXTURE incId:textureId];
    if (obj == nil || ![obj isKindOfClass:[AceTexture class]]) {
        return -1;
    }
 
    int64_t incId = [self getAtomicId];
    AceTexture *texture = (AceTexture*)obj;
    AceVideo *aceVide = [[AceVideo alloc] init:incId onEvent:[self getEventCallback] texture:texture]; 
    [self addResource:incId video:aceVide];
    
    return incId;
}

- (id)getObject:(NSString *)incId{
    return [self.objectMap objectForKey:incId];
}

- (BOOL)release:(NSString *)incId {
    AceVideo *video = [self.objectMap objectForKey:incId];
    if (video) {
        [self unregisterCallMethod:[video getCallMethod]];
        [video releaseObject];
        [self.objectMap removeObjectForKey:incId];
        return YES;
    }
    return NO;
}

- (void)releaseObject{
    [self.objectMap enumerateKeysAndObjectsUsingBlock:^(AceVideo * _Nonnull video, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [video releaseObject];
    }];
    [self.objectMap removeAllObjects];
}

@end
