//
//  AceTexture.h
//  sources
//
//  Created by wuhuanlong 吴焕隆 on 2022/3/24.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

#import "IAceOnCallResourceMethod.h"
#import "IAceOnResourceEvent.h"
#import "FlutterTexture.h"

NS_ASSUME_NONNULL_BEGIN

@protocol AceTextureDelegate <NSObject>
- (CVPixelBufferRef _Nullable)getPixelBuffer;
@end

@interface AceTexture : NSObject

@property(nonatomic, assign) int64_t incId;
@property(nonatomic,weak)id<AceTextureDelegate>delegate;
- (instancetype)initWithRegister:(NSObject<FlutterTextureRegistry> *)textures onEvent:(IAceOnResourceEvent)callback;
- (void)markTextureFrameAvailable;
- (void)releaseObject;

@end

NS_ASSUME_NONNULL_END
