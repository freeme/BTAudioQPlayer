//
//  AudioQueue.m
//

#import "BTAudioQueue.h"
#import "AudioPlayerUtil.h"
#import "BTPlayerItem.h"

@interface BTAudioQueue(Private)
- (void)bufferDidEmpty:(AudioQueueBufferRef)bufferRef;
- (void)propertyChanged:(AudioQueuePropertyID)inPropertyID ;
- (void)moveToNextEmptyBuffer;

- (AudioQueueBufferRef)currentFillBuffer;
@end

@implementation BTAudioQueue

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
  //NSAssert1(![[NSThread currentThread].name isEqualToString:@"AQClient"], @"%s", __FUNCTION__);
  unsigned int bufIndex = -1;
	for (unsigned int i = 0; i < kNumAQBufs; ++i) {
		if (bufferRef == _buffers[i]) {
			bufIndex = i;
			break;
    }
  }

	if (bufIndex == -1) {
		//[self failWithErrorCode:AS_AUDIO_QUEUE_BUFFER_MISMATCH];
    [_condition lock];
    [_condition broadcast];
    [_condition unlock];
    
  } else {
    [_condition lock];
    _inuse[bufIndex] = NO;
    _bufCountInQueue--;
    //CDLog(BTDFLAG_AUDIO_QUEUE,@"_bufCountInQueue-- = %d bufferRef:%d", _bufCountInQueue,bufferRef);
    [_condition broadcast];
    [_condition unlock];
    
//    if (_delegate && [_delegate respondsToSelector:@selector(audioQueue:isDoneWithBuffer:)]) {
//      [_delegate audioQueue:self isDoneWithBuffer:bufferRef];
//    }
  }

}

void propertyChangeIsRunning(void *data, AudioQueueRef inAQ, AudioQueuePropertyID inID) {
  if (data != NULL && [(id)data isKindOfClass:[BTAudioQueue class]]) { //TODO:Fix bug, 切换歌曲里Crash。 异步操作，要处理中断
    BTAudioQueue *audioQueue = (BTAudioQueue *)data;
    [audioQueue propertyChanged:inID];
  }
}

- (void)propertyChanged:(AudioQueuePropertyID)inPropertyID {
  //异步操作，要处理中断
  if (_audioQueue && (inPropertyID == kAudioQueueProperty_IsRunning)) {
    int result = 0;
    UInt32 size = sizeof(UInt32);
    OSStatus status = AudioQueueGetProperty (_audioQueue, kAudioQueueProperty_IsRunning, &result, &size);
    if (!VERIFY_STATUS(status)) {
      //TODO: 容错处理
      //      audioQueue.status = BTAudioQueueStatusStopped;
      //      [audioQueue->_delegate audioQueuePlaybackIsComplete:audioQueue];
      result = 0;
    }
    if (result == 0) {
      _queueStatus = BTAudioQueueStatusStopped;
      if (_delegate && [_delegate respondsToSelector:@selector(audioQueuePlaybackIsComplete:)]) {
        //dispatch_async(dispatch_get_main_queue(), ^{
          [_delegate audioQueuePlaybackIsComplete:self];
        //});
      }
    } else {
      if (_delegate && [_delegate respondsToSelector:@selector(audioQueuePlaybackIsStarting:)]) {
        //dispatch_async(dispatch_get_main_queue(), ^{
          [_delegate audioQueuePlaybackIsStarting:self];
        //});
      }
    }
  }

}

- (void)dealloc {
  [_condition release];
  _condition = nil;
	if (_audioQueue != NULL) {
    [self unbind];
	}
	[super dealloc];
}


- (id)initWithDelegate:(id<BTAudioQueueDelegate>) delegate {
  self = [super init];
  if (self) {
    _condition = [[NSCondition alloc] init];
    _delegate = delegate;
  }
  return self;
}

- (OSStatus)setMagicCookie:(NSData *)magicCookie {
   OSStatus status = noErr;
  if (_audioQueue) {
    status = AudioQueueSetProperty(_audioQueue, kAudioQueueProperty_MagicCookie, magicCookie.bytes, magicCookie.length);
  }
	return status;
}


