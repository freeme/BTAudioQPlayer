//
//  AudioPlayer.h
//

#import <Foundation/Foundation.h>



#define kAQDefaultBufSize 2048	// Number of bytes in each audio queue buffer
// Needs to be big enough to hold a packet of
// audio from the audio file. If number is too
// large, queuing of audio before playback starts
// will take too long.
// Highly compressed files can use smaller
// numbers (512 or less). 2048 should hold all
// but the largest packets. A buffer size error
// will occur if this number is too small.

/*
typedef enum
{
	AS_INITIALIZED = 0,
	AS_STARTING_FILE_THREAD,
	AS_WAITING_FOR_DATA,
	AS_FLUSHING_EOF,
	AS_WAITING_FOR_QUEUE_TO_START,
	AS_PLAYING,
	AS_BUFFERING,
	AS_STOPPING,
	AS_STOPPED,
	AS_PAUSED,
} AudioStreamerState;

typedef enum
{
	AS_NO_STOP = 0,
	AS_STOPPING_EOF,
	AS_STOPPING_USER_ACTION,
	AS_STOPPING_ERROR,
	AS_STOPPING_TEMPORARILY
} AudioStreamerStopReason;

typedef enum
{
	AS_NO_ERROR = 0,
	AS_NETWORK_CONNECTION_FAILED,
	AS_FILE_STREAM_GET_PROPERTY_FAILED,
	AS_FILE_STREAM_SEEK_FAILED,
	AS_FILE_STREAM_PARSE_BYTES_FAILED,
	AS_FILE_STREAM_OPEN_FAILED,
	AS_FILE_STREAM_CLOSE_FAILED,
	AS_AUDIO_DATA_NOT_FOUND,
	AS_AUDIO_QUEUE_CREATION_FAILED,
	AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED,
	AS_AUDIO_QUEUE_ENQUEUE_FAILED,
	AS_AUDIO_QUEUE_ADD_LISTENER_FAILED,
	AS_AUDIO_QUEUE_REMOVE_LISTENER_FAILED,
	AS_AUDIO_QUEUE_START_FAILED,
	AS_AUDIO_QUEUE_PAUSE_FAILED,
	AS_AUDIO_QUEUE_BUFFER_MISMATCH,
	AS_AUDIO_QUEUE_DISPOSE_FAILED,
	AS_AUDIO_QUEUE_STOP_FAILED,
	AS_AUDIO_QUEUE_FLUSH_FAILED,
	AS_AUDIO_STREAMER_FAILED,
	AS_GET_AUDIO_TIME_FAILED,
	AS_AUDIO_BUFFER_TOO_SMALL
} AudioStreamerErrorCode;
*/

/*
 使用状态变量的时候应该注意，避免各状态所表述的内容有交叉，比如AS_STOPPING和AS_PLAYING，AS_STOPPING也是种播放ing的状态。AS_STARTING_FILE_THREAD其实也是AS_WAITING_FOR_DATA
 这样的状态设置将导致后续难以维护
 
 单纯从播放器的角度来看待状态，只需要有以下几种，（或者从用户可见（UI）的状态来看）,其他的内部状态不需要让用户知道
 stop: 初始和最终，都应该是这个状态。也有可能是因为某种错误而导致进入这个状态
 playing: 播放中，无需多解释
 paused: 暂停，这个只代表用户行为的暂停。当然播放器在播放的过程中，还有因为不能正常播放而显示出类似“暂停”的状态，统一归为waiting
 waiting: 进入这个状态有很多原因。一个主要的原因就是等待数据。
 
 */
//typedef NS_ENUM(NSInteger, BTAudioPlayerStatus) {
//	BTAudioPlayerStatusStop, 
//  BTAudioPlayerStatusWaiting,
//  BTAudioPlayerStatusPlaying,
//  BTAudioPlayerStatusPaused,
//  //BTAudioPlayerStatusReadyToPlay
//} ;


