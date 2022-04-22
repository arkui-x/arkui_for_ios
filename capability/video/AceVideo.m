//
//  AceVideo.m
//  sources
//
//  Created by wuhuanlong 吴焕隆 on 2022/3/24.
//

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

@property(nonatomic, assign) int64_t incId;
@property(nonatomic, copy) IAceOnResourceEvent onEvent;
@property(nonatomic, assign) BOOL isAutoPlay;
@property(nonatomic, assign) BOOL isMute;
@property(nonatomic, strong) NSString *url;
@property(nonatomic, assign) float speed;

@property(nonatomic, strong) NSDictionary<NSString *, IAceOnCallResourceMethod> *callMethodMap;


@property (nonatomic, strong) AVPlayer *player_;
@property (nonatomic, strong) AVPlayerItem *playerItem_;
@property (nonatomic, strong) AVPlayerItemVideoOutput *videoOutput_;

@property (nonatomic, strong) AceTexture *renderTexture;

@property (nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation AceVideo
- (instancetype)init:(int64_t)incId onEvent:(IAceOnResourceEvent)callback texture:(AceTexture *)texture{
    if (self = [super init]) {
        self.incId = incId;
        self.onEvent = callback;
        self.renderTexture = texture;
        self.renderTexture.delegate = self;
        
        self.speed = 1.0f;
        self.isMute = false;
        self.isAutoPlay = false;

        // init callback
        NSMutableDictionary *callMethodMap = [NSMutableDictionary dictionary];
        NSString *init_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"init", PARAM_BEGIN];
        NSLog(@"vailcamera->AceVideo init init_method_hash:%@",init_method_hash);
        IAceOnCallResourceMethod init_callback = ^NSString *(NSDictionary * param){
            return [self initMideaPlayer:param] ? SUCCESS : FAIL;
        };
        [callMethodMap setObject:init_callback forKey:init_method_hash];


        // start callback
        IAceOnCallResourceMethod start_callback = ^NSString *(NSDictionary * param){
            [self startPlay];
            return SUCCESS;
        };

        NSString *start_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"start", PARAM_BEGIN];
        [callMethodMap setObject:start_callback forKey:start_method_hash];


        // pause callback
        NSString *pause_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"pause", PARAM_BEGIN];
        IAceOnCallResourceMethod pause_callback = ^NSString *(NSDictionary * param){
            [self pause:true];
            return SUCCESS;
        };
        [callMethodMap setObject:pause_callback forKey:pause_method_hash];


        // getposition callback
        NSString *getposition_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"getposition", PARAM_BEGIN];
        IAceOnCallResourceMethod getposition_callback = ^NSString *(NSDictionary * param){
            int64_t position = [self getPosition];
            return [NSString stringWithFormat:@"%@%lld",@"currentpos=", position];
        };
        
        [callMethodMap setObject:getposition_callback forKey:getposition_method_hash];


        // seekto callback
        NSString *seekto_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"seekto", PARAM_BEGIN];
        IAceOnCallResourceMethod seekto_callback = ^NSString *(NSDictionary * param){
            if (!param) {
                return FAIL;
            }
            
            int64_t msec = [[param objectForKey:KEY_VALUE] longLongValue];
            CMTime time = CMTimeMake(msec, 1);
            [self seekTo:time];
            return SUCCESS;
        };
        [callMethodMap setObject:seekto_callback forKey:seekto_method_hash];


        // setvolume callback
        NSString *setvolume_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"setvolume", PARAM_BEGIN];
        IAceOnCallResourceMethod setvolume_callback = ^NSString *(NSDictionary * param){
            if (!param) {
                return FAIL;
            }
            
            float volumn = [[param objectForKey:KEY_VALUE] floatValue];
            [self setVolume:volumn];
            return SUCCESS;
        };
        [callMethodMap setObject:setvolume_callback forKey:setvolume_method_hash];


        // enablelooping callback
        NSString *enablelooping_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"enablelooping", PARAM_BEGIN];
        IAceOnCallResourceMethod enablelooping_callback = ^NSString *(NSDictionary * param){
            if (!param) {
                return FAIL;
            }
            
            BOOL loop = [[param objectForKey:@"loop"] boolValue];
            [self enableLooping:loop];
            return SUCCESS;
        };
        [callMethodMap setObject:enablelooping_callback forKey:enablelooping_method_hash];


        // setspeed callback
        NSString *setspeed_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"setspeed", PARAM_BEGIN];
        IAceOnCallResourceMethod setspeed_callback = ^NSString *(NSDictionary * param){
            if (!param) {
                return FAIL;
            }
            
            float speed = [[param objectForKey:KEY_VALUE] floatValue];
            self.speed = speed;
            return SUCCESS;
        };
        [callMethodMap setObject:setspeed_callback forKey:setspeed_method_hash];


        // setdirection callback
        NSString *setdirection_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"setdirection", PARAM_BEGIN];
        IAceOnCallResourceMethod setdirection_callback = ^NSString *(NSDictionary * param){
            return SUCCESS;
        };
        [callMethodMap setObject:setdirection_callback forKey:setdirection_method_hash];


        // start callback
        NSString *setlandscape_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, METHOD, PARAM_EQUALS, @"setlandscape", PARAM_BEGIN];
        IAceOnCallResourceMethod setlandscape_callback = ^NSString *(NSDictionary * param){
            return SUCCESS;
        };
        [callMethodMap setObject:setlandscape_callback forKey:setlandscape_method_hash];

        
        self.callMethodMap = callMethodMap.copy;
    }
    
    return self;
}

