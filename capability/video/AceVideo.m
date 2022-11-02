/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "AceVideo.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

#define VIDEO_FLAG      @"video@"
#define PARAM_AND       @"#HWJS-&-#"
#define PARAM_EQUALS    @"#HWJS-=-#"
#define PARAM_BEGIN     @"#HWJS-?-#"
#define METHOD          @"method"
#define EVENT           @"event"

#define SUCCESS         @"success"
#define FAIL            @"fail"
#define KEY_SOURCE      @"src"
#define KEY_VALUE       @"value"
#define FILE_SCHEME     @"file://"
#define HAP_SCHEME      @"/"
#define SECOND_TO_MSEC  (1000)

@interface AceVideo()<AceTextureDelegate>

@property (nonatomic, assign) int64_t incId;
@property (nonatomic, copy) IAceOnResourceEvent onEvent;
@property (nonatomic, assign) BOOL isAutoPlay;
@property (nonatomic, assign) BOOL isMute;
@property (nonatomic, assign) BOOL isLoop;
@property (nonatomic, assign) float speed;
@property (nonatomic, strong) NSURL *url;

@property (nonatomic, weak) NSString *bundleDirectory;
@property (nonatomic, strong) NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *callSyncMethodMap;

@property (nonatomic, strong) AVPlayer *player_;
@property (nonatomic, strong) AVPlayerItem *playerItem_;
@property (nonatomic, strong) AVPlayerItemVideoOutput *videoOutput_;

@property (nonatomic, strong) AceTexture *renderTexture;
@property (nonatomic, strong) CADisplayLink *displayLink;

@end

@implementation AceVideo
- (instancetype)init:(int64_t)incId bundleDirectory:(NSString*)bundleDirectory onEvent:(IAceOnResourceEvent)callback texture:(AceTexture *)texture{
    if (self = [super init]) {
        self.incId = incId;
        self.onEvent = callback;
        self.renderTexture = texture;
        self.renderTexture.delegate = self;
        self.bundleDirectory = bundleDirectory;
        
        self.speed = 1.0f;
        self.isMute = false;
        self.isAutoPlay = false;
        self.isLoop = false;
        
        // init callback
        NSMutableDictionary *callSyncMethodMap = [NSMutableDictionary dictionary];
        NSString *init_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"init", PARAM_BEGIN];
        IAceOnCallSyncResourceMethod init_callback = ^NSString *(NSDictionary * param){
            return [self initMediaPlayer:param] ? SUCCESS : FAIL;
        };
        [callSyncMethodMap setObject:init_callback forKey:init_method_hash];

        // start callback
        IAceOnCallSyncResourceMethod start_callback = ^NSString *(NSDictionary * param){
            [self startPlay];
            return SUCCESS;
        };

        NSString *start_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"start", PARAM_BEGIN];
        [callSyncMethodMap setObject:start_callback forKey:start_method_hash];

        // pause callback
        NSString *pause_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"pause", PARAM_BEGIN];
        IAceOnCallSyncResourceMethod pause_callback = ^NSString *(NSDictionary * param){
            [self pause:true];
            return SUCCESS;
        };
        [callSyncMethodMap setObject:pause_callback forKey:pause_method_hash];

        // getposition callback
        NSString *getposition_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"getposition", PARAM_BEGIN];
        IAceOnCallSyncResourceMethod getposition_callback = ^NSString *(NSDictionary * param){
            int64_t position = [self getPosition];
            [self fireCallback:@"ongetcurrenttime" params:[NSString stringWithFormat:@"currentpos=%lld", position]];
            return [NSString stringWithFormat:@"%@%lld",@"currentpos=", position];
        };
        
        [callSyncMethodMap setObject:getposition_callback forKey:getposition_method_hash];

        // seekto callback
        NSString *seekto_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"seekto", PARAM_BEGIN];
        IAceOnCallSyncResourceMethod seekto_callback = ^NSString *(NSDictionary * param){
            if (!param) {
                return FAIL;
            }
            int64_t msec = [[param objectForKey:KEY_VALUE] longLongValue];
            CMTime time = CMTimeMake(msec, 1);
            [self seekTo:time];
            return SUCCESS;
        };
        [callSyncMethodMap setObject:seekto_callback forKey:seekto_method_hash];

        // setvolume callback
        NSString *setvolume_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"setvolume", PARAM_BEGIN];
        IAceOnCallSyncResourceMethod setvolume_callback = ^NSString *(NSDictionary * param){
            if (!param) {
                return FAIL;
            }
            
            float volumn = [[param objectForKey:KEY_VALUE] floatValue];
            [self setVolume:volumn];
            return SUCCESS;
        };
        [callSyncMethodMap setObject:setvolume_callback forKey:setvolume_method_hash];

        // enablelooping callback
        NSString *enablelooping_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"enablelooping", PARAM_BEGIN];
        IAceOnCallSyncResourceMethod enablelooping_callback = ^NSString *(NSDictionary * param){
            if (!param) {
                return FAIL;
            }
            
            BOOL loop = [[param objectForKey:@"loop"] boolValue];
            [self enableLooping:loop];
            return SUCCESS;
        };
        [callSyncMethodMap setObject:enablelooping_callback forKey:enablelooping_method_hash];

        // setspeed callback
        NSString *setspeed_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"setspeed", PARAM_BEGIN];
        IAceOnCallSyncResourceMethod setspeed_callback = ^NSString *(NSDictionary * param){
            if (!param) {
                return FAIL;
            }
            
            float speed = [[param objectForKey:KEY_VALUE] floatValue];
            self.speed = speed;
            return SUCCESS;
        };
        [callSyncMethodMap setObject:setspeed_callback forKey:setspeed_method_hash];

        // setdirection callback
        NSString *setdirection_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"setdirection", PARAM_BEGIN];
        IAceOnCallSyncResourceMethod setdirection_callback = ^NSString *(NSDictionary * param){
            return SUCCESS;
        };
        [callSyncMethodMap setObject:setdirection_callback forKey:setdirection_method_hash];

        // start callback
        NSString *setlandscape_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"setlandscape", PARAM_BEGIN];
        IAceOnCallSyncResourceMethod setlandscape_callback = ^NSString *(NSDictionary * param){
            return SUCCESS;
        };
        [callSyncMethodMap setObject:setlandscape_callback forKey:setlandscape_method_hash];

        self.callSyncMethodMap = callSyncMethodMap.copy;
    }
    
    return self;
}

