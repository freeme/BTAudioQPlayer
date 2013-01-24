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
  }
  return self;
}

- (id)initWithURL:(NSURL *)URL {
  self = [super init];
  if (self) {
    _intenralPlayer = [[BTAudioPlayerInternal alloc] initWithURL:URL audioPlayer:self];
  }
  return self;
}
- (id)initWithPlayerItem:(BTPlayerItem *)item {
  self = [super init];
  if (self) {
    _intenralPlayer = [[BTAudioPlayerInternal alloc] initWithPlayerItem:item audioPlayer:self];
  }
  return self;
}

//- (BTAudioPlayerStatus) status {
//  return _intenralPlayer.status;
//}

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

@implementation BTAudioPlayer (BTAudioPlayerItemControl)


- (void)playWithPlayerItem:(BTPlayerItem *)item {
  
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