- (NSDictionary<NSString *, IAceOnCallResourceMethod> *)getCallMethod{
    return self.callMethodMap;
}

- (void)releaseObject{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.displayLink invalidate];
    self.displayLink = nil;
    [self.player_ pause];
    self.player_ = nil;
}


- (void)startPlay{
    if (self.player_) {
        NSLog(@"%f", self.speed);
        [self.player_ setRate:self.speed];
    }
}

- (void)pause:(BOOL)isMute{
    if (self.player_) {
        [self.player_ pause];
    }
}

- (void)seekTo:(CMTime)time{
    if (self.player_) {
        [self.player_ seekToTime:time];
    }
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
        self.isAutoPlay = enable;
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


- (BOOL)initMideaPlayer:(NSDictionary * )param {
    
    NSString *src = [param objectForKey:@"src"];
    if (![src isKindOfClass:[NSString class]] || src.length == 0 || [src isKindOfClass:[NSNull class]]) {
        return NO;
    }

    self.url = [src stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    if (!self.url || self.url.length == 0) {
        return NO;
    }
    
    self.isAutoPlay = [[param objectForKey:@"autoplay"] boolValue];
    self.isMute = [[param objectForKey:@"mute"] boolValue];
    
    NSURL *assetUrl = [NSURL URLWithString:self.url];
    if (!assetUrl) {
        return NO;
    }
    
    self.playerItem_ = [[AVPlayerItem alloc] initWithURL:assetUrl];
    self.player_ = [[AVPlayer alloc] initWithPlayerItem:self.playerItem_];

    [self.player_ setMuted:self.isMute];
    
    NSDictionary* pixBuffAttributes = @{
      (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
      (id)kCVPixelBufferIOSurfacePropertiesKey : @{}
    };
    self.videoOutput_ = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];

    [self.playerItem_ addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    
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
    if (self.player_ && self.isAutoPlay) {
        [self.player_ seekToTime:kCMTimeZero];
        [self startPlay];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItemStatus status = self.playerItem_.status;
        switch (status) {
            case AVPlayerItemStatusFailed:{
                NSLog(@"AVPlayerItemStatusFailed");
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
                NSString *prepared_method_hash = [NSString stringWithFormat:@"%@%lld%@%@%@%@", VIDEO_FLAG, self.incId, EVENT, PARAM_EQUALS, @"prepared", PARAM_BEGIN];
                
                self.onEvent(prepared_method_hash, param);
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

const int64_t TIME_UNSET = -9223372036854775807;
static inline int64_t FLTCMTimeToMillis(CMTime time) {
  // When CMTIME_IS_INDEFINITE return a value that matches TIME_UNSET from ExoPlayer2 on Android.
  // Fixes https://github.com/flutter/flutter/issues/48670
  if (CMTIME_IS_INDEFINITE(time)) return TIME_UNSET;
  if (time.timescale == 0) return 0;
  return time.value * 1000 / time.timescale;
}

@end