- (void)bind {
  CDLog(BTDFLAG_AUDIO_QUEUE, @" >>>>>>>>>> initQueue _audioQueue:%d", _audioQueue);
  if (_audioQueue == NULL && _delegate && [_delegate respondsToSelector:@selector(playerItemForAudioQueue:)]) {
    BTPlayerItem *item = [_delegate playerItemForAudioQueue:self];
    if (item) {
      _queueStatus = BTAudioQueueStatusStopped;
      _packetBufferSize = item.packetBufferSize;
      AudioStreamBasicDescription asbd = item.asbd;
      OSStatus status = AudioQueueNewOutput(&asbd,
                                            audioQueueOutputCallback,
                                            self,
                                            NULL, //设置Null,AudioQueue将在自己的内部线程(AQClient)中运行
                                            NULL,
                                            0,
                                            &_audioQueue);

      status = AudioQueueAddPropertyListener (_audioQueue, kAudioQueueProperty_IsRunning, propertyChangeIsRunning, self);
      
      // set the software codec too on the queue.
      UInt32 val = kAudioQueueHardwareCodecPolicy_PreferSoftware;
      OSStatus ignorableError;
      ignorableError = AudioQueueSetProperty(_audioQueue, kAudioQueueProperty_HardwareCodecPolicy, &val, sizeof(UInt32));
      if (ignorableError){
        NSLog(@"set kAudioQueueProperty_HardwareCodecPolicy failed");
      }
      for (unsigned int i = 0; i < kNumAQBufs; ++i) {
        OSStatus status = AudioQueueAllocateBuffer(_audioQueue, _packetBufferSize, &_buffers[i]);
//        if (status) {
//          //TODO: 容错处理
//          //[self failWithErrorCode:AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED];
//          return nil;
//        }
      }
      
      AudioQueueSetParameter (_audioQueue, kAudioQueueParam_Volume, 0.5);
      _currentFillBufferIndex = 0;
      _bufCountInQueue = 0;
    }
  }
}

- (OSStatus)start {
  OSStatus status = noErr;
  CDLog(BTDFLAG_AUDIO_QUEUE, @" >>>>>>>>>> start");
  if (_audioQueue) {
    if (_queueStatus == BTAudioQueueStatusStopped) {
      if (_audioQueue == NULL) {
        [self bind];
      }
      _queueStatus = BTAudioQueueStatusStarting;
      status = AudioQueueStart(_audioQueue, NULL);
      
      VERIFY_STATUS(status);
    } else if (_queueStatus == BTAudioQueueStatusStarting){
      _queueStatus = BTAudioQueueStatusStarted;
    } else if (_queueStatus == BTAudioQueueStatusPaused) {
      _queueStatus = BTAudioQueueStatusStarted;
      status = AudioQueueStart(_audioQueue, NULL);
    }
  }
  return status;
}

- (OSStatus)pause {
  CDLog(BTDFLAG_AUDIO_QUEUE, @" >>>>>>>>>> pause");
  OSStatus status = noErr;
  if (_audioQueue) {
    _queueStatus = BTAudioQueueStatusPaused;
    status = AudioQueuePause(_audioQueue);
  }
	return status;
}

- (OSStatus)endOfStream {
  CDLog(BTDFLAG_AUDIO_QUEUE, @" >>>>>>>>>> endOfStream");
  OSStatus status = noErr;
  if (_audioQueue) {
    if (_queueStatus == BTAudioQueueStatusStopping) {// 这里有问题，availableDataLength = 0时， writeData可能不会再进来了
      if ([self isEmpty]) {
        [self pause];
        if (_delegate && [_delegate respondsToSelector:@selector(audioQueuePlaybackIsComplete:)]) {
          //dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate audioQueuePlaybackIsComplete:self];
          //});
        }
      }
    } else {
      _queueStatus = BTAudioQueueStatusStopping;
      status = AudioQueueFlush(_audioQueue);
    }
  }
	return status;
}

- (OSStatus)unbind {
  CDLog(BTDFLAG_AUDIO_QUEUE, @" >>>>>>>>>> stop");
  OSStatus status = noErr;
  //_delegate = nil;
	if (_audioQueue != NULL) {
    VERIFY_STATUS(AudioQueueRemovePropertyListener(_audioQueue, kAudioQueueProperty_IsRunning, propertyChangeIsRunning, self));
    status = AudioQueueFlush(_audioQueue);
    status = AudioQueueReset(_audioQueue);
    VERIFY_STATUS(status);
    status = AudioQueueStop(_audioQueue, true);
    VERIFY_STATUS(status);
    _queueStatus = BTAudioQueueStatusStopped;
		VERIFY_STATUS(AudioQueueDispose(_audioQueue, true));
    _audioQueue = NULL;
    _currentFillBufferIndex = 0;
    _bufCountInQueue = 0;
	}

  return status;
}