//BTAudioPlayerStateStop: Finish, UserAction, Error
//BTAudioPlayerStateWaiting: WaitingData, QUEUE_TO_START,Waiting Buffer
//
//#import "BTAudioRequest.h"
//#import "BTAudioFileStream.h"
//#import "BTAudioQueue.h"
//#import "BTPlayerItemInternal.h"
//#import "BTRunLoopSource.h"
//#import "BTAudioPlayer.h"
//#import "BTPlayerItem.h"
#import "BTAudioPlayer.h"
@class BTAudioPlayer;
@class BTPlayerItem;
@class BTAudioRequest;
@class BTAudioFileStream;
@class BTAudioQueue;
@class BTPlayerItemInternal;
@class BTRunLoopSource;
@protocol BTAudioPlayerDelegate;
@protocol BTAudioRequestDelegate;
@protocol BTAudioFileStreamDelegate;
@protocol BTAudioQueueDelegate;
@protocol BTRunLoopSourcePerformDelegate;

@interface BTAudioPlayerInternal : NSObject <	BTAudioRequestDelegate,	BTAudioFileStreamDelegate,	BTAudioQueueDelegate, BTRunLoopSourcePerformDelegate> {
  @private
  BTAudioPlayer *           _outsidePlayer;
  BTPlayerItem  *           _currentItem;
  
  
  //==============================
	id<BTAudioPlayerDelegate> _delegate;
	BTAudioRequest *          _request;
	BTAudioFileStream *       _fileStream;
	BTAudioQueue *            _audioQueue;
	
	//volatile BOOL                      paused;
  volatile NSInteger       _playStatus;
  NSURL *                   _url;
  NSThread *                _thread;
  
//  NSMutableData *                 _cacheData;
//  int                             _byteWriteIndex;
//  BOOL                            _discontinuity;
//  
//  UInt32                              packetBufferSize;
  BTRunLoopSource*          _btRunLoopSource;
  CFRunLoopSourceRef        _runLoopSource;
  CFRunLoopRef              _runLoop;
  
  CFRunLoopSourceRef        _runLoopSourcePlay;
  CFRunLoopSourceRef        _runLoopSourceSeek;
  BTPlayerItemInternal*             _playerItem;
//  NSInteger                           seekByteOffset;
//  double                              seekTime;
//	BOOL                                seekWasRequested;
	Float64                              requestedSeekTime;
  NSTimer                   *heartbeatTimer;
}
- (id)initWithAudioPlayer:(BTAudioPlayer*) audioPlayer;
- (id)initWithURL:(NSURL *)URL audioPlayer:(BTAudioPlayer*) audioPlayer;
- (id)initWithPlayerItem:(BTPlayerItem *)item audioPlayer:(BTAudioPlayer*) audioPlayer;
- (void)setURL:(NSURL*)url;
- (void)play;

//==================
@property (nonatomic) BOOL paused;
@property (readonly) BTAudioPlayerStatus status;
@property (nonatomic, retain) NSError *error;
- (id)initPlayerWithDelegate:(id<BTAudioPlayerDelegate>) aDelegate;
- (id)initPlayerWithURL:(NSURL *)url delegate:(id<BTAudioPlayerDelegate>) aDelegate;



- (void)play:(NSURL*)url;

- (void)start;

- (void)stop;

- (Float64)playProgress;

- (Float64)duration;

- (Float64)downloadProgress;

- (void)seekToTime:(Float64)newSeekTime;
//- (void)updateStatus:(BTAudioPlayerStatus)status;

@end



//@protocol BTAudioPlayerDelegate<NSObject>
///*
// * Notifies the delegate that the requested file was not playable.
// */
//- (void)audioPlayer:(BTAudioPlayerInternal *)audioPlayer failedWithError:(NSError*)error;
//
///*
// * Notifies the delegate that playback of the requested file has begun.
// */
//- (void)audioPlayerStarted:(BTAudioPlayerInternal *)audioPlayer;
//
//- (void)audioPlayerWaiting:(BTAudioPlayerInternal *)audioPlayer;
//
///*
// * Notifies the delegate that playback of the request file is complete.
// */
//- (void)audioPlayerFinished:(BTAudioPlayerInternal *)audioPlayer;
//
//- (void)audioPlayer:(BTAudioPlayerInternal *) audioPlayer downloadProgress:(float)progress;
//@end

/*
 Responding to Sound Playback Completion
 – audioPlayerDidFinishPlaying:successfully:
 Responding to an Audio Decoding Error
 – audioPlayerDecodeErrorDidOccur:error:
 Handling Audio Interruptions
 – audioPlayerBeginInterruption:
 – audioPlayerEndInterruption:
 – audioPlayerEndInterruption:withFlags:



*/

