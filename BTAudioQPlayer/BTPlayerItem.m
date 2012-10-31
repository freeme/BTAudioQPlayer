//
//  BTPlayerItem.m
//  BTAudioQPlayer
//
//  Created by He baochen on 12-10-31.
//  Copyright (c) 2012年 Gary. All rights reserved.
//

#import "BTPlayerItem.h"

@implementation BTPlayerItem
@synthesize cacheData = _cacheData;
@synthesize isDataComplete = _isDataComplete;
@synthesize sampleRate = _sampleRate;
@synthesize packetDuration = _packetDuration;
@synthesize isFormatVBR = _isFormatVBR;

+ (BTPlayerItem *)playerItemWithURL:(NSURL *)URL {
  BTPlayerItem *item = [[[BTPlayerItem alloc] initWithURL:URL] autorelease];
  return item;
}

- (void)dealloc {
  self.url = nil;
  self.title = nil;
  [_cacheData release];
  _cacheData = nil;
  [super dealloc];
}

- (id)initWithURL:(NSURL*)URL {
  self = [super init];
  if (self) {
    self.url = URL;
    _cacheData = [[NSMutableData alloc] initWithCapacity:1024];
  }
  return self;
}

- (void)setAsbd:(AudioStreamBasicDescription)asbd {
  _asbd = asbd;
  _sampleRate = _asbd.mSampleRate;
  _packetDuration = (float)_asbd.mFramesPerPacket / _sampleRate;
  _isFormatVBR = (_asbd.mBytesPerPacket == 0 || _asbd.mFramesPerPacket == 0);
}

- (void)appendData:(NSData*)data {
  [_cacheData appendData:data];
  if ([_cacheData length] == self.expectedContentLength) {
    _isDataComplete = YES;
  }
}

- (NSUInteger)availableDataLength {
 return [_cacheData length] - self.byteWriteIndex;
}

@end
