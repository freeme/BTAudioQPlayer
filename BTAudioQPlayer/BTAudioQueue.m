//
//  AudioQueue.m
//

#import "BTAudioQueue.h"
#import "AudioPlayerUtil.h"


@interface BTAudioQueue(Private)
- (void)bufferDidEmpty:(AudioQueueBufferRef)bufferRef;
- (void)propertyChanged:(AudioQueuePropertyID)inPropertyID ;
- (void)moveToNextEmptyBuffer;

- (AudioQueueBufferRef)currentFillBuffer;
@end

@implementation BTAudioQueue

@synthesize delegate = _delegate;
@synthesize audioQueue = _audioQueue;
@synthesize status = _queueStatus;

void audioQueueOutputCallback (void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer);
void propertyChangeIsRunning(void *data, AudioQueueRef inAQ, AudioQueuePropertyID inID);


void audioQueueOutputCallback (void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
  if (inUserData != NULL && [(id)inUserData isKindOfClass:[BTAudioQueue class]]) {
    BTAudioQueue *audioQueue = (BTAudioQueue *)inUserData;
    [audioQueue bufferDidEmpty:inBuffer];
    //
  }
}

- (void)bufferDidEmpty:(AudioQueueBufferRef)bufferRef {
  
  //  unsigned int bufIndex = -1;
  //	for (unsigned int i = 0; i < kNumAQBufs; ++i) {
  //		if (bufferRef == _buffers[i]) {
  //			bufIndex = i;
  //			break;
  //    }
  //  }
  //
  //	if (bufIndex == -1) {
  //		//[self failWithErrorCode:AS_AUDIO_QUEUE_BUFFER_MISMATCH];
  //    [_condition lock];
  //    [_condition broadcast];
  //    [_condition unlock];
  //  }
  if (_condition) {
    [_condition lock];
    //_inuse[bufIndex] = NO;
    _bufCountInQueue--;
    CDLog(BTDFLAG_AUDIO_QUEUE,@"_bufCountInQueue-- = %d", _bufCountInQueue);
    [_condition broadcast];
    [_condition unlock];
  }
  if (_delegate && [_delegate respondsToSelector:@selector(audioQueue:isDoneWithBuffer:)]) {
    [_delegate audioQueue:self isDoneWithBuffer:bufferRef];
  }
}

void propertyChangeIsRunning(void *data, AudioQueueRef inAQ, AudioQueuePropertyID inID) {
  CDLog(BTDFLAG_AUDIO_QUEUE, @"????????");
  
  
  if (data != NULL && [(id)data isKindOfClass:[BTAudioQueue class]]) { //TODO:Fix bug, 切换歌曲里Crash。 异步操作，要处理中断
    BTAudioQueue *audioQueue = (BTAudioQueue *)data;
    
    [audioQueue propertyChanged:inID];
    /*
     int result = 0;
     UInt32 size = sizeof(UInt32);
     OSStatus status = AudioQueueGetProperty (audioQueue->_audioQueue, kAudioQueueProperty_IsRunning, &result, &size);
     if (!VERIFY_STATUS(status)) {
     //TODO: 容错处理
     //      audioQueue.status = BTAudioQueueStatusStopped;
     //      [audioQueue->_delegate audioQueuePlaybackIsComplete:audioQueue];
     return;
     }
     if (result == 0) {
     audioQueue.status = BTAudioQueueStatusStopped;
     [audioQueue->_delegate audioQueuePlaybackIsComplete:audioQueue];
     } else {
     audioQueue.status = BTAudioQueueStatusStarted;
     [audioQueue->_delegate audioQueuePlaybackIsStarting:audioQueue];
     }
     */
  }
}

