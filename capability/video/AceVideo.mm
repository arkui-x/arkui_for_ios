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
#import "AceSurfaceHolder.h"
#import "AceSurfaceView.h"
#import "StageAssetManager.h"

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

typedef enum : NSUInteger {
    IDLE,
    PREPARED,
    STARTED,
    PAUSED,
    STOPPED,
    PLAYBACK_COMPLETE
} PlayState;

@interface AceVideo()<AceTextureDelegate>

@property (nonatomic, assign) int64_t incId;
@property (nonatomic, assign) int32_t instanceId;
@property (nonatomic, assign) long surfaceId;

@property (nonatomic, copy) IAceOnResourceEvent onEvent;
@property (nonatomic, assign) BOOL isAutoPlay;
@property (nonatomic, assign) BOOL isMute;
@property (nonatomic, assign) BOOL isLoop;
@property (nonatomic, assign) float speed;
@property (nonatomic, strong) NSURL *url;

@property (nonatomic, copy) NSString *moudleName;
@property (nonatomic, strong) NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *callSyncMethodMap;

@property (nonatomic, strong) AVPlayer *player_;
@property (nonatomic, strong) AVPlayerItem *playerItem_;
@property (nonatomic, strong) AVPlayerItemVideoOutput *videoOutput_;

@property (nonatomic, strong) AceTexture *renderTexture;
@property (nonatomic, strong) CADisplayLink *displayLink;

@property (nonatomic, assign) BOOL stageMode;
@property (nonatomic, assign) BOOL backgroundPause;
@property (nonatomic, assign) PlayState state;
@end

@implementation AceVideo
- (instancetype)init:(int64_t)incId
    moudleName:(NSString*)moudleName
    onEvent:(IAceOnResourceEvent)callback 
    texture:(AceTexture *)texture
    abilityInstanceId:(int32_t)abilityInstanceId
{
    if (self = [super init]) {
        NSLog(@"AceVideo: init moudleName: %@  incId: %lld",moudleName,incId);
        self.incId = incId;
        self.instanceId = abilityInstanceId;
        self.onEvent = callback;
        self.state = IDLE;
        self.player_ = [[AVPlayer alloc] init];
        if (texture) {
            self.renderTexture = texture;
            self.stageMode = false;
        }else {
            self.stageMode = true;
        }
        self.renderTexture.delegate = self;
        self.moudleName = moudleName;
        
        self.speed = 1.0f;
        self.isMute = false;
        self.isAutoPlay = false;
        self.isLoop = false;

        [self initEventCallback];
    }
    
    return self;
}

