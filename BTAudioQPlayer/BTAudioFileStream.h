//
//  AudioFileStream.h
//
// This is a very simple Objective-C wrapper around the
// AudioFileStream C API.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol BTAudioFileStreamDelegate;
@interface BTAudioFileStream : NSObject {
	AudioFileStreamID _streamID;
	id<BTAudioFileStreamDelegate> _delegate;
	OSStatus _callbackStatus;
  AudioStreamBasicDescription _asbd;
  
  UInt64  _processedPacketsSizeTotal;
  UInt32  _processedPacketsCount;
  float   _packetDuration;
  UInt64  _fileLength;
  UInt64  _dataOffset;
  BOOL    _isFormatVBR;
  UInt32  _bitRate;
  
  NSInteger                          _seekByteOffset;
  float                              _seekTime;
  Float64 _sampleRate;
}


@property (nonatomic) AudioStreamBasicDescription asbd;
@property (nonatomic,assign) id<BTAudioFileStreamDelegate> delegate;
//@property (nonatomic, readonly) UInt64 processedPacketsSizeTotal;
//@property (nonatomic, readonly) UInt32 processedPacketsCount;
@property (nonatomic) UInt64 fileLength;
@property (nonatomic) UInt64 dataOffset;
@property (nonatomic) float packetDuration;
@property (nonatomic) float seekTime;
@property (nonatomic) NSInteger seekBtyeOffset;
@property (nonatomic) Float64 sampleRate;
//@property (nonatomic) BOOL formatIsVBR;

- (id)initFileStreamWithDelegate:(id<BTAudioFileStreamDelegate>)delegate;

/*
 * Opens this file stream for parsing.
 * Returns an error code if an error occurs.  See documentation for 
 * AudioFileStreamOpen for possible errors.
 */
- (OSStatus)open;
- (void) close;
- (void)setSeekTime:(double)newSeekTime;
/*
 * Parses bytes from this audio stream.
 * Delegate will be notified asynchronously of any magic cookie, 
 * AudioStreamBasicDescription, or packet data resulting from this
 * parsing call.  All asynchronous notifications will happen before
 * this method returns.
 *
 * Returns an error code if an error occurs.  See documentation for
 * AudioFileStreamParseBytes, AudioFileStreamGetPropertyInfo, or
 * AudioFileStreamGetProperty for possible errors.  Errors from this 
 * method are generally unexpected.  If one occurs, it is probably
 * best not to continue parsing with this AudioFileStream object.
 */
//- (OSStatus)parseBytes:(NSData *)data;
//- (OSStatus)parseBytes:(const void*)inData dataSize:(UInt32)inDataSize;
- (OSStatus)parseBytes:(const void*)inData dataSize:(UInt32)inDataSize flags:(UInt32)inFlags;

- (NSString*)getFileFormat;
- (UInt64)getAudioDataByteCount;
- (UInt64)getAudioDataPacketCount;
- (UInt32)getMaxPacketSize;
- (UInt64)getDataOffset;
- (UInt32)getPacketSizeUpperBound;
- (UInt64)getAverageBytesPerPacket;
- (UInt32)getBitRate;

- (UInt32)getPacketBufferSize;
- (float)calculatedBitRate;
- (float)duration;

@end

@protocol BTAudioFileStreamDelegate<NSObject>
/*
 * Some audio formats have "magic cookies" which contain special
 * metadata about the stream that is specific to the audio format in
 * a non-generalizable way.  AudioQueue requires the magic cookie
 * for such audio formats to work correctly.  This method notifies
 * a delegate if a magic cookie is found when parsing an AudioFileStream.
 */
- (void)audioFileStream:(BTAudioFileStream *)stream foundMagicCookie:(NSData *)cookie;

/*
 * This method notifies a delegate when an AudioFileStream is about to
 * begin sending packets.  It is a signal to the delegate that the stream
 * is valid, and the delegate should now create an AudioQueue and prepare
 * it for queining and playback.
 */
- (void)audioFileStream:(BTAudioFileStream *)stream isReadyToProducePacketsWithASBD:(AudioStreamBasicDescription)absd;

/*
 * This method notfies a delegate that new packets have been parsed from
 * the stream and are ready for queuing in an AudioQueue.
 */
- (void)audioFileStream:(BTAudioFileStream *)stream callBackWithByteCount:(UInt32)byteCount packetCount:(UInt32)packetCount data:(const void *)inputData packetDescs:(AudioStreamPacketDescription *)packetDescs;

@end 
