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
@synthesize byteWriteIndex = _byteWriteIndex;

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

//- (NSUInteger) byteWriteIndex {
//  if (self.seekByteOffset) {
//    _byteWriteIndex = self.seekByteOffset;
//    self.seekByteOffset = 0;
//  }
//  return _byteWriteIndex;
//}

//- (void)setSeekTime:(double)newSeekTime {
//	if ([self calculatedBitRate] == 0.0 || self.expectedContentLength <= 0) {
//		return;
//	}
//	
//	//
//	// Calculate the byte offset for seeking
//	//
//	self.seekByteOffset = self.dataOffset + (newSeekTime / [self duration]) * (self.expectedContentLength - self.dataOffset);
//  
//	//
//	// Attempt to leave 1 useful packet at the end of the file (although in
//	// reality, this may still seek too far if the file has a long trailer).
//	//
//
//	if (self.seekByteOffset > self.expectedContentLength - 2 * self.packetBufferSize) {
//		self.seekByteOffset = self.expectedContentLength - 2 * self.packetBufferSize;
//	}
//	
//	//
//	// Store the old time from the audio queue and the time that we're seeking
//	// to so that we'll know the correct time progress after seeking.
//	//
//	self.seekTime = newSeekTime;
//	
//	//
//	// Attempt to align the seek with a packet boundary
//	//
//	double calculatedBitRate = [self calculatedBitRate];
//	if (self.packetDuration > 0 && calculatedBitRate > 0) {
//		UInt32 ioFlags = 0;
//		SInt64 packetAlignedByteOffset;
//		SInt64 seekPacket = floor(newSeekTime / _packetDuration);
//		OSStatus err = AudioFileStreamSeek(_streamID, seekPacket, &packetAlignedByteOffset, &ioFlags);
//		if (!err && !(ioFlags & kAudioFileStreamSeekFlag_OffsetIsEstimated))
//		{
//			_seekTime -= ((_seekByteOffset - _dataOffset) - packetAlignedByteOffset) * 8.0 / calculatedBitRate;
//			_seekByteOffset = packetAlignedByteOffset + _dataOffset;
//		}
//	}
//}

- (void)reset {
  self.seekByteOffset = 0;
  self.seekTime = 0;
  self.discontinuity = YES;
  self.byteWriteIndex = 0;
//  self.processedPacketsSizeTotal = 0;
//  self.processedPacketsCount = 0;
}
@end