- (void)initEventCallback
{
    // init callback
    NSMutableDictionary *callSyncMethodMap = [NSMutableDictionary dictionary];
    NSString *init_method_hash = [self method_hashFormat:@"init"];
    IAceOnCallSyncResourceMethod init_callback = ^NSString *(NSDictionary * param){
        return [self initMediaPlayer:param] ? SUCCESS : FAIL;
    };
    [callSyncMethodMap setObject:init_callback forKey:init_method_hash];

    // start callback
    IAceOnCallSyncResourceMethod start_callback = ^NSString *(NSDictionary * param){
        NSLog(@"AceVideo: startPlay");
        [self startPlay];
        return SUCCESS;
    };

    NSString *start_method_hash = [self method_hashFormat:@"start"];
    [callSyncMethodMap setObject:start_callback forKey:start_method_hash];

    // pause callback 
    NSString *pause_method_hash = [self method_hashFormat:@"pause"];
    IAceOnCallSyncResourceMethod pause_callback = ^NSString *(NSDictionary * param){
        NSLog(@"AceVideo: pause");
        [self pause];
        return SUCCESS;
    };
    [callSyncMethodMap setObject:pause_callback forKey:pause_method_hash];

    // stop callback
    NSString *stop_method_hash =  [self method_hashFormat:@"stop"];
    IAceOnCallSyncResourceMethod stop_callback = ^NSString *(NSDictionary * param){
        NSLog(@"AceVideo: stop");
        [self stop];
        return SUCCESS;
    };
    [callSyncMethodMap setObject:stop_callback forKey:stop_method_hash];

    // getposition callback 
    NSString *getposition_method_hash = [self method_hashFormat:@"getposition"];
    IAceOnCallSyncResourceMethod getposition_callback = ^NSString *(NSDictionary * param){
        NSLog(@"AceVideo: currentpos");
        int64_t position = [self getPosition];
        [self fireCallback:@"ongetcurrenttime" params:[NSString stringWithFormat:@"currentpos=%lld", position]];
        return [NSString stringWithFormat:@"%@%lld",@"currentpos=", position];
    };
    
    [callSyncMethodMap setObject:getposition_callback forKey:getposition_method_hash];

    // seekto callback 
    NSString *seekto_method_hash = [self method_hashFormat:@"seekto"];
    IAceOnCallSyncResourceMethod seekto_callback = ^NSString *(NSDictionary * param){
        if (!param) {
            return FAIL;
        }
        int64_t msec = [[param objectForKey:KEY_VALUE] longLongValue];
        CMTime time = CMTimeMake(msec/1000, 1);
        [self seekTo:time];
        return SUCCESS;
    };
    [callSyncMethodMap setObject:seekto_callback forKey:seekto_method_hash];

    // setvolume callback 
    NSString *setvolume_method_hash = [self method_hashFormat:@"setvolume"];
    IAceOnCallSyncResourceMethod setvolume_callback = ^NSString *(NSDictionary * param){
        NSLog(@"AceVideo: setVolume");
        if (!param) {
            return FAIL;
        }
        NSLog(@"%@",[param objectForKey:KEY_VALUE]);
        float volumn = [[param objectForKey:KEY_VALUE] floatValue];
        [self setVolume:volumn];
        return SUCCESS;
    };
    [callSyncMethodMap setObject:setvolume_callback forKey:setvolume_method_hash];

    // enablelooping callback
    NSString *enablelooping_method_hash = [self method_hashFormat:@"enablelooping"];
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
    NSString *setspeed_method_hash = [self method_hashFormat:@"setspeed"];
    IAceOnCallSyncResourceMethod setspeed_callback = ^NSString *(NSDictionary * param){
        NSLog(@"AceVideo: player_ setspeed %@",param);
        if (!param) {
            return FAIL;
        }
        
        float speed = [[param objectForKey:KEY_VALUE] floatValue];
        self.speed = speed;
        return SUCCESS;
    };
    [callSyncMethodMap setObject:setspeed_callback forKey:setspeed_method_hash];

    // setdirection callback 
    NSString *setdirection_method_hash = [self method_hashFormat:@"setdirection"];
    IAceOnCallSyncResourceMethod setdirection_callback = ^NSString *(NSDictionary * param){
        return SUCCESS;
    };
    [callSyncMethodMap setObject:setdirection_callback forKey:setdirection_method_hash];

    // start callback 
    NSString *setlandscape_method_hash = [self method_hashFormat:@"setlandscape"];
    IAceOnCallSyncResourceMethod setlandscape_callback = ^NSString *(NSDictionary * param){
        return SUCCESS;
    };
    [callSyncMethodMap setObject:setlandscape_callback forKey:setlandscape_method_hash];
    
    // setLayer callback 
    NSString *setsurface_method_hash = [self method_hashFormat:@"setsurface"];
    IAceOnCallSyncResourceMethod setsurface_callback = ^NSString *(NSDictionary * param){
        return [self setSuerface:param];
    };
    [callSyncMethodMap setObject:setsurface_callback forKey:setsurface_method_hash];

    // setupdateResource callback 
    NSString *updateResource_method_hash = [self method_hashFormat:@"updateresource"];
    IAceOnCallSyncResourceMethod setupdateResource_callback = ^NSString *(NSDictionary * param){
        return [self setUpdateResource:param];
    };
    [callSyncMethodMap setObject:setupdateResource_callback forKey:updateResource_method_hash];

    // setfullscreen callback
    NSString *fullscreen_method_hash = [self method_hashFormat:@"fullscreen"];
    IAceOnCallSyncResourceMethod setfullscreen_callback = ^NSString *(NSDictionary * param){
        return [self setFullscreen:param];
    };
    [callSyncMethodMap setObject:setfullscreen_callback forKey:fullscreen_method_hash];

    self.callSyncMethodMap = callSyncMethodMap;
}

- (NSDictionary<NSString *, IAceOnCallSyncResourceMethod> *)getSyncCallMethod
{
    return self.callSyncMethodMap;
}

- (void)dealloc
{
    [self releaseObject];
    NSLog(@"AceVideo->%@ dealloc", self);
}

- (void)releaseObject
{
    @try {
        NSLog(@"AceVideo releaseObject");
        if (self.playerItem_) {
            @try {
                [self.playerItem_ removeObserver:self forKeyPath:@"status"];
                [self.playerItem_ removeObserver:self forKeyPath:@"loadedTimeRanges"];
            } @catch (NSException *exception) {}
        }
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        if (_displayLink) {
            [self.displayLink invalidate];
            self.displayLink = nil;
        }
        if (self.player_) {
            if (self.player_.timeControlStatus == AVPlayerTimeControlStatusPlaying) {
                [self pause];
            }
            self.player_ = nil;
        }
        self.callSyncMethodMap = nil;
    } @catch (NSException* exception) {
        NSLog(@"AceVideo releaseObject failed");
    }

}

