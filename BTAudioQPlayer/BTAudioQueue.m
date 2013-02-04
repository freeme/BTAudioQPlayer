//
//  AudioQueue.m
//

#import "BTAudioQueue.h"
#import "AudioPlayerUtil.h"
#import "BTPlayerItemInternal.h"
#define AQThreadName @"AQClient"
NSString *const BTAudioQueueErrorDomain = @"BTAudioQueueErrorDomain";

@interface  BTBufferProxy : NSObject

@property(nonatomic) AudioQueueBufferRef buffer;

@end

@implementation BTBufferProxy

@end

@interface BTAudioQueue(Private)

- (void)failWithError:(BTAudioQueueErrorCode)btQueueError status:(OSStatus) osStatus;
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
    if (inAQ == audioQueue.audioQueue) {
      [audioQueue bufferDidEmpty:inBuffer];
    }
  }
}

//- (void)bufferDidEmpty:(AudioQueueBufferRef)bufferRef {
//  unsigned int bufIndex = -1;
//	for (unsigned int i = 0; i < kNumAQBufs; ++i) {
//		if (bufferRef == _buffers[i]) {
//			bufIndex = i;
//			break;
//    }
//  }
//
//	if (bufIndex == -1) {
//    [self failWithError:BTAudioQueueErrorBufferMisMatch status:noErr];
//    [_condition lock];
//    [_condition broadcast];
//    [_condition unlock];
//    
//  } else {
//    [_condition lock];
//    _inuse[bufIndex] = NO;
//    _bufCountInQueue--;
//    CVLog(BTDFLAG_AUDIO_QUEUE,@"_bufCountInQueue-- = %d bufIndex:%d", _bufCountInQueue, bufIndex);
//    [_condition broadcast];
//    [_condition unlock];
//  }
//}


void propertyChangeIsRunning(void *data, AudioQueueRef inAQ, AudioQueuePropertyID inID) {
  if (data != NULL && [(id)data isKindOfClass:[BTAudioQueue class]]) { //TODO:Fix bug, 切换歌曲里Crash。 异步操作，要处理中断
    BTAudioQueue *audioQueue = (BTAudioQueue *)data;
    if (inAQ == audioQueue.audioQueue) {
      [audioQueue propertyChanged:inID];
    }
  }
}

- (void)propertyChanged:(AudioQueuePropertyID)inPropertyID {
  //异步操作，要处理中断
    CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
  if (_audioQueue && (inPropertyID == kAudioQueueProperty_IsRunning)) {
    int result = 0;
    UInt32 size = sizeof(UInt32);
    OSStatus status = AudioQueueGetProperty (_audioQueue, kAudioQueueProperty_IsRunning, &result, &size);
    if (!VERIFY_STATUS(status)) {
      //TODO: 容错处理
      [self failWithError:BTAudioQueueErrorIsRunning status:status];
      return;
    }
    if (result == 0) {
      _queueStatus = BTAudioQueueStatusStopped;
      if (_delegate && [_delegate respondsToSelector:@selector(audioQueuePlaybackIsComplete:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [_delegate audioQueuePlaybackIsComplete:self];
        });
      }
    } else {
      if (_delegate && [_delegate respondsToSelector:@selector(audioQueuePlaybackIsStarting:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [_delegate audioQueuePlaybackIsStarting:self];
        });
      }
    }
  }
  CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
}

- (void)dealloc {
  //TODO: move _condition release unbind
  [_condition release];
  _condition = nil;
  _delegate = nil;
	if (_audioQueue != NULL) {
    [self unbind];
	}
  [_emptyBuffers release];
  [_usedBuffers release];
	[super dealloc];
}


- (id)initWithDelegate:(id<BTAudioQueueDelegate>) delegate {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  self = [super init];
  if (self) {
    
    _delegate = delegate;
    _emptyBuffers = [[NSMutableArray arrayWithCapacity:kNumAQBufs] retain];
    _usedBuffers = [[NSMutableArray arrayWithCapacity:kNumAQBufs] retain];
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

- (void)failWithError:(BTAudioQueueErrorCode)btQueueError status:(OSStatus) osStatus {
  if (_delegate && [_delegate respondsToSelector:@selector(audioQueue:didError:status:)]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [_delegate audioQueue:self didError:btQueueError status:osStatus];
    });
  }
}

