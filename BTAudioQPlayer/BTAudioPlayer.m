//
//  BTAudioPlayer.m
//  BTAudioQPlayer
//
//  Created by Gary on 13-1-23.
//  Copyright (c) 2013年 Gary. All rights reserved.
//

#import "BTAudioPlayer.h"
#import "BTAudioPlayerInternal.h"
#import "BTPlayerItem.h"

@implementation BTAudioPlayer
@synthesize status;

- (void) dealloc {
  [_intenralPlayer stop];
  [_intenralPlayer release];
  [super dealloc];
}

+ (id)playerWithURL:(NSURL *)URL {
  BTAudioPlayer *player = [[[BTAudioPlayer alloc] initWithURL:URL] autorelease];
  return player;
}
+ (id)playerWithPlayerItem:(BTPlayerItem *)item {
  BTAudioPlayer *player = [[[BTAudioPlayer alloc] initWithPlayerItem:item] autorelease];
  return player;
}

- (id)init {
  self = [super init];
  if (self) {
    _intenralPlayer = [[BTAudioPlayerInternal alloc] initWithAudioPlayer:self];
    [_intenralPlayer start];
  }
  return self;
}

- (id)initWithURL:(NSURL *)URL {
  self = [super init];
  if (self) {
    _intenralPlayer = [[BTAudioPlayerInternal alloc] initWithURL:URL audioPlayer:self];
    [_intenralPlayer start];
  }
  return self;
}
- (id)initWithPlayerItem:(BTPlayerItem *)item {
  self = [super init];
  if (self) {
    _intenralPlayer = [[BTAudioPlayerInternal alloc] initWithPlayerItem:item audioPlayer:self];
    [_intenralPlayer start];
  }
  return self;
}

//- (BTAudioPlayerStatus) status {
//  return _intenralPlayer.status;
//}

- (NSError*)error {
  return _intenralPlayer.error;
}

@end

@implementation BTAudioPlayer (BTAudioPlayerPlaybackControl)

/*!
 @method			play
 @abstract		Begins playback of the current item.
 @discussion		Same as setting rate to 1.0.
 */
- (void)play {
  [_intenralPlayer play];
}

/*!
 @method			pause
 @abstract		Pauses playback.
 @discussion		Same as setting rate to 0.0.
 */
- (BOOL)paused {
  NSAssert([NSThread isMainThread],nil);
	return _intenralPlayer.paused;
}

- (void)setPaused:(BOOL)paused {
  _intenralPlayer.paused = paused;
}

@end

@implementation BTAudioPlayer (BTAudioPlayerItemControl)


- (void)replaceCurrentItemWithPlayerItem:(BTPlayerItem *)item {
  
}

- (void)replaceCurrentItemWithURL:(NSURL*)url {
  [_intenralPlayer setURL:url];
}

- (void)setActionAtItemEnd:(BTPlayerActionAtItemEnd)actionAtItemEnd {
  NSAssert(actionAtItemEnd == BTPlayerActionAtItemEndLoop, nil);
}

- (BTPlayerActionAtItemEnd)actionAtItemEnd {
  return 0;
}

- (BTPlayerItem*)currentItem {
  return nil;
}

@end

@implementation BTAudioPlayer (BTAudioPlayerTimeControl)

- (Float64)currentTime {
  return 0;
}
- (void)seekToTime:(Float64)time {
  
}
- (Float64)playProgress {
  return [_intenralPlayer playProgress];
}
- (Float64)duration {
  return [_intenralPlayer duration];
}

- (Float64)downloadProgress {
  return [_intenralPlayer downloadProgress];
}
@end