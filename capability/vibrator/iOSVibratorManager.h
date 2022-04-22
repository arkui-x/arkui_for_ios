//
//  iOSVibratorManager.h
//  sources
//
//  Created by vail 王军平 on 2022/3/17.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface iOSVibratorManager : NSObject

+(instancetype)shareintance;
@property(nonatomic,assign) NSInteger duration;
-(void)addVibrate:(NSInteger)duration;
-(void)addVibrateSingle;

@end

NS_ASSUME_NONNULL_END