- (void)propertyChanged:(AudioQueuePropertyID)inPropertyID {
  //异步操作，要处理中断
  if (inPropertyID == kAudioQueueProperty_IsRunning) {
    int result = 0;
    UInt32 size = sizeof(UInt32);
    OSStatus status = AudioQueueGetProperty (_audioQueue, kAudioQueueProperty_IsRunning, &result, &size);
    if (!VERIFY_STATUS(status)) {
      //TODO: 容错处理
      //      audioQueue.status = BTAudioQueueStatusStopped;
      //      [audioQueue->_delegate audioQueuePlaybackIsComplete:audioQueue];
      return;
    }
    if (result == 0) {
      _queueStatus = BTAudioQueueStatusStopped;
      if (_delegate && [_delegate respondsToSelector:@selector(audioQueuePlaybackIsComplete:)]) {
        [_delegate audioQueuePlaybackIsComplete:self];
      }
    } else {
      if (_queueStatus == BTAudioQueueStatusStarting || _queueStatus == BTAudioQueueStatusPaused) {
        if (_queueStatus == BTAudioQueueStatusPaused) {
          [self start];
        }
        if (_delegate && [_delegate respondsToSelector:@selector(audioQueuePlaybackIsStarting:)]) {
          [_delegate audioQueuePlaybackIsStarting:self];
        }
      }
    }
  }

}

- (void)dealloc {
  [_condition release];
  _condition = nil;
  _delegate = nil;
	if (_audioQueue != NULL) {
    VERIFY_STATUS(AudioQueueRemovePropertyListener(_audioQueue, kAudioQueueProperty_IsRunning, propertyChangeIsRunning, self));
		VERIFY_STATUS(AudioQueueDispose(_audioQueue, true));
    _audioQueue = NULL;
	}
	[super dealloc];
}
/*
- (id)initWithASBD:(AudioStreamBasicDescription)asbd {
  self = [super init];
  if (self) {
    _queueStatus = BTAudioQueueStatusInitialized;
    OSStatus status = AudioQueueNewOutput(&asbd,
                                          audioQueueOutputCallback,
                                          self,
                                          NULL, //设置Null,AudioQueue将在自己的内部线程(AQClient)中运行
                                          NULL,
                                          0,
                                          &_audioQueue);
    if (!VERIFY_STATUS(status)) {
      return nil;
    }
    status = AudioQueueAddPropertyListener (_audioQueue, kAudioQueueProperty_IsRunning, propertyChangeIsRunning, self);
    
    // set the software codec too on the queue.
    UInt32 val = kAudioQueueHardwareCodecPolicy_PreferSoftware;
    OSStatus ignorableError;
    ignorableError = AudioQueueSetProperty(_audioQueue, kAudioQueueProperty_HardwareCodecPolicy, &val, sizeof(UInt32));
    if (ignorableError){
      NSLog(@"set kAudioQueueProperty_HardwareCodecPolicy failed");
    }
    
    if (!VERIFY_STATUS(status)) {
      return nil;
    }
    
  }
	return self;
}
*/
- (id)initWithASBD:(AudioStreamBasicDescription)asbd packetBufferSize:(NSUInteger)packetBufferSize {
  self = [super init];
  if (self) {
    _queueStatus = BTAudioQueueStatusInitialized;
    OSStatus status = AudioQueueNewOutput(&asbd,
                                          audioQueueOutputCallback,
                                          self,
                                          NULL, //设置Null,AudioQueue将在自己的内部线程(AQClient)中运行
                                          NULL,
                                          0,
                                          &_audioQueue);
    if (!VERIFY_STATUS(status)) {
      return nil;
    }
    status = AudioQueueAddPropertyListener (_audioQueue, kAudioQueueProperty_IsRunning, propertyChangeIsRunning, self);
    
    // set the software codec too on the queue.
    UInt32 val = kAudioQueueHardwareCodecPolicy_PreferSoftware;
    OSStatus ignorableError;
    ignorableError = AudioQueueSetProperty(_audioQueue, kAudioQueueProperty_HardwareCodecPolicy, &val, sizeof(UInt32));
    if (ignorableError){
      NSLog(@"set kAudioQueueProperty_HardwareCodecPolicy failed");
    }
    
    if (!VERIFY_STATUS(status)) {
      return nil;
    }
    _packetBufferSize = packetBufferSize;
    for (unsigned int i = 0; i < kNumAQBufs; ++i) {
      OSStatus status = AudioQueueAllocateBuffer(_audioQueue, _packetBufferSize, &_buffers[i]);
      if (status) {
        //TODO: 容错处理
        //[self failWithErrorCode:AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED];
        return nil;
      }
    }
    _currentFillBufferIndex = 0;
    _bufCountInQueue = 0;
    _condition = [[NSCondition alloc] init];
  }
  return self;
}

