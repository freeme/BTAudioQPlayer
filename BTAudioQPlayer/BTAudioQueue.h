//
//  AudioQueue.h
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#define kNumAQBufs 16			// Number of audio queue buffers we allocate.
// Needs to be big enough to keep audio pipeline
// busy (non-zero number of queued buffers) but
// not so big that audio takes too long to begin
// (kNumAQBufs * kAQBufSize of data must be
// loaded before playback will start).
//
// Set LOG_QUEUED_BUFFERS to 1 to log how many
// buffers are queued at any time -- if it drops
// to zero too often, this value may need to
// increase. Min 3, typical 8-24.

#define kAQMaxPacketDescs 512	// Number of packet descriptions in our array

typedef NS_ENUM(NSInteger, BTAudioQueueStatus) {
	BTAudioQueueStatusInitialized,
  BTAudioQueueStatusStarting, //这个时候Queue还没有播放出声音
  BTAudioQueueStatusStarted,
  //BTAudioQueueStatusReseted,
  BTAudioQueueStatusPaused,
  BTAudioQueueStatusStopping, //这个时候Queue中还有Buffer没有播放完
  BTAudioQueueStatusStopped,
} ;

@protocol BTAudioQueueDelegate;
@interface BTAudioQueue : NSObject {
	AudioQueueRef             _audioQueue;
  volatile BTAudioQueueStatus        _queueStatus;
	id<BTAudioQueueDelegate>  _delegate;

  AudioQueueBufferRef       _buffers[kNumAQBufs];
  BOOL                      _inuse[kNumAQBufs];
  NSUInteger                _packetBufferSize;
  
  
  AudioStreamPacketDescription    _packetDescs[kAQMaxPacketDescs];
  NSUInteger                      _packetsFilled;
  NSUInteger                      _bytesFilled;  // how many bytes have been filled
  
  unsigned short      _currentFillBufferIndex;
  unsigned short      _bufCountInQueue;
  
  NSCondition *       _condition;
  volatile Float32             _volume;
}

@property (nonatomic,assign) id<BTAudioQueueDelegate> delegate;
@property (nonatomic, readonly) AudioQueueRef audioQueue;
@property (nonatomic) BTAudioQueueStatus status;
@property unsigned short bufCountInQueue;
- (id)initWithASBD:(AudioStreamBasicDescription)asbd packetBufferSize:(NSUInteger)packetBufferSize;

/*
 * Sets the magic cookie for this audio queue.  See Core Audio documentation
 * for AudioQueueSetProperty for possible return values.
 */
- (OSStatus)setMagicCookie:(NSData *)magicCookie;

/*
 * Starts playback of the audio queue.  See Core Audio documentation
 * for AudioQueueStart for possible return values.
 */
- (OSStatus)start;

/*
 * Pauses playback of the audio queue.  See Core Audio documentation
 * for AudioQueuePause for possible return values.
 */
- (OSStatus)pause;


- (void)enqueueBuffer:(AudioQueueBufferRef)bufferRef;
/*
 * Enqueues a buffer for future playback.  See Core Audio documentation for 
 * AudioQueueEnqueueBuffer for possible return values;
 */
//- (OSStatus)enqueueBuffer:(AudioQueueBufferRef)bufferRef;
//- (OSStatus)enqueueBuffer:(AudioQueueBufferRef)bufferRef inNumPacketDescs:(UInt32)inNumPacketDescs inPacketDescs:(const AudioStreamPacketDescription *) inPacketDescs;;

/*
 * Notifies this AudioQueue that no more audio will be queued, and that
 * the AudioQueue should stop once the last currently queued buffer 
 * is complete. See Core Audio documentation for AudioQueueFlush and
 * AudioStop for possible return values;
 */
- (OSStatus)endOfStream;

- (OSStatus)stop;

- (OSStatus)reset;
- (OSStatus)getCurrentTime:(AudioTimeStamp *)outTimeStamp discontinuity:(Boolean *)outTimelineDiscontinuity;
- (BOOL)isStopping;
- (BOOL)isFull;
- (BOOL)isEmpty;

//- (void)fileBufferWithPackets:(NSData *)packetData count:(UInt32)packetCount desc:(AudioStreamPacketDescription *)packetDescriptions;
- (void)fileBufferByteCount:(UInt32)byteCount packetCount:(UInt32)packetCount data:(const void *)inputData packetDescs:(AudioStreamPacketDescription *)packetDescs;

@end



@protocol BTAudioQueueDelegate<NSObject>
/*
 * Notifies the delegate that the AudioQueue is done enqueueing a
 * buffer and the buffer may now be released.
 */
- (void)audioQueue:(BTAudioQueue *)audioQueue isDoneWithBuffer:(AudioQueueBufferRef)bufferRef;

/*
 * Notifies the delegate that audio is now playing on this AudioQueue.
 */
- (void)audioQueuePlaybackIsStarting:(BTAudioQueue *)audioQueue;

/*
 * Notifies the delegate that audio playback has finished
 * on this AudioQueue.
 */
- (void)audioQueuePlaybackIsComplete:(BTAudioQueue *)audioQueue;

//- (void)audioQueueIsFull:(BTAudioQueue *)audioQueue;
@end
