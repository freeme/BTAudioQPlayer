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

//- (BOOL)hasMoreData {
//  return (self.byteWriteIndex < self.expectedContentLength);
//}
////下载完成，数据也写完了
//- (BOOL)isEnd {
//  return (self.byteWriteIndex == self.expectedContentLength);
//}

- (Float64)duration {
	float calculatedBitRate = [self calculatedBitRate];
	
	if (calculatedBitRate == 0 || self.expectedContentLength == 0) {
		return 0.0;
  }
	
	return (self.expectedContentLength - self.dataOffset) / (calculatedBitRate * 0.125);
}

//
// calculatedBitRate
//
// returns the bit rate, if known. Uses packet duration times running bits per
//   packet if available, otherwise it returns the nominal bitrate. Will return
//   zero if no useful option available.
//
- (Float64)calculatedBitRate {
  Float64 bitRate = 0.0;
	if (_isFormatVBR) { //packetDuration = asbd.mFramesPerPacket / asbd.mSampleRate
		if (_packetDuration && self.processedPacketsCount > 50) {
			Float64 averagePacketByteSize = (Float64)self.processedPacketsSizeTotal / self.processedPacketsCount;
      CVLog(BTDFLAG_FILE_STREAM, @"averagePacketByteSize = %.4f",averagePacketByteSize);
      bitRate = 8.0 * averagePacketByteSize / _packetDuration;
    } else if (self.bitRate) {
			bitRate = self.bitRate;
    }
  } else {
		bitRate = 8.0 * _asbd.mSampleRate * _asbd.mBytesPerPacket * _asbd.mFramesPerPacket;
    self.bitRate = bitRate;
  }
  CVLog(BTDFLAG_FILE_STREAM, @"                   bitRate = %.4f",bitRate);
  CVLog(BTDFLAG_FILE_STREAM, @"           _packetDuration = %.4f",_packetDuration);
  CVLog(BTDFLAG_FILE_STREAM, @"    _processedPacketsCount = %d",_processedPacketsCount);
  CVLog(BTDFLAG_FILE_STREAM, @"_processedPacketsSizeTotal = %d",_processedPacketsSizeTotal);
	return bitRate;
}

- (void)reset {
  
}
@end