- (OSStatus)setMagicCookie:(NSData *)magicCookie {
	return AudioQueueSetProperty(_audioQueue, kAudioQueueProperty_MagicCookie, magicCookie.bytes, magicCookie.length);
}

- (OSStatus)start {
  CDLog(BTDFLAG_AUDIO_QUEUE, @" >>>>>>>>>> start");
  if (_queueStatus == BTAudioQueueStatusInitialized) {
    _queueStatus = BTAudioQueueStatusStarting;
  } else {
    _queueStatus = BTAudioQueueStatusStarted;
  }
  
	OSStatus status = AudioQueueStart(_audioQueue, NULL);
  VERIFY_STATUS(status);
  return status;
}

- (OSStatus)pause {
  CDLog(BTDFLAG_AUDIO_QUEUE, @" >>>>>>>>>> pause");
  _queueStatus = BTAudioQueueStatusPaused;
	return AudioQueuePause(_audioQueue);
}

- (OSStatus)endOfStream {
  CDLog(BTDFLAG_AUDIO_QUEUE, @" >>>>>>>>>> endOfStream");
  _queueStatus = BTAudioQueueStatusStopping;
	OSStatus status = AudioQueueFlush(_audioQueue);
  status = AudioQueueReset(_audioQueue);
	VERIFY_STATUS(status);
  status = AudioQueueStop(_audioQueue, false);
  VERIFY_STATUS(status);
	return status;
}

- (OSStatus)stop {
  CDLog(BTDFLAG_AUDIO_QUEUE, @" >>>>>>>>>> stop");
  _queueStatus = BTAudioQueueStatusStopped;
  OSStatus status = AudioQueueReset(_audioQueue);
  VERIFY_STATUS(status);
  status = AudioQueueStop(_audioQueue, false);
  VERIFY_STATUS(status);
  return status;
}

- (OSStatus)getCurrentTime:(AudioTimeStamp *)outTimeStamp discontinuity:(Boolean *)outTimelineDiscontinuity {
  OSStatus status = AudioQueueGetCurrentTime(_audioQueue, NULL, outTimeStamp, outTimelineDiscontinuity);
  return status;
}

- (BOOL)isStopping {
  return ((_queueStatus == BTAudioQueueStatusStopping) || (_queueStatus == BTAudioQueueStatusStopped));
}

- (BOOL)isFull {
  return (_bufCountInQueue == kNumAQBufs);
}

- (BOOL)isEmpty {
  return (_bufCountInQueue == 0);
}




- (AudioQueueBufferRef)currentFillBuffer {
  return _buffers[_currentFillBufferIndex];
}