- (NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *)getSyncCallMethod{
    return self.callSyncMethodMap;
}

- (void)dealloc
{
    if (_displayLink) {
        _displayLink.paused = YES;
        _displayLink = nil;
    }
}

- (void)releaseObject{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.displayLink invalidate];
    self.displayLink = nil;
    [self.player_ pause];
    self.player_ = nil;
    self.callSyncMethodMap = nil;
}

- (void)startPlay{
    if (self.player_) {
        CMTime currentTime = self.player_.currentTime;
        CMTime time = CMTimeMake(currentTime.value / currentTime.timescale, 1);
        [self seekTo:time];
        [self.player_ play];
        NSString *param = [NSString stringWithFormat:@"isplaying=%d", 1];
        [self fireCallback:@"onplaystatus" params:param];
    }
}

- (void)pause:(BOOL)isMute{
    if (self.player_) {
        [self.player_ pause];
        NSString *param = [NSString stringWithFormat:@"isplaying=%d", 0];
        [self fireCallback:@"onplaystatus" params:param];
    }
}

- (void)seekTo:(CMTime)time{
    if (self.player_) {
        [self.player_ seekToTime:time];
    }
    NSString *param = [NSString stringWithFormat:@"currentpos=%f", (float)time.value];
    [self fireCallback:@"seekcomplete" params:param];
}

- (int64_t)getPosition{
    if (self.player_) {
        CMTime time = self.player_.currentTime;
        return time.value / time.timescale;
    }
    
    return 0;
}

- (void)setVolume:(float)volume{
    if (self.player_) {
        [self.player_ setVolume:volume];
    }
}

- (void)enableLooping:(BOOL)enable{
    if (self.player_) {
        self.isLoop = enable;
    }
}

- (void)setSpeed:(float)speed{
    _speed = speed;
    if (self.player_) {
        AVPlayerTimeControlStatus status = self.player_.timeControlStatus;
        if (status == AVPlayerTimeControlStatusPlaying) {
            [self.player_ setRate:speed];
        }else if(self.isAutoPlay){
            [self.player_ setRate:speed];
        }
    }
}