- (void)bind {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  NSAssert((_audioQueue == NULL),@"_audioQueue is already bound");
  CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
  if (_condition== nil) {
      _condition = [[NSCondition alloc] init];
  }

  if (_audioQueue == NULL && _delegate && [_delegate respondsToSelector:@selector(playerItemForAudioQueue:)]) {
    BTPlayerItemInternal *item = [_delegate playerItemForAudioQueue:self];
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
      if (status != noErr) {
        [self failWithError:BTAudioQueueErrorInitQueue status:status];
      }
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
        if (status != noErr) {
          [self failWithError:BTAudioQueueErrorInitBuffer status:status];
        }
        _inuse[i] = NO;
        BTBufferProxy *bfProxy = [[BTBufferProxy alloc] init];
        bfProxy.buffer = _buffers[i];
        [_emptyBuffers addObject:bfProxy];
        [bfProxy release];
      }
      
      AudioQueueSetParameter (_audioQueue, kAudioQueueParam_Volume, 1.0);
      _currentFillBufferIndex = 0;
      _bufCountInQueue = 0;
    }
  }
  CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
}

- (BOOL)isBound {
  return (_audioQueue != nil);
}

//TODO: 这里的逻辑需要rework
- (OSStatus)start {
  CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  //NSAssert(_audioQueue!=nil, nil);
  OSStatus status = noErr;
  if (_audioQueue) {
    if (_queueStatus == BTAudioQueueStatusStopped) {
      _queueStatus = BTAudioQueueStatusStarting;
      status = AudioQueueStart(_audioQueue, NULL);
      if (status != noErr) {
        [self failWithError:BTAudioQueueErrorStart status:status];
      }
    } else if (_queueStatus == BTAudioQueueStatusStarting){
      _queueStatus = BTAudioQueueStatusStarted;
    } else if (_queueStatus == BTAudioQueueStatusPaused) {
      _queueStatus = BTAudioQueueStatusStarted;
      status = AudioQueueStart(_audioQueue, NULL);
      if (status != noErr) {
        [self failWithError:BTAudioQueueErrorStart status:status];
      }
    }
  }
  CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
  return status;
}

- (OSStatus)pause {
  CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  OSStatus status = noErr;
  if (_audioQueue) {
    _queueStatus = BTAudioQueueStatusPaused;
    status = AudioQueuePause(_audioQueue);
  }
    CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
	return status;
}

- (OSStatus)endOfStream {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  OSStatus status = noErr;
  if (_audioQueue) {
    if (_queueStatus == BTAudioQueueStatusStopping) {//TODO: Buffer Drive时，这里有问题，availableDataLength = 0时， writeData可能不会再进来了
      if ([self isEmpty]) {
        [self pause];
        if (_delegate && [_delegate respondsToSelector:@selector(audioQueuePlaybackIsComplete:)]) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate audioQueuePlaybackIsComplete:self];
          });
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
  CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  [_emptyBuffers release];
  _emptyBuffers = nil;
  [_usedBuffers release];
  _usedBuffers = nil;
  _delegate = nil;
  OSStatus status = noErr;
  [_condition release];
  _condition = nil;
	if (_audioQueue != NULL) {
    status = AudioQueueRemovePropertyListener(_audioQueue, kAudioQueueProperty_IsRunning, propertyChangeIsRunning, self);
    status = AudioQueueFlush(_audioQueue);
    status = AudioQueueStop(_audioQueue, true);
		status = AudioQueueDispose(_audioQueue, true);
    _queueStatus = BTAudioQueueStatusStopped;
    _audioQueue = NULL;
    
	}
  CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
  return status;
}

- (OSStatus)reset {
    CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  OSStatus status = noErr;
  if (_audioQueue) {
    status = AudioQueueReset(_audioQueue);
  }
    CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
  return status;
}

- (OSStatus)getCurrentTime:(AudioTimeStamp *)outTimeStamp discontinuity:(Boolean *)outTimelineDiscontinuity {
  //NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
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
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  return (_bufCountInQueue == kNumAQBufs);
}

