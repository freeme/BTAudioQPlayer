//
//  BTPlayerItem.m
//  BTAudioQPlayer
//
//  Created by He baochen on 12-10-31.
//  Copyright (c) 2012年 Gary. All rights reserved.
//

#import "BTPlayerItemInternal.h"
#import "BTAudioPlayerInternal.h"

@implementation BTPlayerItemInternal
@synthesize cacheData = _cacheData;
@synthesize readBytes = _readBytes;
@synthesize isDataComplete = _isDataComplete;
@synthesize sampleRate = _sampleRate;
@synthesize packetDuration = _packetDuration;
@synthesize isFormatVBR = _isFormatVBR;
@synthesize byteWriteIndex = _byteWriteIndex;

+ (BTPlayerItemInternal *)playerItemWithURL:(NSURL *)URL {
  BTPlayerItemInternal *item = [[[BTPlayerItemInternal alloc] initWithURL:URL] autorelease];
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
    _readBytes = [_cacheData mutableBytes];
    _discontinuity = YES;
  }
  return self;
}

- (void)setAsbd:(AudioStreamBasicDescription)asbd {
  _asbd = asbd;
  _sampleRate = _asbd.mSampleRate;
  _packetDuration = (float)_asbd.mFramesPerPacket / _sampleRate;
  _isFormatVBR = (_asbd.mBytesPerPacket == 0 || _asbd.mFramesPerPacket == 0);
  
  //  NSString *fileFormat = [self getFileFormat];
  //  UInt64 audioDataByteCount = [self getAudioDataByteCount];
  //  UInt64 audioDataPacketCount = [self getAudioDataPacketCount];
  //  UInt32 maxPacketSize = [self getMaxPacketSize];
  //  _dataOffset = [self getDataOffset];
  //  UInt32 packetSizeUpperBound = [self getPacketSizeUpperBound];
  //  UInt64 averageBytesPerPacket = [self getAverageBytesPerPacket];
  //  _bitRate = [self getBitRate];
  //  CILog(BTDFLAG_FILE_STREAM, @"isFormatVBR           = %d", _isFormatVBR);
  //  CILog(BTDFLAG_FILE_STREAM, @"fileFormat            = %@", fileFormat);
  //  CILog(BTDFLAG_FILE_STREAM, @"audioDataByteCount    = %lld", audioDataByteCount);
  //  CILog(BTDFLAG_FILE_STREAM, @"audioDataPacketCount  = %lld", audioDataPacketCount);
  //  CILog(BTDFLAG_FILE_STREAM, @"maxPacketSize         = %ld", maxPacketSize);
  //  CILog(BTDFLAG_FILE_STREAM, @"dataOffset            = %lld", _dataOffset);
  //  CILog(BTDFLAG_FILE_STREAM, @"packetSizeUpperBound  = %ld", packetSizeUpperBound);
  //  CILog(BTDFLAG_FILE_STREAM, @"averageBytesPerPacket = %lld", averageBytesPerPacket);
  //  CILog(BTDFLAG_FILE_STREAM, @"bitRate               = %ld", _bitRate);
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
  self.seekByteOffset = 0;
  self.seekTime = 0;
  self.discontinuity = YES;
  self.byteWriteIndex = 0;
//  self.processedPacketsSizeTotal = 0;
//  self.processedPacketsCount = 0;
}

- (NSData*)readData {
  NSData *readData = nil;
  NSUInteger availableDataLength = [_cacheData length] - self.byteWriteIndex;
  if (availableDataLength > 0) {
    //TODO: 16*kAQDefaultBufSize 可以使queue达到Full的状态
    NSUInteger readLength = ((availableDataLength >= 16*kAQDefaultBufSize) ? 16*kAQDefaultBufSize : availableDataLength);
    readData = [NSData dataWithBytes:(_cacheData.mutableBytes + self.byteWriteIndex) length:readLength];
    self.byteWriteIndex += readLength;
  }
  return readData;
}
@end