- (OSStatus)reset {
  CDLog(BTDFLAG_AUDIO_QUEUE, @" >>>>>>>>>> reset");
  OSStatus status = noErr;
  if (_audioQueue) {
    status = AudioQueueReset(_audioQueue);
  }
  return status;
}

- (OSStatus)getCurrentTime:(AudioTimeStamp *)outTimeStamp discontinuity:(Boolean *)outTimelineDiscontinuity {
  OSStatus status = noErr;
  if (_audioQueue) {
    status = AudioQueueGetCurrentTime(_audioQueue, NULL, outTimeStamp, outTimelineDiscontinuity);
  }
  return status;
}

//- (BOOL)isStopping {
//  return (_queueStatus == BTAudioQueueStatusStopping);
//}

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
  if (_audioQueue == NULL) {
    return;
  }
  if (packetDescs) { //the following code assumes we're streaming VBR data
    //AudioQueueBufferRef fillBuf = NULL;
		for (int i = 0; i < packetCount && _audioQueue; ++i) { //TODO: 有托动操作时，这里的for需要及时结束，这里可能是会造成混音的地方
      //TODO: for 是否放在外面会更好？
			SInt64 packetOffset = packetDescs[i].mStartOffset;
			SInt64 packetSize   = packetDescs[i].mDataByteSize;
			SInt64 bufSpaceRemaining;
      //CDLog(BTDFLAG_AUDIO_QUEUE, @"--->i = %d",i);
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
      if (_audioQueue == NULL) {
        CDLog(BTDFLAG_AUDIO_QUEUE, @"-------------------------1");
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
  OSStatus status;
  _inuse[_currentFillBufferIndex] = YES;
  _bufCountInQueue++;
  //CDLog(BTDFLAG_AUDIO_QUEUE,@"_bufCountInQueue++ = %d", _bufCountInQueue);
  
  if (_packetsFilled) {
    status = AudioQueueEnqueueBuffer(_audioQueue, filledBuffer, _packetsFilled, _packetDescs);
  } else {
    status = AudioQueueEnqueueBuffer(_audioQueue, filledBuffer, 0, NULL);
  }
  [self moveToNextEmptyBuffer];
  //  if (err) {
  //    [self failWithErrorCode:AS_AUDIO_QUEUE_ENQUEUE_FAILED];
  //    return;
  //  }
  if (_bufCountInQueue == kNumAQBufs) { //||state == AS_FLUSHING_EOF ||
    CVLog(BTDFLAG_AUDIO_QUEUE, @"statue = %d", _queueStatus);
    //if (_queueStatus == BTAudioQueueStatusStopped || _queueStatus == BTAudioQueueStatusPaused) {
      //UInt32 outNumberOfFramesPrepared;
      //OSStatus status = AudioQueuePrime (_audioQueue,0,&outNumberOfFramesPrepared);
      //CDLog(BTDFLAG_AUDIO_QUEUE,@"[outNumberOfFramesPrepared = %ld", outNumberOfFramesPrepared);
    if (_delegate && [_delegate respondsToSelector:@selector(audioQueueIsFull:)]) {
      //dispatch_async(dispatch_get_main_queue(), ^{
        [_delegate audioQueueIsFull:self];
      //});
    }
  }
  
	// wait until next buffer is not in use
  [_condition lock];
  
	while (_inuse[_currentFillBufferIndex]) {//_inuse[_currentFillBufferIndex])  {self.status == BTAudioQueueStatusPaused || 
//    if (self.status == BTAudioQueueStatusStopping ||self.status == BTAudioQueueStatusStopped || self.status == BTAudioQueueStatusPaused) {
//      break;
//    }
    CVLog(BTDFLAG_AUDIO_QUEUE,@"[_condition       wait");
    [_condition wait];
  }
  CVLog(BTDFLAG_AUDIO_QUEUE,@"[_condition after wait");
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
