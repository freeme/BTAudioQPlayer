//
//  BTAudioPlayer.m
//  BTAudioQPlayer
//
//  Created by Gary on 13-1-23.
//  Copyright (c) 2013年 Gary. All rights reserved.
//

#import "BTAudioPlayer.h"
#import "BTAudioPlayerInternal.h"


@implementation BTAudioPlayer


+ (id)playerWithURL:(NSURL *)URL {
  BTAudioPlayer *player = [[[BTAudioPlayer alloc] initWithURL:URL] autorelease];
  return player;
}
+ (id)playerWithPlayerItem:(BTPlayerItem *)item {
  BTAudioPlayer *player = [[[BTAudioPlayer alloc] initWithPlayerItem:item] autorelease];
  return player;
}
- (id)initWithURL:(NSURL *)URL {
  self = [super init];
  if (self) {
    _intenralPlayer = [[BTAudioPlayerInternal alloc] initWithURL:URL];
    _intenralPlayer.outsidePlayer = self;
  }
  return self;
}
- (id)initWithPlayerItem:(BTPlayerItem *)item {
  self = [super init];
  if (self) {
    _intenralPlayer = [[BTAudioPlayerInternal alloc] initWithPlayerItem:item];
    _intenralPlayer.outsidePlayer = self;
  }
  return self;
}

- (BTAudioPlayerStatus) status {
  return _intenralPlayer.status;
}

- (NSError*)error {
  return nil;
}

@end

@implementation BTAudioPlayer (BTAudioPlayerPlaybackControl)

/*!
 @method			play
 @abstract		Begins playback of the current item.
 @discussion		Same as setting rate to 1.0.
 */
- (void)play {
  
}

/*!
 @method			pause
 @abstract		Pauses playback.
 @discussion		Same as setting rate to 0.0.
 */
- (void)pause {
  
}

@end

@implementation BTAudioPlayer(BTAudioPlayerItemControl)

- (void)setActionAtItemEnd:(BTPlayerActionAtItemEnd)actionAtItemEnd {
  NSAssert(actionAtItemEnd == BTPlayerActionAtItemEndLoop, nil);
}

@end