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
  BOOL    _isFormatVBR;
}


@property (nonatomic) AudioStreamBasicDescription asbd;
@property (nonatomic,assign) id<BTAudioFileStreamDelegate> delegate;

- (id)initFileStreamWithDelegate:(id<BTAudioFileStreamDelegate>)delegate;

/*
 * Opens this file stream for parsing.
 * Returns an error code if an error occurs.  See documentation for 
 * AudioFileStreamOpen for possible errors.
 */
- (OSStatus)open;
- (void) close;
- (OSStatus)seekWithPacketOffset:(SInt64)inPacketOffset  outDataByteOffset:(SInt64 *)outDataByteOffset ioFlags:(UInt32 *)ioFlags;

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
