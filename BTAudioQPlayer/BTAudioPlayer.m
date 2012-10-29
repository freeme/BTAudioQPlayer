//
//  AudioPlayer.m
//

#import "BTAudioPlayer.h"
#import <dispatch/dispatch.h>

@interface BTAudioPlayer (Private)

@property (readwrite) BTAudioPlayerStatus status;

- (void)writeData;
- (void)cancel;

@end

@implementation BTAudioPlayer
@synthesize status = _playStatus;
void RunLoopSourcePerformRoutine (void *info);

void RunLoopSourcePerformRoutine (void *info) {
  if (info != NULL && [(id)info isKindOfClass:[BTAudioPlayer class]]) {
    BTAudioPlayer*  player = (BTAudioPlayer*)info;
    if ([player respondsToSelector:@selector(writeData)]) {
      [player writeData];
    }
  }
}

- (void)dealloc {
	[self cancel];
	[super dealloc];
}

- (id)initPlayerWithURL:(NSURL *)url delegate:(id<BTAudioPlayerDelegate>) aDelegate {
	self = [super init];
  if (self) {
    _delegate = aDelegate;
    _url = [url retain];
  }
	return self;
}

- (void)main {
  CDLog(BTDFLAG_DEFAULT,@"");
  _runLoop = CFRunLoopGetCurrent();
  CFRunLoopSourceContext context = {0, self, NULL, NULL, NULL, NULL, NULL, NULL, NULL, &RunLoopSourcePerformRoutine};
  _runLoopSource = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
  CFRunLoopAddSource(_runLoop, _runLoopSource, kCFRunLoopDefaultMode);
  
  
  _cacheData = [[NSMutableData dataWithCapacity:0] retain];

  _request = [[BTAudioRequest alloc] initRequestWithURL:_url delegate:self];
  [_request start];
  
  //_audioQueue = [[BTAudioQueue alloc] initQueueWithDelegate:self];
  _fileStream = [[BTAudioFileStream alloc] initFileStreamWithDelegate:self];
  [_fileStream open];
  _playStatus = BTAudioPlayerStatusStop;
  
  BOOL isRun = YES;
  
  
  while (isRun && ![_thread isCancelled]) {

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    @try {
      CFRunLoopRun();
    }@catch (NSException *exception) {
      
    }@finally {
      
    }
    [pool drain];
  }


  
}

- (void)error {
	[self cancel];
  //TODO: 
	//_delegate performSelectorOnMainThread
}

- (void)seekToTime:(Float64)newSeekTime {
  self.status = BTAudioPlayerStatusWaiting;
  [self performSelector:@selector(internalSeekToTime:) onThread:_thread withObject:[NSNumber numberWithFloat:newSeekTime] waitUntilDone:NO];
}

// internalSeekToTime:
//
// Called from our internal runloop to reopen the stream at a seeked location
//
- (void) internalSeekToTime:(NSNumber*)newSeekTime {
  [_cacheData setLength:0];
  [_fileStream setSeekTime:[newSeekTime floatValue]];
  [_fileStream close];
  [_fileStream open];
  [_audioQueue stop];
  self.status = BTAudioPlayerStatusStop;
  if (_request) {
    [_request cancel];
    [_request release];
    _request = nil;
  }
  _request = [[BTAudioRequest alloc] initRequestWithURL:_url delegate:self];
  [_request setRequestRange:_fileStream.seekBtyeOffset end:_fileStream.fileLength - 1];
  [_request start];
}

#pragma mark -
#pragma mark RunLoop Source
- (void) driveRunLoop {
  //CDLog(BTDFLAG_AUDIO_PLAYER, @" *************** ");
  CFRunLoopSourceSignal(_runLoopSource);
  CFRunLoopWakeUp(_runLoop);
}

#pragma mark -
#pragma mark BTAudioRequestDelegate
- (void)audioRequestDidStart:(BTAudioRequest *)request {
  self.status = BTAudioPlayerStatusWaiting;
  CILog(BTDFLAG_NETWORK, @"-----------------");
}