- (void)fileBufferByteCount:(UInt32)byteCount packetCount:(UInt32)packetCount data:(const void *)inputData packetDescs:(AudioStreamPacketDescription *)packetDescs {
  
  if (packetDescs) { //the following code assumes we're streaming VBR data
    //AudioQueueBufferRef fillBuf = NULL;
		for (int i = 0; i < packetCount && ![self isStopping]; ++i) { //TODO: 有托动操作时，这里的for需要及时结束，这里可能是会造成混音的地方
      //TODO: for 是否放在外面会更好？
			SInt64 packetOffset = packetDescs[i].mStartOffset;
			SInt64 packetSize   = packetDescs[i].mDataByteSize;
			SInt64 bufSpaceRemaining;
      
      // If the audio was terminated before this point, then
      // exit.
      //      if ([self isFinishing]){
      //        return;
      //      }
      
      //      if (packetSize > packetBufferSize) {
      //        [self failWithErrorCode:AS_AUDIO_BUFFER_TOO_SMALL];
      //      }
      
      bufSpaceRemaining = _packetBufferSize - _bytesFilled;
      
      
			// if the space remaining in the buffer is not enough for this packet, then enqueue the buffer.
			if (bufSpaceRemaining < packetSize)  {
        AudioQueueBufferRef  fillBuf = [self currentFillBuffer];
				[self enqueueBuffer:fillBuf];
        //fillBuf = NULL;
      }
			
      
      // If the audio was terminated while waiting for a buffer, then
      // exit.
      if ([self isStopping]) {
        return;
      }
      
      //
      // If there was some kind of issue with enqueueBuffer and we didn't
      // make space for the new audio data then back out
      //
      //http://github.com/mattgallagher/AudioStreamer/issues/#issue/22
      if (_bytesFilled + packetSize > _packetBufferSize) {
        return;
      }
      
      // copy data to the audio queue buffer
      //      if (fillBuf == NULL) {
      AudioQueueBufferRef  fillBuf = [self currentFillBuffer];
      //      }
      memcpy((char*)fillBuf->mAudioData + _bytesFilled, (const char*)inputData + packetOffset, packetSize);
      
      // fill out packet description
      _packetDescs[_packetsFilled] = packetDescs[i];
      _packetDescs[_packetsFilled].mStartOffset = _bytesFilled;
      // keep track of bytes filled and packets filled
      _bytesFilled += packetSize;
      _packetsFilled += 1;
      fillBuf->mAudioDataByteSize = _bytesFilled;
			
			// if that was the last free packet description, then enqueue the buffer.
			size_t packetsDescsRemaining = kAQMaxPacketDescs - _packetsFilled;
			if (packetsDescsRemaining == 0) {
				[self enqueueBuffer:fillBuf];
        //fillBuf = NULL;
			}
    }
  } else {
    //TODO: CBR format
  }
  
  
  
}
//
// enqueueBuffer
//
// Called from MyPacketsProc and connectionDidFinishLoading to pass filled audio
// bufffers (filled by MyPacketsProc) to the AudioQueue for playback. This
// function does not return until a buffer is idle for further filling or
// the AudioQueue is stopped.
//
// This function is adapted from Apple's example in AudioFileStreamExample with
// CBR functionality added.
//
- (void)enqueueBuffer:(AudioQueueBufferRef)filledBuffer {
  
  
  //  if ([self isFinishing]){
  //    return;
  //  }
  OSStatus err;
  //_inuse[_currentFillBufferIndex] = YES;
  _bufCountInQueue++;
  CDLog(BTDFLAG_AUDIO_QUEUE,@"_bufCountInQueue++ = %d", _bufCountInQueue);
  
  if (_packetsFilled) {
    err = AudioQueueEnqueueBuffer(_audioQueue, filledBuffer, _packetsFilled, _packetDescs);
  } else {
    err = AudioQueueEnqueueBuffer(_audioQueue, filledBuffer, 0, NULL);
  }
  [self moveToNextEmptyBuffer];
  //  if (err) {
  //    [self failWithErrorCode:AS_AUDIO_QUEUE_ENQUEUE_FAILED];
  //    return;
  //  }
  if (_bufCountInQueue == kNumAQBufs) { //||state == AS_FLUSHING_EOF ||
    CDLog(BTDFLAG_AUDIO_QUEUE, @"statue = %d", _queueStatus);
    if (_queueStatus == BTAudioQueueStatusInitialized || _queueStatus == BTAudioQueueStatusPaused) {
      UInt32 outNumberOfFramesPrepared;
      //OSStatus status = AudioQueuePrime (_audioQueue,0,&outNumberOfFramesPrepared);
      CDLog(BTDFLAG_AUDIO_QUEUE,@"[outNumberOfFramesPrepared = %ld", outNumberOfFramesPrepared);
      [self start];
    }
    [_delegate audioQueueIsFull:self];
  }
  
	// wait until next buffer is not in use
  [_condition lock];
  
	while ([self isFull]) {//_inuse[_currentFillBufferIndex])  {
    if (self.status == BTAudioQueueStatusPaused || self.status == BTAudioQueueStatusStopping ||self.status == BTAudioQueueStatusStopped) {
      break;
    }
    CDLog(BTDFLAG_AUDIO_QUEUE,@"[_condition       wait");
    [_condition wait];
  }
  CDLog(BTDFLAG_AUDIO_QUEUE,@"[_condition after wait");
  [_condition unlock];
}

- (void)moveToNextEmptyBuffer {
  // go to next buffer
  if (++_currentFillBufferIndex >= kNumAQBufs) {
    _currentFillBufferIndex = 0;
  }
  _bytesFilled = 0;		// reset bytes filled
  _packetsFilled = 0;		// reset packets filled
}

@end
