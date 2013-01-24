//
//  BTAudioPlayer.h
//  BTAudioQPlayer
//
//  Created by Gary on 13-1-23.
//  Copyright (c) 2013年 Gary. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CMTime.h>

/*
 使用状态变量的时候应该注意，避免各状态所表述的内容有交叉，比如AS_STOPPING和AS_PLAYING，AS_STOPPING也是种播放ing的状态。AS_STARTING_FILE_THREAD其实也是AS_WAITING_FOR_DATA
 这样的状态设置将导致后续难以维护
 
 单纯从播放器的角度来看待状态，只需要有以下几种，（或者从用户可见（UI）的状态来看）,其他的内部状态不需要让用户知道
 stop: 初始和最终，都应该是这个状态。也有可能是因为某种错误而导致进入这个状态
 playing: 播放中，无需多解释
 paused: 暂停，这个只代表用户行为的暂停。当然播放器在播放的过程中，还有因为不能正常播放而显示出类似“暂停”的状态，统一归为waiting
 waiting: 进入这个状态有很多原因。一个主要的原因就是等待数据。
 
 */
enum {
	BTAudioPlayerStatusStop, //TODO: Or unknown
  BTAudioPlayerStatusReadyToPlay,
  BTAudioPlayerStatusWaiting,
  BTAudioPlayerStatusPlaying,
  BTAudioPlayerStatusPaused,
  BTAudioPlayerStatusFailed
};
typedef NSInteger BTAudioPlayerStatus;

@class BTPlayerItem;
@class BTAudioPlayerInternal;



@interface BTAudioPlayer : NSObject {
  //@private
  BTAudioPlayerInternal *_intenralPlayer;
}

+ (id)playerWithURL:(NSURL *)URL;
+ (id)playerWithPlayerItem:(BTPlayerItem *)item;
- (id)initWithURL:(NSURL *)URL;
- (id)initWithPlayerItem:(BTPlayerItem *)item;
@property (nonatomic, readonly) BTAudioPlayerStatus status;
@property (nonatomic, readonly) NSError *error;
@end

@interface BTAudioPlayer (BTAudioPlayerPlaybackControl)

/* indicates the current rate of playback; 0.0 means "stopped", 1.0 means "play at the natural rate of the current item" */
//@property (nonatomic) float rate;

/*!
 @method			play
 @abstract		Begins playback of the current item.
 @discussion		Same as setting rate to 1.0.
 */
- (void)play;

/*!
 @method			pause
 @abstract		Pauses playback.
 @discussion		Same as setting rate to 0.0.
 */
- (void)pause;

@end

@interface BTAudioPlayer (BTAudioPlayerItemControl)

/* indicates the current item of the player */
@property (nonatomic, readonly) BTPlayerItem *currentItem;


- (void)playWithPlayerItem:(BTPlayerItem *)item;


enum {
  BTPlayerActionAtItemEndPause    = 1U << 0,
  BTPlayerActionAtItemEndAdvance	= 1U << 1,
  BTPlayerActionAtItemEndRandom   = 1U << 2,
	BTPlayerActionAtItemEndLoop     = 1U << 3,  //Loop不能单独使用，需要与其他Action配合使用
  BTPlayerActionAtItemEndLoopOne  = BTPlayerActionAtItemEndLoop | BTPlayerActionAtItemEndPause,
  BTPlayerActionAtItemEndLoopAll  = BTPlayerActionAtItemEndLoop | BTPlayerActionAtItemEndAdvance,
};
typedef NSInteger BTPlayerActionAtItemEnd;

/* indicates the action that the player should perform when playback of an item reaches its end time */
@property (nonatomic) BTPlayerActionAtItemEnd actionAtItemEnd;

@end

@interface BTAudioPlayer (BTAudioPlayerTimeControl)

- (Float64)currentTime;
- (void)seekToTime:(Float64)time;

@end

//@interface BTAudioPlayer (BTAudioPlayerTimeObservation)
//- (id)addPeriodicTimeObserverForInterval:(CMTime)interval queue:(dispatch_queue_t)queue usingBlock:(void (^)(CMTime time))block;
//- (void)removeTimeObserver:(id)observer;
//@end

/**
@class BTAudioPlayerInternal;

NS_CLASS_AVAILABLE(10_7, 4_1)
@interface BTAudioQueuePlayer : BTAudioPlayer
{
@private
  BTAudioPlayerInternal   *_intenralPlayer;
}

+ (id)queuePlayerWithItems:(NSArray *)items;
- (id)initWithItems:(NSArray *)items;
- (NSArray *)items;
- (void)advanceToNextItem;
- (BOOL)canInsertItem:(BTPlayerItem *)item afterItem:(BTPlayerItem *)afterItem;
- (void)insertItem:(BTPlayerItem *)item afterItem:(BTPlayerItem *)afterItem;
- (void)removeItem:(BTPlayerItem *)item;
- (void)removeAllItems;

@end
*/