- (void)audioRequestDidConnectOK:(BTAudioRequest *)request contentLength:(NSInteger)contentLength {
  CILog(BTDFLAG_NETWORK, @"statusCode = 200");
  _fileStream.fileLength = contentLength;
  self.status = BTAudioPlayerStatusWaiting;

}

- (void)audioRequest:(BTAudioRequest *)request didReceiveData:(NSData *)data {
  //CDLog(BTDFLAG_NETWORK, @"data length = %d", [data length]);
  [_cacheData appendData:data];
//	if ([_fileStream parseBytes:data] != noErr) {
//		[self error];
//	}
  [self driveRunLoop];
}

- (void)audioRequest:(BTAudioRequest *)request downloadProgress:(float)progress {
  CVLog(BTDFLAG_NETWORK,@"progress = %.2f", progress);
  if (_delegate && [_delegate respondsToSelector:@selector(audioPlayer:downloadProgress:)]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [_delegate audioPlayer:self downloadProgress:progress];
    });
  }
}

- (void)audioRequestDidFinish:(BTAudioRequest *)request {
  CILog(BTDFLAG_NETWORK, @"--player status = %d",_playStatus);
//	if (!audioIsReadyToPlay) {
//		[self error];
//	}
}

- (void)audioRequest:(BTAudioRequest *)request didFailWithError:(NSError*)error {
  CELog(BTDFLAG_NETWORK, @"BTAudioRequest didFailWithError(%i)-%@:%@", error.code,[error localizedDescription],[[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
  dispatch_async(dispatch_get_main_queue(), ^{
    //TODO: 错误处理
  });
}
#pragma mark -

- (void)audioFileStream:(BTAudioFileStream *)stream foundMagicCookie:(NSData *)cookie {
	// if an error happens here, it may be recoverable so we let it slide...
	[_audioQueue setMagicCookie:cookie];
}

- (void)audioFileStream:(BTAudioFileStream *)stream isReadyToProducePacketsWithASBD:(AudioStreamBasicDescription)asbd {
  if (_audioQueue == nil) {
    packetBufferSize = [_fileStream getPacketBufferSize];
    _audioQueue = [[BTAudioQueue alloc] initWithASBD:asbd packetBufferSize:packetBufferSize];
    if (_audioQueue == nil) {
      //TODO: 容错处理
      
    } else {
      _audioQueue.delegate = self;
      _discontinuity = YES;
    }
	}
}


- (void)audioFileStream:(BTAudioFileStream *)stream callBackWithByteCount:(UInt32)byteCount packetCount:(UInt32)packetCount data:(const void *)inputData packetDescs:(AudioStreamPacketDescription *)packetDescs {
  if (_discontinuity) {
    _discontinuity = NO;
  }
  [_audioQueue fileBufferByteCount:byteCount packetCount:packetCount data:inputData packetDescs:packetDescs];
}

#pragma mark -
#pragma mark AudioQueue Callback
//Callback from AQClient thread
- (void)audioQueue:(BTAudioQueue *)audioQueue isDoneWithBuffer:(AudioQueueBufferRef)bufferRef {
  //CDLog(BTDFLAG_AUDIO_QUEUE,@">>>");
  [self driveRunLoop];
}

//Callback from AQClient thread
- (void)audioQueuePlaybackIsStarting:(BTAudioQueue *)audioQueue {
  CDLog(BTDFLAG_AUDIO_QUEUE, @"");
  self.status = BTAudioPlayerStatusPlaying;
}
//Callback from AQClient thread
- (void)audioQueuePlaybackIsComplete:(BTAudioQueue *)audioQueue {
  CDLog(BTDFLAG_AUDIO_QUEUE, @"<<<<<<<<<<<-->>>>>>>>>>>>");
  self.status = BTAudioPlayerStatusStop;
  
  _audioQueue.delegate = nil;
	[_audioQueue release];
  _audioQueue = nil;
}

- (void)audioQueueIsFull:(BTAudioQueue *)audioQueue {
  CDLog(BTDFLAG_AUDIO_QUEUE, @"--");
  if (self.status == BTAudioPlayerStatusWaiting) {
    //[_audioQueue start];
    self.status = BTAudioPlayerStatusPlaying;
  }
}
#pragma mark -
#pragma mark Drive Data

- (void)writeData {
  CDLog(BTDFLAG_AUDIO_PLAYER, @"[_audioQueue isFull]:%d", [_audioQueue isFull]);
  if ([_audioQueue isFull]||_fileStream.fileLength == 0||[_thread isCancelled]) {
    return;
  }
  int kAQWriteDataSzie = kAQDefaultBufSize * 4;
  UInt8 bytes[kAQWriteDataSzie];
  CFIndex readLength = 0;
  //
  // Read the bytes from the stream
  //
  
  int data_len = [_cacheData length];
  //TODO:
  //_byteWriteIndex = seekByteOffset;
  if ((data_len < _fileStream.fileLength && _byteWriteIndex >= data_len)|| data_len <= 0) {
    //判断当前的播放状态，决定是否要暂停播放
    if (_byteWriteIndex < _fileStream.fileLength && _playStatus == BTAudioPlayerStatusPlaying) {
      [_audioQueue pause];
      self.status = BTAudioPlayerStatusWaiting;
    }
    CDLog(BTDFLAG_AUDIO_PLAYER, @"BTDFLAG_AUDIO_PLAYER =============2");
    return;
  }
  if (_byteWriteIndex >= _fileStream.fileLength &&  _playStatus == BTAudioPlayerStatusPlaying) {
    [_audioQueue endOfStream];
//    if (self.progress >= self.duration - 0.1) {
//      self.state = AS_STOPPING;
//      stopReason = AS_STOPPING_EOF;
//      err = AudioQueueStop(audioQueue, true);
//      if (err)
//      {
//        [self failWithErrorCode:AS_AUDIO_QUEUE_STOP_FAILED];
//        return;
//      }
//    }
  }
  readLength = ((data_len - _byteWriteIndex >= kAQWriteDataSzie) ? kAQWriteDataSzie : (data_len-_byteWriteIndex));
  //    if (_fileStream && _fileStream.fileLength - _byteWriteIndex >= kAQWriteDataSzie && readLength < kAQWriteDataSzie) {
  //      //如果当前数据还不够kAQDefaultBufSize这么大，并且数据还没下载完，就等下次
  //      CDLog(BTDFLAG_AUDIO_PLAYER, @"BTDFLAG_AUDIO_PLAYER =============3");
  //      return;
  //    }
  
  uint8_t *readBytes = (uint8_t *)[_cacheData mutableBytes];
  
  readBytes += _byteWriteIndex; // instance variable to move pointer
  
  (void)memcpy(bytes, readBytes, readLength);
  
  
  _byteWriteIndex += readLength;
  //CDLog(BTDFLAG_AUDIO_PLAYER, @"readLength = %d, _byteWriteIndex = %d", readLength,_byteWriteIndex);
  //CDLog(BTDFLAG_AUDIO_PLAYER, @"buffersUsed:%d fillBufferIndex:%d", _bufferState.buffersUsed, _bufferState.fillBufferIndex);
  //seekByteOffset = _byteIndex;
  
  if (_fileStream) {
    if (_discontinuity) {
      [_fileStream parseBytes:bytes dataSize:readLength flags:kAudioFileStreamParseFlag_Discontinuity];
    } else {
      [_fileStream parseBytes:bytes dataSize:readLength flags:0];
    }
  }

}




#pragma mark -
#pragma mark BTAudioPlayer Control
- (void)start {
  CDLog(BTDFLAG_AUDIO_PLAYER,@">>>>>>>>>>start");
  _thread = [[NSThread alloc] initWithTarget:self selector:@selector(main) object:nil];
  [_thread setName:@"INTH"];
  [_thread start];
}

- (void)stop {
  
  //TODO: waitUntilDone:YES just for test
  [self performSelector:@selector(cancel) onThread:_thread withObject:nil waitUntilDone:YES];
  
  [_thread cancel];
  [_thread release];
  _thread = nil;
}

- (BOOL)paused {
	return (_playStatus == BTAudioPlayerStatusPaused);
}

- (void)setPaused:(BOOL)paused {
  CDLog(BTDFLAG_AUDIO_PLAYER,@">>>>>>>>>>setPaused:%d",paused);
	if (paused == (_playStatus == BTAudioPlayerStatusPaused)) {
		return;
	}

	if (paused) {
    self.Status = BTAudioPlayerStatusPaused;
		[_audioQueue pause];
	} else {
    self.Status = BTAudioPlayerStatusPlaying;
		[_audioQueue start];
	}
}

- (void)setStatus:(BTAudioPlayerStatus)status {
  if (_playStatus != status) {
//    [self willChangeValueForKey:@"status"];
    _playStatus = status;
//    [self didChangeValueForKey:@"status"];
    if (_delegate) {
      switch (_playStatus) {
        case BTAudioPlayerStatusWaiting:
          dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate audioPlayerWaiting:self];
          });
          break;
        case BTAudioPlayerStatusPlaying:
          dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate audioPlayerStarted:self];
          });
          break;
        case BTAudioPlayerStatusPaused:
          dispatch_async(dispatch_get_main_queue(), ^{
            //TODO: BTAudioPlayerStatusPaused
          });
          break;
        case BTAudioPlayerStatusStop:
          dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate audioPlayerFinished:self];
          });
          break;
        default:
          break;
      }

    }
  }
   //[self setValue:[NSNumber numberWithInt:status] forKey:@"status"];
}