- (BOOL)isEmpty {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  return (_bufCountInQueue == 0);
}

//- (AudioQueueBufferRef)currentFillBuffer {
//  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
//  return _buffers[_currentFillBufferIndex];
//}

- (AudioQueueBufferRef)currentFillBuffer {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  AudioQueueBufferRef buffer = NULL;
  if ([_emptyBuffers count]) {
    buffer = ((BTBufferProxy*)[_emptyBuffers objectAtIndex:0]).buffer;
  }
  return buffer;
}

- (void)fileBufferByteCount:(UInt32)byteCount packetCount:(UInt32)packetCount data:(const void *)inputData packetDescs:(AudioStreamPacketDescription *)packetDescs {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  if (_audioQueue == NULL) {// || _queueStatus == BTAudioQueueStatusStopped) {
    return;
  }
  if (packetDescs) { //the following code assumes we're streaming VBR data
		for (int i = 0; i < packetCount && _audioQueue; ++i) { //TODO: 有托动操作时，这里的for需要及时结束，这里可能是会造成混音的地方
      //TODO: for 是否放在外面会更好？
			SInt64 packetOffset = packetDescs[i].mStartOffset;
			SInt64 packetSize   = packetDescs[i].mDataByteSize;
			SInt64 bufSpaceRemaining;

      // If the audio was terminated before this point, then
      // exit.
      //      if ([self isFinishing]){
      //        return;
      //      }
      
      if (packetSize > _packetBufferSize) {
        [self failWithError:BTAudioQueueErrorBufferTooSmall status:noErr];
        return;
      }
      
      bufSpaceRemaining = _packetBufferSize - _bytesFilled;
      
      
			// if the space remaining in the buffer is not enough for this packet, then enqueue the buffer.
			if (bufSpaceRemaining < packetSize)  {
        AudioQueueBufferRef  fillBuf = [self currentFillBuffer];
        NSAssert(fillBuf!=NULL, @"currentFillBuffer = NULL");
				[self enqueueBuffer:fillBuf];
        //fillBuf = NULL;
      }
			
      
      // If the audio was terminated while waiting for a buffer, then
      // exit.
      if (_audioQueue == NULL) {
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
      NSAssert(fillBuf!=NULL, @"currentFillBuffer = NULL");
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
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);

  //  if ([self isFinishing]){
  //    return;
  //  }
//  if (self.status == BTAudioQueueStatusStopping || self.status == BTAudioQueueStatusPaused) {
//    return;
//  }

  OSStatus status;
  
  if (_bufCountInQueue == kNumAQBufs) {
    return;
  }
  if (_packetsFilled) {
    status = AudioQueueEnqueueBuffer(_audioQueue, filledBuffer, _packetsFilled, _packetDescs);
  } else {
    status = AudioQueueEnqueueBuffer(_audioQueue, filledBuffer, 0, NULL);
  }
  //status = -66686 = kAudioQueueErr_BufferEmpty, bufferDidEmpty没有回调
  if (status!=noErr) {
    [self failWithError:BTAudioQueueErrorEnqueueBuffer status:status];
    return;
  }
  _inuse[_currentFillBufferIndex] = YES;
  //CVLog(BTDFLAG_AUDIO_QUEUE,@"enqueueBuffer _currentFillBufferIndex: = %d", _currentFillBufferIndex);
  [self moveToNextEmptyBuffer];

  if ([_emptyBuffers count] > 0) {
    [_usedBuffers addObject:[_emptyBuffers objectAtIndex:0]];
    [_emptyBuffers removeObjectAtIndex:0];
  }
  _bufCountInQueue++;
//  CVLog(BTDFLAG_AUDIO_QUEUE,@"enqueueBuffer _bufCountInQueue: = %d", _bufCountInQueue);
//CVLog(BTDFLAG_AUDIO_QUEUE,@"            _usedBuffers count: = %d", [_usedBuffers count]);
//CVLog(BTDFLAG_AUDIO_QUEUE,@"           _emptyBuffers count: = %d", [_emptyBuffers count]);
  
  if (_bufCountInQueue == kNumAQBufs - 1) {// || _queueStatus == BTAudioQueueStatusStopping) {
    if (_queueStatus != BTAudioQueueStatusStarting && _queueStatus != BTAudioQueueStatusStarted) {
      //UInt32 outNumberOfFramesPrepared;
      //OSStatus status = AudioQueuePrime (_audioQueue,0,&outNumberOfFramesPrepared);
      //CDLog(BTDFLAG_AUDIO_QUEUE,@"[outNumberOfFramesPrepared = %ld", outNumberOfFramesPrepared);
      if (_delegate && [_delegate respondsToSelector:@selector(audioQueueIsFull:)]) {
        [_delegate audioQueueIsFull:self];
      }
    }
  }
  if (_condition) {
    [_condition lock];

    
    //  static int testflag = 0;
    //  testflag++;
    //  CDLog(BTDFLAG_AUDIO_QUEUE,@"[             testflag: %d",testflag);
    //	while (_inuse[_currentFillBufferIndex]||testflag>50) {//_inuse[_currentFillBufferIndex])  {self.status == BTAudioQueueStatusPaused ||
    //    if (self.status == BTAudioQueueStatusStopping ||self.status == BTAudioQueueStatusStopped || self.status == BTAudioQueueStatusPaused) {
    //      CDLog(BTDFLAG_AUDIO_QUEUE,@"[_queueStatus:%d       break: %d",_queueStatus, _currentFillBufferIndex);
    //      break;
    //    }
    //    CDLog(BTDFLAG_AUDIO_QUEUE,@"[_condition       wait: %d",_currentFillBufferIndex);
    //    [_condition wait];
    //  }
    //  CVLog(BTDFLAG_AUDIO_QUEUE,@"[_condition after wait: %d",_currentFillBufferIndex);
    if (_emptyBuffers != nil && [_emptyBuffers count] == 0) {
      //CDLog(BTDFLAG_AUDIO_QUEUE,@"[_condition       wait: %d",_currentFillBufferIndex);
      if (_queueStatus == BTAudioQueueStatusStopping || _queueStatus == BTAudioQueueStatusStopped || _queueStatus == BTAudioQueueStatusPaused) {
        NSAssert(YES, @"");
      } else {
        [_condition wait];
      }
    }
    [_condition unlock];
  }

  /*
   造成死锁的情况:
   每次Bind后，_bufCountInQueue达到kNumAQBufs后，再start，然后直接Wait住了。
   unbind的代码没完全走完，就走bind的部分了。
   */
  
  
  
  
  //[self waitUntilBufferEmpty];
}

- (void)bufferDidEmpty:(AudioQueueBufferRef)bufferRef {
//  CDLog(BTDFLAG_AUDIO_QUEUE,@"");
  if (_condition) {
    [_condition lock];
    [_emptyBuffers addObject:[_usedBuffers objectAtIndex:0]];
    [_usedBuffers removeObjectAtIndex:0];
    _bufCountInQueue--;
    //CVLog(BTDFLAG_AUDIO_QUEUE,@"_bufCountInQueue-- = %d bufIndex:%d", _bufCountInQueue, bufIndex);
    [_condition broadcast];
    [_condition unlock];
  }
}


- (void) waitUntilBufferEmpty {
  // wait until next buffer is not in use
  [_condition lock];
  
	while (_inuse[_currentFillBufferIndex]) {//_inuse[_currentFillBufferIndex])  {self.status == BTAudioQueueStatusPaused ||
    //TODO: check
//    if (self.status == BTAudioQueueStatusStopping ||self.status == BTAudioQueueStatusStopped || self.status == BTAudioQueueStatusPaused) {
//      break;
//    }
    CVLog(BTDFLAG_AUDIO_QUEUE,@"[_condition       wait: %d",_currentFillBufferIndex);
    [_condition wait];
  }
  CVLog(BTDFLAG_AUDIO_QUEUE,@"[_condition after wait: %d",_currentFillBufferIndex);
  [_condition unlock];
}

- (void)moveToNextEmptyBuffer {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  // go to next buffer
  if (++_currentFillBufferIndex >= kNumAQBufs) {
    _currentFillBufferIndex = 0;
  }
  _bytesFilled = 0;		// reset bytes filled
  _packetsFilled = 0;		// reset packets filled
}

@end