- (void)startPlay{
    NSLog(@"AceVideo: player_ startPlay");
    if (self.player_) {
        if (self.state == STOPPED) {
            [self updatePalyerItem];
        }else {
            CMTime currentTime = self.player_.currentTime;
            int64_t duration = FLTCMTimeToMillis([[self.player_ currentItem] duration]);
            if (currentTime.value == duration) {
                CMTime time = CMTimeMake(0, currentTime.timescale);
                [self.player_ seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
            }
        }
        [self showAvPlayerlayer];
        [self.player_ play];
        self.state = STARTED;

        if (self.player_.rate != self.speed) {
            self.speed = self.speed;
        }

        NSString *param = [NSString stringWithFormat:@"isplaying=%d", 1];
        [self fireCallback:@"onplaystatus" params:param];
    }
}

- (void)pause
{
    if (self.player_) {
        [self.player_ pause];
        self.state = PAUSED;
        NSString *param = [NSString stringWithFormat:@"isplaying=%d", 0];
        [self fireCallback:@"onplaystatus" params:param];
    }
}

- (void)stop
{
    if (self.player_) {
        [self.player_ pause];
        self.state = STOPPED;
    }
}

- (void)seekTo:(CMTime)time
{
    if (self.player_) {
        if (self.state == STOPPED) {
            [self setReset];
        }
        [self.player_ seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    }
    NSString *param = [NSString stringWithFormat:@"currentpos=%f", (float)time.value];
    [self fireCallback:@"seekcomplete" params:param];
}

- (int64_t)getPosition
{
    if (self.player_) {
        CMTime time = self.player_.currentTime;
        return time.value / time.timescale;
    }
    
    return 0;
}

- (void)setVolume:(float)volume
{
    if (self.player_) {
        [self.player_ setVolume:volume];
    }
}

- (void)enableLooping:(BOOL)enable
{
    if (self.player_) {
        self.isLoop = enable;
    }
}

- (void)setSpeed:(float)speed
{
    _speed = speed;
    if (self.player_) {
        AVPlayerTimeControlStatus status = self.player_.timeControlStatus;
        if (status == AVPlayerTimeControlStatusPlaying || self.isAutoPlay || self.state == STARTED) {
             NSLog(@"AceVideo: setspeed %f",speed);
            [self.player_ setRate:speed];
        }else {
            NSLog(@"AceVideo: If the speed is greater than 0, the video will start playing.  setspeed");
        }
    }
}

- (void)setReset
{
    [self resetPlayerToPrepare:self.player_.currentItem withIsSetAutoPlay:false];
}

- (void)setPrepare:(id)object
{
    [self resetPlayerToPrepare:object withIsSetAutoPlay:true];
}

- (NSString *)setSuerface:(NSDictionary *)params
{
    if (!params) {
        NSLog(@"AceVideo: setSurface failed: params is null");
        return FAIL;
    }
    if (!params[KEY_VALUE]) {
        NSLog(@"AceVideo: setSurface failed: value is illegal");
        return FAIL;
    }
    @try {
        self.surfaceId = [params[KEY_VALUE] longLongValue];
        NSLog(@"AceVideo: setSurface id:%ld", self.surfaceId);
        AVPlayerLayer * playerLayer = (AVPlayerLayer *)[AceSurfaceHolder getLayerWithId:self.surfaceId inceId:self.instanceId];
        if (playerLayer && self.player_) {
            NSLog(@"AceVideo: MediaPlayer SetSurface");
            playerLayer.player = self.player_;
        }
    } @catch (NSException *exception) {
        NSLog(@"AceVideo: IOException, setSuerface failed");
        return FAIL;
    }
    return SUCCESS;
}

/// ios Fix display order issues
- (void)showAvPlayerlayer
{
    if (self.surfaceId == 0) {
        return;
    }
    AVPlayerLayer * playerLayer = (AVPlayerLayer *)[AceSurfaceHolder getLayerWithId:self.surfaceId inceId:self.instanceId];
    if (playerLayer && playerLayer.isHidden) {
        playerLayer.hidden = false;
    }  
}

- (NSString *)setUpdateResource:(NSDictionary *)params
{
    NSLog(@"AceVideo: setUpdateResource");
    if (!params) {
        NSLog(@"AceVideo: updateResource failed: params is null");
        return FAIL;
    }
    @try {
        if (!params[KEY_SOURCE]) {
            return FAIL;
        }
        
        [self pause];
        
        NSString *src = [params objectForKey:KEY_SOURCE];
        if (![src isKindOfClass:[NSString class]] || src.length == 0 || [src isKindOfClass:[NSNull class]]) {
            NSLog(@"AceVideo: src param is null");
            return FAIL;
        }
        if(![self setDataSource:src]) {
            return FAIL;
        }
        
        if (!self.url) {
            return FAIL;
        }
        
        [self updatePalyerItem];
    } @catch (NSException *exception) {
        NSLog(@"AceVideo: IOException, setSuerface failed");
        return FAIL;
    }
    return SUCCESS;
}

- (BOOL)setDataSource:(NSString *)param
{
    NSLog(@"AceVideo: setDataSource param:%@",param);
    @try {
        param = [param stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSURL *url_ = [NSURL URLWithString:param];
        if (url_.scheme.length != 0 || ![url_.absoluteString hasPrefix:HAP_SCHEME]) {
            self.url = url_;
            return true;
        }
    
        NSString * bundlePath = [[StageAssetManager assetManager] getBundlePath];
        if (!bundlePath) {
            NSLog(@"AceVideo: setDataSource null assetManager");
            return false;
        }
        if (_stageMode) {
            @try {
               NSURL * filePath = [NSURL fileURLWithPathComponents:@[bundlePath,self.moudleName,@"ets",param]];
               NSLog(@"AceVideo: setDataSourc file hapPath:%@",filePath.absoluteString);
               self.url = filePath;
            } @catch (NSException *exception) {
                NSLog(@"AceVideo: not found asset in instance path, now begin to search asset in share path");
            }
        } else {
            @try {
                NSURL * filePath = self.url = [NSURL fileURLWithPath:[bundlePath stringByAppendingPathComponent:param]];;
                self.url = filePath;
            } @catch (NSException *exception) {
                NSLog(@"AceVideo: not found asset in instance path, now begin to search asset in share path");
            }
        }
        
    }
    @catch (NSException *exception) {
        NSLog(@"AceVideo: IOException, setDataSource failed");
        return false;
    }
    
    return true;
}

- (NSString *)setFullscreen:(NSDictionary *)param
{
    NSLog(@"AceVideo: setFullscreen param: %@",param);
    if (!param[KEY_VALUE]) {
        NSLog(@"AceVideo: setFullscreen failed: value is illegal");
        return FAIL;
    }
    if (self.surfaceId == 0) {
        return FAIL;
    }
    BOOL isFullScreen = [[param objectForKey:KEY_VALUE] boolValue];
    if (isFullScreen) {
        AVPlayerLayer * playerLayer = (AVPlayerLayer *)[AceSurfaceHolder getLayerWithId:self.surfaceId inceId:self.instanceId];
        CALayer *superLayer = playerLayer.superlayer; 
        AceSurfaceView * surfaceView = (AceSurfaceView *)superLayer ? superLayer.delegate : nil;
        if (surfaceView) {
            [surfaceView bringSubviewToFront];
        }
    }
    return SUCCESS;
}

- (BOOL)initMediaPlayer:(NSDictionary *)param
{
    NSLog(@"AceVideo: initMediaPlayer param: %@",param);
    if (!param[KEY_SOURCE]) {
        return NO;
    }
    
    NSString *src = [param objectForKey:KEY_SOURCE];
    if (![src isKindOfClass:[NSString class]] || src.length == 0 || [src isKindOfClass:[NSNull class]]) {
        NSLog(@"AceVideo: src param is null");
        return NO;
    }
    if(![self setDataSource:src]) {
        return NO;
    }
    
    if (!self.url) {
        return NO;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playDidEndNotification:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    self.isAutoPlay = [[param objectForKey:@"autoplay"] boolValue];
    self.isMute = [[param objectForKey:@"mute"] boolValue];
    self.isLoop = [[param objectForKey:@"loop"] boolValue];

    AVPlayerItem * playerItem = [[AVPlayerItem alloc] initWithURL:self.url];
    [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    
    if (self.player_) {
        [self.player_ replaceCurrentItemWithPlayerItem:playerItem];
    }else {
        self.player_ = [[AVPlayer alloc] initWithPlayerItem:playerItem];
    }
   
    [self.player_ setMuted:self.isMute];

    
    if (!_stageMode) {
        NSDictionary* pixBuffAttributes = @{
            (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
            (id)kCVPixelBufferIOSurfacePropertiesKey : @{}
        };
        self.videoOutput_ = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
    }

    self.playerItem_ = playerItem;
    return YES;
}

- (void)updatePalyerItem
{
    @try {
        AVPlayerItem * playerItem = [[AVPlayerItem alloc] initWithURL:self.url];
        
        NSLog(@"%@",self.player_.currentItem);
        if (self.player_.currentItem) {
            [self.player_.currentItem removeObserver:self forKeyPath:@"status"];
            [self.player_.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
        }
        [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
        [playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
        
        [self.player_ replaceCurrentItemWithPlayerItem:playerItem];
        self.playerItem_ = playerItem;
    } @catch (NSException *exception) {
        NSLog(@"AceVideo: playerItem create failed");
    }
  
}

- (CVPixelBufferRef _Nullable)getPixelBuffer
{
    CMTime outputItemTime = [self.videoOutput_ itemTimeForHostTime:CACurrentMediaTime()];
    if ([self.videoOutput_ hasNewPixelBufferForItemTime:outputItemTime]) {
        return [self.videoOutput_ copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
    } else {
        return NULL;
    }
}

- (void)playDidEndNotification:(NSNotification *)notification
{
    NSLog(@"AceVideo: player_ finish");
    if (self.player_ && self.isLoop) {
        CMTime time = CMTimeMake(0, 1);
        [self seekTo:time];
        [self startPlay];
    } else {
        self.state = PLAYBACK_COMPLETE;
        [self fireCallback:@"completion" params:@""];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object 
    change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    AVPlayerItem *playerItem = object;
    if([keyPath isEqualToString:@"loadedTimeRanges"]) {
        if (self.player_ && self.player_.currentItem) {
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
                NSLog(@"AceVideo: player_ totalDuration param %@",param);
                [self fireCallback:@"bufferingupdate" params:param];
            }
        }   
    } else if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItemStatus status = self.playerItem_.status;
        switch (status) {
            case AVPlayerItemStatusFailed:{
                NSLog(@"AceVideo: AVPlayerItemStatusFailed");
                [self fireCallback:@"error" params:@""];
            } break;
            case AVPlayerItemStatusReadyToPlay:
            {
                [self setPrepare:object];
            }
                break;
            default:
                break;
        }
    }
}

- (CADisplayLink *)displayLink
{
    if (!_displayLink) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkDidrefresh)];
    }
    return _displayLink;
}

- (void)displayLinkDidrefresh
{
    [self.renderTexture markTextureFrameAvailable];
}

- (void)onActivityResume
{
    if (self.player_ && self.backgroundPause && self.state == PAUSED) {
        [self startPlay];
        self.backgroundPause = false;
    }   
}

- (void)onActivityPause
{
    if (self.player_ && self.player_.timeControlStatus == AVPlayerTimeControlStatusPlaying) {
        [self pause];
        self.backgroundPause = true;
    }
}

- (void)resetPlayerToPrepare:(id)object withIsSetAutoPlay:(BOOL)setAutoPlay
{
    if (self.player_ && self.player_.currentItem) {
        self.state = PREPARED;
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
        if (!_stageMode) {
            AVPlayerItem* item = (AVPlayerItem*)object;
            [item addOutput:self.videoOutput_];
            [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        }
        if (self.isAutoPlay && setAutoPlay) {
            [self startPlay];
        }

        int isPlaying = (self.player_.timeControlStatus == AVPlayerTimeControlStatusPlaying || self.isAutoPlay) ? 1 : 0;
        NSString *param = [NSString stringWithFormat:@"width=%f&height=%f&duration=%lld&isplaying=%d&needRefreshForce=%d", width, height, duration, isPlaying, 1];
        [self fireCallback:@"prepared" params:param];
    }   
}

- (NSString *)method_hashFormat:(NSString *)method
{
    return [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, method, PARAM_BEGIN];
}

- (void)fireCallback:(NSString *)method params:(NSString *)params
{
    NSString *method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, 
        self.incId, EVENT, PARAM_EQUALS, method, PARAM_BEGIN];
    if (self.onEvent) {
        self.onEvent(method_hash, params);
    }
}

const int64_t TIME_UNSET = -9223372036854775807;
static inline int64_t FLTCMTimeToMillis(CMTime time)
{
    // When CMTIME_IS_INDEFINITE return a value that matches TIME_UNSET from ExoPlayer2 on Android.
    // Fixes https://github.com/flutter/flutter/issues/48670
    if (CMTIME_IS_INDEFINITE(time)) return TIME_UNSET;
    if (time.timescale == 0) return 0;
    return time.value * 1000 / time.timescale;
}

@end