- (void)cancel {
  CDLog(BTDFLAG_AUDIO_PLAYER,@">>>>>>>>>>cancel");
  
  _request.delegate = nil;
  [_request cancel];
	[_request release];
  _request = nil;

  [_audioQueue stop];

  
  _fileStream.delegate = nil;
	[_fileStream release];
	_fileStream = nil;
  
  _delegate = nil;
  
  [_cacheData release];
  _cacheData = nil;
  
  [_url release];
  _url = nil;
  
  CFRunLoopRemoveSource(_runLoop, _runLoopSource, kCFRunLoopDefaultMode);
  CFRelease(_runLoopSource);
  

  

  
	// nil out our references so that any further operations
	// (such as cancel during dealloc) don't cause errors.

}

- (float)playProgress {

  AudioTimeStamp queueTime;
  Boolean discontinuity;
  
  OSStatus status = [_audioQueue getCurrentTime:&queueTime discontinuity:&discontinuity];
  float progress = -1;
  const OSStatus AudioQueueStopped = 0x73746F70; // 0x73746F70 is 'stop'
  if (status == AudioQueueStopped) {
    CVLog(BTDFLAG_AUDIO_PLAYER, @"AudioQueueStopped");
    progress = -2;
  } else if (status) {
    CVLog(BTDFLAG_AUDIO_PLAYER, @"status = %ld", status);
    progress = -3;
  } else {
    progress = _fileStream.seekTime + queueTime.mSampleTime / _fileStream.sampleRate;
    if (progress < 0.0) {
      progress = 0.0;
    }
  }
  //CDLog(BTDFLAG_AUDIO_PLAYER, @"progress = %.3f", progress);

	return progress;
}
//
// duration
//
// Calculates the duration of available audio from the bitRate and fileLength.
//
// returns the calculated duration in seconds.
//
- (float)duration {
  return [_fileStream duration];
}



#pragma mark -

@end