- (BOOL)initMediaPlayer:(NSDictionary * )param {
    
    NSString *src = [param objectForKey:@"src"];
    if (![src isKindOfClass:[NSString class]] || src.length == 0 || [src isKindOfClass:[NSNull class]]) {
        return NO;
    }

    src = [src stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url_ = [NSURL URLWithString:src];
    if (url_.scheme == nil || url_.scheme.length == 0) {
        self.url = [NSURL fileURLWithPath:[self.bundleDirectory stringByAppendingPathComponent:src]];
    } else {
        self.url = [NSURL URLWithString:src];
    }
    
    if (!self.url) {
        return NO;
    }
    
    self.isAutoPlay = [[param objectForKey:@"autoplay"] boolValue];
    self.isMute = [[param objectForKey:@"mute"] boolValue];
    self.isLoop = [[param objectForKey:@"loop"] boolValue];

    self.playerItem_ = [[AVPlayerItem alloc] initWithURL:self.url];
    self.player_ = [[AVPlayer alloc] initWithPlayerItem:self.playerItem_];

    [self.player_ setMuted:self.isMute];
    
    NSDictionary* pixBuffAttributes = @{
        (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
        (id)kCVPixelBufferIOSurfacePropertiesKey : @{}
    };
    self.videoOutput_ = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];

    [self.playerItem_ addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [self.playerItem_ addObserver:self forKeyPath:@"loadedTimeRanges"options:NSKeyValueObservingOptionNew context:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playDidEndNotification:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];

    return YES;
}

- (CVPixelBufferRef _Nullable)getPixelBuffer{
    CMTime outputItemTime = [self.videoOutput_ itemTimeForHostTime:CACurrentMediaTime()];
    if ([self.videoOutput_ hasNewPixelBufferForItemTime:outputItemTime]) {
        return [self.videoOutput_ copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
    } else {
        return NULL;
    }
}

- (void)playDidEndNotification:(NSNotification *)notification{
    if (self.player_ && self.isLoop) {
        CMTime time = CMTimeMake(0, 1);
        [self seekTo:time];
        [self startPlay];
    } else {
        [self fireCallback:@"completion" params:@""];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    AVPlayerItem *playerItem = object;
    if([keyPath isEqualToString:@"loadedTimeRanges"]) {
        NSArray *loadedTimeRanges = [[self.player_ currentItem] loadedTimeRanges];
        CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
        float startSeconds = CMTimeGetSeconds(timeRange.start);
        float durationSeconds = CMTimeGetSeconds(timeRange.duration);
        NSTimeInterval timeInterval = startSeconds + durationSeconds;// 计算缓冲总进度
        CMTime duration = playerItem.duration;
        CGFloat totalDuration = CMTimeGetSeconds(duration);
        if (isnan(timeInterval)) {
            timeInterval = 0;
        }
        if (isnan(totalDuration)) {
            totalDuration = 0;
        }
        if (totalDuration > 0) {
            CGFloat percent = timeInterval / totalDuration;
            NSString *param = [NSString stringWithFormat:@"percent=%f", percent];
            [self fireCallback:@"bufferingupdate" params:param];
        }
    } else if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItemStatus status = self.playerItem_.status;
        switch (status) {
            case AVPlayerItemStatusFailed:{
                NSLog(@"AVPlayerItemStatusFailed");
                [self fireCallback:@"error" params:@""];
            } break;
            case AVPlayerItemStatusReadyToPlay:
            {
                CGSize size = [self.player_ currentItem].presentationSize;
                float width = size.width;
                float height = size.height;
                
                if (height == CGSizeZero.height && width == CGSizeZero.width) {
                    return;
                }
                
                int64_t duration = FLTCMTimeToMillis([[self.player_ currentItem] duration]);
                if (duration == 0) {
                    return;
                }
                
                AVPlayerItem* item = (AVPlayerItem*)object;
                [item addOutput:self.videoOutput_];

                [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
                
                int isPlaying = (self.player_.timeControlStatus == AVPlayerTimeControlStatusPlaying || self.isAutoPlay) ? 1 : 0;
                NSString *param = [NSString stringWithFormat:@"width=%f&height=%f&duration=%lld&isplaying=%d&needRefreshForce=%d", width, height, duration, isPlaying, 1];
                [self fireCallback:@"prepared" params:param];
            }
                break;
            default:
                break;
        }
    }
}

- (CADisplayLink *)displayLink{
    if (!_displayLink) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkDidrefresh)];
    }
    return _displayLink;
}

- (void)displayLinkDidrefresh{
    [self.renderTexture markTextureFrameAvailable];
}

#pragma mark - fireCallback

- (void)fireCallback:(NSString *)method params:(NSString *)params
{
    NSString *method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, EVENT, PARAM_EQUALS, method, PARAM_BEGIN];
    if (self.onEvent) {
        self.onEvent(method_hash, params);
    }
}

const int64_t TIME_UNSET = -9223372036854775807;
static inline int64_t FLTCMTimeToMillis(CMTime time) {
    // When CMTIME_IS_INDEFINITE return a value that matches TIME_UNSET from ExoPlayer2 on Android.
    // Fixes https://github.com/flutter/flutter/issues/48670
    if (CMTIME_IS_INDEFINITE(time)) return TIME_UNSET;
    if (time.timescale == 0) return 0;
    return time.value * 1000 / time.timescale;
}

@end
