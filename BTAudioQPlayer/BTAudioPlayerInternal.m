//
//  AudioPlayer.m
//

#import "BTAudioPlayerInternal.h"
#import <dispatch/dispatch.h>
#import "BTAudioRequest.h"
#import "BTAudioFileStream.h"
#import "BTAudioQueue.h"
#import "BTPlayerItemInternal.h"
#import "BTRunLoopSource.h"
#import "BTAudioPlayer.h"
#import "AudioPlayerUtil.h"
#define CMD_PLAY @"play"
#define CMD_SEEK @"seek"

@interface BTAudioPlayerInternal (Private)

@property (readwrite) BTAudioPlayerStatus status;

- (void)writeData;
- (void)cancel;
- (void)_playInternal;
- (void)_seekInternal;
@end

@implementation BTAudioPlayerInternal

@synthesize status = _playStatus;
void RunLoopSourcePerformRoutine (void *info);
void RunLoopSourcePlay (void *info);
void RunLoopSourceSeek (void *info);
void RunLoopSourceSeekSchedule(void *info, CFRunLoopRef rl, CFStringRef mode);
void RunLoopSourceSeekCancel(void *info, CFRunLoopRef rl, CFStringRef mode);

void RunLoopSourcePerformRoutine (void *info) {
  if (info != NULL && [(id)info isKindOfClass:[BTAudioPlayerInternal class]]) {
    BTAudioPlayerInternal*  player = (BTAudioPlayerInternal*)info;
    if ([player respondsToSelector:@selector(writeData)]) {
      [player writeData];
    }
  }
}

void RunLoopSourcePlay (void *info) {
  if (info != NULL && [(id)info isKindOfClass:[BTAudioPlayerInternal class]]) {
    BTAudioPlayerInternal*  player = (BTAudioPlayerInternal*)info;
    if ([player respondsToSelector:@selector(_playInternal)]) {
      [player _playInternal];
    }
  }
}

void RunLoopSourceSeekSchedule(void *info, CFRunLoopRef rl, CFStringRef mode) {
  //CDLog(BTDFLAG_DEFAULT,@"");
}

void RunLoopSourceSeekCancel(void *info, CFRunLoopRef rl, CFStringRef mode) {
  //CDLog(BTDFLAG_DEFAULT,@"");
}
void RunLoopSourceSeek (void *info) {
  if (info != NULL && [(id)info isKindOfClass:[BTAudioPlayerInternal class]]) {
    BTAudioPlayerInternal*  player = (BTAudioPlayerInternal*)info;
    if ([player respondsToSelector:@selector(_seekInternal)]) {
      [player _seekInternal];
    }
  }
}

- (void)dealloc {
	//[self cancel];
  
  _delegate = nil; 
  [_playerItem release];
	[super dealloc];
}

#pragma mark BTAudioPlayerInternale Thread Control
- (void)start {
  NSAssert([NSThread isMainThread],nil);
  _thread = [[NSThread alloc] initWithTarget:self selector:@selector(main) object:nil];
  [_thread setName:@"INTH"];
  [_thread start];
}

- (void)stop {
  NSAssert([NSThread isMainThread],nil);
  //TODO: waitUntilDone:YES just for test
  
  [self performSelector:@selector(cancel) onThread:_thread withObject:nil waitUntilDone:YES];
  [_thread cancel];
  [_thread release];
  _thread = nil;
}
#pragma mark -
#pragma mark -
#pragma mark New API
- (id)initWithAudioPlayer:(BTAudioPlayer*) audioPlayer {
  self = [super init];
  if (self) {
    _outsidePlayer = audioPlayer;
  }
  return self;
}

- (id)initWithURL:(NSURL *)URL audioPlayer:(BTAudioPlayer*) audioPlayer;{
  self = [super init];
  if (self) {
    _url = [URL retain];
    _outsidePlayer = audioPlayer;
    [_outsidePlayer setValue:[NSNumber numberWithInt:3] forKey:@"status"];
  }
  return self;
}
- (id)initWithPlayerItem:(BTPlayerItem *)item audioPlayer:(BTAudioPlayer*) audioPlayer;{
  self = [super init];
  if (self) {
    _currentItem = [item retain];
    _outsidePlayer = audioPlayer;
  }
  return self;
}

- (void)setURL:(NSURL*)url {
  if (url && _url != url) {
    [_url release];
    _url = [url retain];
  }
}
- (void)play {
  NSAssert([NSThread isMainThread],nil);
//  if ([self isPaused]) {
//    [self setPaused:NO];
//  } else {
//    if (self.status == BTAudioPlayerStatusStop) {
//      [_btRunLoopSource addCommand:CMD_PLAY];
//      [_btRunLoopSource fireAllCommands];
//    }
//  }
  [self performSelector:@selector(_playInternal) onThread:_thread withObject:nil waitUntilDone:NO];
}
//- (void)pause {
//  [self setPaused:YES];
//}

- (BOOL)paused {
  NSAssert([NSThread isMainThread],nil);
	return (_playStatus == BTAudioPlayerStatusPaused || _playStatus == BTAudioPlayerStatusStop);
}

- (void)setPaused:(BOOL)paused {
  NSAssert([NSThread isMainThread],nil);
  CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
  if (self.error) {
    return;
  }
	if (paused == [self paused]) {
		return;
	}
  
	if (paused) {
//    [_audioQueue pause];
//    self.status = BTAudioPlayerStatusPaused;
    //[self performSelector:@selector(pausePlayer) onThread:_thread withObject:nil waitUntilDone:NO];
    [self performSelectorOnInternalThread:@selector(pausePlayer) withObject:nil];
	} else {
    [self performSelectorOnInternalThread:@selector(startPlayer) withObject:nil];
    //[self performSelector:@selector(startPlayer) onThread:_thread withObject:nil waitUntilDone:NO];
	}
  CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
}

- (void) performSelectorOnInternalThread:(SEL)selector withObject:(id)arg {
  NSDictionary *dict = nil;
  if (arg) {
    dict = [NSDictionary dictionaryWithObjectsAndKeys:NSStringFromSelector(selector),arg,@"SEL",@"OBJ", nil];
  } else {
    dict = [NSDictionary dictionaryWithObjectsAndKeys:NSStringFromSelector(selector),@"SEL", nil];
  }
  
  [self performSelector:@selector(runOnInternalThread:) onThread:_thread withObject:dict waitUntilDone:NO];
}

- (void) runOnInternalThread:(id)arg  {
  [NSObject cancelPreviousPerformRequestsWithTarget:self];
  NSDictionary *dict = (NSDictionary*)arg;
  SEL selector = NSSelectorFromString([dict objectForKey:@"SEL"]);
  id object = [dict objectForKey:@"OBJ"];
  [self performSelector:selector withObject:object afterDelay:0.1];
}


//- (void)resetPlayerAndWait {
//  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
//  [_playerItem reset];
//  [_audioQueue bind];
//  //[_audioQueue start];
//  self.status = BTAudioPlayerStatusWaiting;
//}

//TODO: make more clearly
- (void)startPlayer {
  DLog(@"self.status = %d queue.status = %d", self.status, _audioQueue.status);
    CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
  //NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
//  if (self.status == BTAudioPlayerStatusStop) {
//    [self resetPlayerAndWait];
//  }else {
  [self initQueueIfNeed];
  [_audioQueue start];
    self.status = BTAudioPlayerStatusPlaying;
//  }
    CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
}

- (void) initQueueIfNeed {
  if (_audioQueue == nil) {
    _audioQueue = [[BTAudioQueue alloc] initWithDelegate:self];
    [_audioQueue bind];
  }
}

- (void)waitPlayer {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  [_audioQueue pause];
  self.status = BTAudioPlayerStatusWaiting;
}

- (void)pausePlayer {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
  [_audioQueue pause];
  self.status = BTAudioPlayerStatusPaused;
  CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
}

- (void)stopPlayer {
    CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
  [_audioQueue unbind];
  [_audioQueue release];
  _audioQueue = nil;
  [_playerItem reset];
  self.status = BTAudioPlayerStatusStop;
    CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
}
#pragma mark -

- (void)play:(NSURL*)url {
  CDLog(BTDFLAG_DEFAULT,@"");
  if (url && _url != url) {
    [_url release];
    _url = [url retain];

    [_btRunLoopSource addCommand:CMD_PLAY];
    [_btRunLoopSource fireAllCommands];
    //[self driveRunLoopSourcePlay];
  }
}

- (void)_playInternal {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
  self.error = nil;
  [_audioQueue unbind];
  [_audioQueue release];
  _audioQueue = nil;
  [_playerItem release];
  _playerItem = nil;
  
  _request.delegate = nil;
  [_request cancel];
  [_request release];
  _request = nil;
  
  _fileStream.delegate = nil;
  [_fileStream release];
  _fileStream = nil;
  
  self.status = BTAudioPlayerStatusStop;
  
  _fileStream = [[BTAudioFileStream alloc] initFileStreamWithDelegate:self];
  [_fileStream open];
  _playerItem = [[BTPlayerItemInternal alloc] initWithURL:_url];
  _request = [[BTAudioRequest alloc] initRequestWithURL:_url delegate:self];
  [_request start];

  CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
}


- (void)main {
  CDLog(BTDFLAG_DEFAULT,@"");

  _runLoop = CFRunLoopGetCurrent();
  _btRunLoopSource = [[BTRunLoopSource alloc] init];
  _btRunLoopSource.delegate = self;
  [_btRunLoopSource addToCurrentRunLoop];
  CFRunLoopSourceContext context = {0, self, NULL, NULL, NULL, NULL, NULL, NULL, NULL, &RunLoopSourcePerformRoutine};
  _runLoopSource = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
  CFRunLoopAddSource(_runLoop, _runLoopSource, kCFRunLoopDefaultMode);

  CFRunLoopSourceContext context1 = {0, self, NULL, NULL, NULL, NULL, NULL, NULL, NULL, &RunLoopSourcePlay};
  _runLoopSourcePlay = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context1);
  CFRunLoopAddSource(_runLoop, _runLoopSourcePlay, kCFRunLoopDefaultMode);
  
  CFRunLoopSourceContext context2 = {0, self, NULL, NULL, NULL, NULL, NULL, &RunLoopSourceSeekSchedule, &RunLoopSourceSeekCancel, &RunLoopSourceSeek};
  _runLoopSourceSeek = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context2);
  CFRunLoopAddSource(_runLoop, _runLoopSourceSeek, kCFRunLoopDefaultMode);
  
//  [_btRunLoopSource addCommand:CMD_PLAY];
//  [_btRunLoopSource fireAllCommands];
//  _playerItem = [[BTPlayerItem alloc] initWithURL:_url];
//  _request = [[BTAudioRequest alloc] initRequestWithURL:_url delegate:self];
//  [_request start];
//  //_audioQueue = [[BTAudioQueue alloc] initQueueWithDelegate:self];
//  _fileStream = [[BTAudioFileStream alloc] initFileStreamWithDelegate:self];
//  [_fileStream open];
  self.status = BTAudioPlayerStatusStop;
  
  _heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(writeData) userInfo:nil repeats:YES];
  
  while (_thread && ![_thread isCancelled]) {

    
    @try {
      //CDLog(BTDFLAG_AUDIO_PLAYER, @"Before CFRunLoopRun %d %d",[_thread isCancelled],_thread);

      NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
      //CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0e10, true);
            CFRunLoopRun();
      [pool drain];
      //CDLog(BTDFLAG_AUDIO_PLAYER, @"AFter CFRunLoopRun %d %d", [_thread isCancelled],_thread);
    }@catch (NSException *exception) {
      DLog(@"exception:%@", exception);
    }@finally {
      
    }
    
  }
  DLog(@"Thread Exit!------");
}

- (void)performCommand:(NSString *)command {
  if ([command isEqualToString:CMD_PLAY]) {
    [self _playInternal];
  } else if([command isEqualToString:CMD_SEEK]) {
    [self _seekInternal];
  }
}

//- (void)error {
//	[self cancel];
//  //TODO: 
//	//_delegate performSelectorOnMainThread
//}

- (void)seekToTime:(Float64)newSeekTime {
  CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
//  [_audioQueue pause];
//  [_audioQueue reset];
//  [_audioQueue pause];
//  self.status = BTAudioPlayerStatusWaiting;
  requestedSeekTime = newSeekTime;
//  [self driveRunLoopSourceSeek];
  [_btRunLoopSource addCommand:CMD_SEEK];
  [_btRunLoopSource fireAllCommands];
  CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
  //[self performSelector:@selector(_seekInternal) onThread:_thread withObject:nil waitUntilDone:NO];
  //[self performSelectorOnInternalThread:@selector(_seekInternal) withObject:nil];
}

//TODO: make it more simple
- (void) _seekInternal {
  CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  if (_playStatus != BTAudioPlayerStatusPlaying) {

    return;
  }
  Float64 nSeekTime = requestedSeekTime;
  if ([_playerItem calculatedBitRate] == 0.0 || _playerItem.expectedContentLength <= 0) {
		return;
	}
  if (nSeekTime > [_playerItem duration]) {
    nSeekTime = [_playerItem duration];
  }

  [_playerItem reset];
  [_audioQueue unbind];
  [_audioQueue release];
  _audioQueue = nil;

  [self initQueueIfNeed];


  self.status = BTAudioPlayerStatusWaiting;
  _playerItem.seekRequested = YES;
	//
	// Calculate the byte offset for seeking
	//
	_playerItem.seekByteOffset = _playerItem.dataOffset + (nSeekTime / [_playerItem duration]) * (_playerItem.expectedContentLength - _playerItem.dataOffset);

  // 拖动的位置不能超过下载进度，并且在预留出20个packet
	if (_playerItem.seekByteOffset > [_playerItem.cacheData length] - 20 * _playerItem.packetBufferSize) {
		_playerItem.seekByteOffset =[_playerItem.cacheData length] - 20 * _playerItem.packetBufferSize;
	}
  // 根据下载进度调整了拖动位置后，要重新计算seekTime
	nSeekTime = ((Float64)(_playerItem.seekByteOffset - _playerItem.dataOffset) / (_playerItem.expectedContentLength - _playerItem.dataOffset)) * [_playerItem duration];
	//
	// Store the old time from the audio queue and the time that we're seeking
	// to so that we'll know the correct time progress after seeking.
	//
	_playerItem.seekTime = nSeekTime;
	
	//
	// Attempt to align the seek with a packet boundary
	//
	double calculatedBitRate = [_playerItem calculatedBitRate];
	if (_playerItem.packetDuration > 0 && calculatedBitRate > 0) {
		UInt32 ioFlags = 0;
		SInt64 packetAlignedByteOffset;
		SInt64 seekPacket = floor(nSeekTime / _playerItem.packetDuration);
		//OSStatus err = AudioFileStreamSeek(_streamID, seekPacket, &packetAlignedByteOffset, &ioFlags);
    OSStatus err = [_fileStream seekWithPacketOffset:seekPacket outDataByteOffset:&packetAlignedByteOffset ioFlags:&ioFlags];
		if (!err && !(ioFlags & kAudioFileStreamSeekFlag_OffsetIsEstimated))
		{
			_playerItem.seekTime -= ((_playerItem.seekByteOffset - _playerItem.dataOffset) - packetAlignedByteOffset) * 8.0 / calculatedBitRate;
			_playerItem.seekByteOffset = packetAlignedByteOffset + _playerItem.dataOffset;
		}
	}
  _playerItem.currentTime = _playerItem.seekTime;

  _playerItem.byteWriteIndex = _playerItem.seekByteOffset;
  _playerItem.seekRequested = NO;
  
  [self driveRunLoop];
  CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
}

#pragma mark -
#pragma mark RunLoop Source
- (void) driveRunLoop {
  return;
  CFRunLoopSourceSignal(_runLoopSource);
  CFRunLoopWakeUp(_runLoop);
}

- (void) driveRunLoopSourcePlay {
  CFRunLoopSourceSignal(_runLoopSourcePlay);
  CFRunLoopWakeUp(_runLoop);
}

- (void) driveRunLoopSourceSeek {
  CFRunLoopSourceSignal(_runLoopSourceSeek);
  CFRunLoopWakeUp(_runLoop);
}
#pragma mark -
#pragma mark BTAudioRequestDelegate
- (void)audioRequestDidStart:(BTAudioRequest *)request {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  self.status = BTAudioPlayerStatusWaiting;
  //CDLog(BTDFLAG_AUDIO_FLOW, @">>>>>>>>");
}

- (void)audioRequestDidConnectOK:(BTAudioRequest *)request contentLength:(NSInteger)contentLength {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  //CDLog(BTDFLAG_AUDIO_FLOW, @">>>>>>>>contentLength:%d",contentLength);
  self.status = BTAudioPlayerStatusWaiting;
  _playerItem.expectedContentLength = contentLength;
}

- (void)audioRequest:(BTAudioRequest *)request didReceiveData:(NSData *)data {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  //CDLog(BTDFLAG_NETWORK, @"data length = %d", [data length]);
  [_playerItem appendData:data];
  [self driveRunLoop];
  
}

- (void)audioRequest:(BTAudioRequest *)request downloadProgress:(float)progress {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  CVLog(BTDFLAG_NETWORK ,@"progress = %.2f", progress);
  _playerItem.downloadProgress = progress;
}

- (void)audioRequestDidFinish:(BTAudioRequest *)request {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
}

- (void)audioRequest:(BTAudioRequest *)request didFailWithError:(NSError*)error {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  ELog(@"BTAudioRequest didFailWithError(%i)-%@:%@", error.code,[error localizedDescription],[[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
  self.error = error;
  [self stopPlayer];
}
#pragma mark -

- (void)audioFileStream:(BTAudioFileStream *)stream foundMagicCookie:(NSData *)cookie {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
	// if an error happens here, it may be recoverable so we let it slide...
	[_audioQueue setMagicCookie:cookie];
}

- (void)audioFileStream:(BTAudioFileStream *)stream isReadyToProducePacketsWithASBD:(AudioStreamBasicDescription)asbd {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
  if (_audioQueue == nil) {
    _playerItem.asbd = asbd;
    _playerItem.packetBufferSize = [stream getPacketBufferSize];
    CDLog(BTDFLAG_AUDIO_FLOW, @">>>>>>>>BTAudioQueue alloc");
    _playerItem.bitRate = [stream getBitRate];
    _playerItem.dataOffset = [stream getDataOffset];
    _playerItem.fileFormat = [stream getFileFormat];
    [self initQueueIfNeed];
	}
  CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
}


- (void)audioFileStream:(BTAudioFileStream *)stream callBackWithByteCount:(UInt32)byteCount packetCount:(UInt32)packetCount data:(const void *)inputData packetDescs:(AudioStreamPacketDescription *)packetDescs {
  CVLog(BTDFLAG_AUDIO_FLOW, @">>>>>>>>");
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  if (_playerItem.discontinuity) {
    _playerItem.discontinuity = NO;
  }
  if (packetDescs) {
		for (int i = 0; i < packetCount; ++i) {
			UInt64 packetSize = packetDescs[i].mDataByteSize;
      _playerItem.processedPacketsSizeTotal += packetSize;
      _playerItem.processedPacketsCount += 1;
    }
  }
  
  [_audioQueue fileBufferByteCount:byteCount packetCount:packetCount data:inputData packetDescs:packetDescs];
}

#pragma mark -
#pragma mark AudioQueue Callback

//Callback from AQClient thread -> change to Main thread
- (void)audioQueue:(BTAudioQueue *)audioQueue didError:(BTAudioQueueErrorCode)errorCode status:(OSStatus)osStatus {
  ELog(@"error = %d; status = %d", errorCode, osStatus);
  VERIFY_STATUS(osStatus);
  if (errorCode == BTAudioQueueErrorIsRunning) {
    //[self performSelector:@selector(stopPlayer) onThread:_thread withObject:nil waitUntilDone:NO];
    
  }
  NSError *error = [[NSError alloc] initWithDomain:BTAudioQueueErrorDomain code:errorCode userInfo:nil];
  self.error = error;
  [error release];
  [self performSelector:@selector(stopPlayer) onThread:_thread withObject:nil waitUntilDone:NO];
}

- (BTPlayerItemInternal*)playerItemForAudioQueue:(BTAudioQueue *)audioQueue {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  return _playerItem;
}

//Callback from AQClient thread -> change to Main thread
- (void)audioQueue:(BTAudioQueue *)audioQueue isDoneWithBuffer:(AudioQueueBufferRef)bufferRef {
  //CDLog(BTDFLAG_AUDIO_QUEUE,@">>>");
  //[self driveRunLoop];
}

//Callback from AQClient thread -> change to Main thread
- (void)audioQueuePlaybackIsStarting:(BTAudioQueue *)audioQueue {
    CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
  if (self.status == BTAudioPlayerStatusWaiting ||self.status == BTAudioPlayerStatusPlaying  ) {
    [self performSelector:@selector(startPlayer) onThread:_thread withObject:nil waitUntilDone:NO];
  }
    CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
}
//Callback from AQClient thread -> change to Main thread
- (void)audioQueuePlaybackIsComplete:(BTAudioQueue *)audioQueue {
    CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
  [self performSelector:@selector(stopPlayer) onThread:_thread withObject:nil waitUntilDone:NO];
//  self.status = BTAudioPlayerStatusStop; //TODO: fix bug, bad access when play another music
//  [_audioQueue unbind];
//  _audioQueue.delegate = nil;
//	[_audioQueue release];
//  _audioQueue = nil;
    CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
}
//Callback from INTH thread
- (void)audioQueueIsFull:(BTAudioQueue *)audioQueue {
    CDLog(BTDFLAG_AUDIO_FLOW, @"--S--");
  if (self.status == BTAudioPlayerStatusWaiting) { // 用户手动操作的pause,不能在此触发start
//    self.status = BTAudioPlayerStatusPlaying;
//    [_audioQueue start];
//    [self performSelector:@selector(stopPlayer) onThread:_thread withObject:nil waitUntilDone:NO];
    [self startPlayer];
  }
    CDLog(BTDFLAG_AUDIO_FLOW, @"--E--");
}

#pragma mark -
#pragma mark Drive Data

- (void)writeData {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  //CDLog(BTDFLAG_AUDIO_PLAYER, @"<<<<bufCountInQueue = %d; _playStatus = %d; queue.status = %d", _audioQueue.bufCountInQueue, _playStatus, _audioQueue.status);
  if ( self.status == BTAudioPlayerStatusStop || self.status == BTAudioPlayerStatusPaused) {
    return;
  }
//  if (self.status == BTAudioQueueStatusStopping ||self.status == BTAudioQueueStatusStopped || self.status == BTAudioQueueStatusPaused) {
//    return;
//  }
  if ([_audioQueue isFull]||[_thread isCancelled]) {
    return;
  }
  NSUInteger availableDataLength = [_playerItem availableDataLength];
  
  //可用数据长度为0了，播放器的状态还在播放
  if (availableDataLength == 0 && (_playStatus == BTAudioPlayerStatusPlaying)) {
    if ([_playerItem isDataComplete]) { //所有数据都下载完了，并且可用数据长度为0，说明数据都已经写到Buffer里了
      if (_audioQueue.status == BTAudioQueueStatusStopping) { // 这里有问题，availableDataLength = 0时， writeData可能不会再进来了
        if ([_audioQueue isEmpty]) {
          [_audioQueue pause];
          [self audioQueuePlaybackIsComplete:_audioQueue];
        }
      } else {
        [_audioQueue endOfStream]; //TODO: 播放完成后，再次点击播放，会一直走这里 2013-01-30
      }
    } else { //还有数据没下载完，Queue需要暂停，播放器表现为等待状态
      [_audioQueue pause];
      self.status = BTAudioPlayerStatusWaiting;
    }
    return;
  } else {
    //TODO: 后续优化解决办法
    //改为kAQDefaultBufSize * 16，暂时解决播放本地文件无法启动播放的问题
    int kAQWriteDataSzie = kAQDefaultBufSize * (16 -_audioQueue.bufCountInQueue);
    if ([_audioQueue isEmpty]) {
      kAQWriteDataSzie = kAQDefaultBufSize * 16;
    }
//    if (_playerItem.seekRequested) {
//      _playerItem.byteWriteIndex = _playerItem.seekByteOffset;
//      _playerItem.seekRequested = NO;
//    }

    NSUInteger readLength = 0;
    readLength = ((availableDataLength >= kAQWriteDataSzie) ? kAQWriteDataSzie : availableDataLength);
    
    NSData *readData = [NSData dataWithBytes:([_playerItem.cacheData mutableBytes] + _playerItem.byteWriteIndex) length:readLength];
    _playerItem.byteWriteIndex += readLength;

//    NSData *readData = [_playerItem readData];
//    NSUInteger readLength = [readData length];
//    CDLog(BTDFLAG_AUDIO_PLAYER, @"readLength = %d", readLength);
    if (readData) {
      if (_fileStream) {
        if (_playerItem.discontinuity) {
          [_fileStream parseBytes:[readData bytes] dataSize:readLength flags:kAudioFileStreamParseFlag_Discontinuity];
        } else {
          [_fileStream parseBytes:[readData bytes] dataSize:readLength flags:0];
        }
      }
    }
    //TODO: 尝试解决拖动回弹的问题，没好用。
//    if (_playerItem.seekRequested) {
//      _playerItem.seekRequested = NO;
//    }
  }
}

#pragma mark -



- (void)setStatus:(BTAudioPlayerStatus)status {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  if (_playStatus != status) {
    _playStatus = status;
    dispatch_async(dispatch_get_main_queue(), ^{
      [_outsidePlayer setValue:[NSNumber numberWithInt:status] forKey:@"status"];
    });
  }
}

- (void)cancel {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  _request.delegate = nil;
  [_request cancel];
	[_request release];
  _request = nil;

  [_audioQueue unbind];
  [_audioQueue release];
  _audioQueue = nil;

  _fileStream.delegate = nil;
	[_fileStream release];
	_fileStream = nil;
  
  [_url release];
  _url = nil;
  
  //CDLog(BTDFLAG_AUDIO_PLAYER, @"_runLoop:%d, _runLoopSource:%d", _runLoop, _runLoopSource);
  if (_runLoop) {
    CFRunLoopRemoveSource(_runLoop, _runLoopSource, kCFRunLoopDefaultMode);
    CFRunLoopRemoveSource(_runLoop, _runLoopSourcePlay, kCFRunLoopDefaultMode);
    CFRelease(_runLoopSource);
    _runLoopSource = NULL;
    CFRelease(_runLoopSourcePlay);
    _runLoopSourcePlay = NULL;
    CFRunLoopStop(_runLoop);
    _runLoop = NULL;
  }
	// nil out our references so that any further operations
	// (such as cancel during dealloc) don't cause errors.

}

- (Float64)currentTime {
  
  if (_playStatus == BTAudioPlayerStatusPlaying) {
    //TODO: 尝试解决拖动回弹的问题，没好用。
//    if (_playerItem.seekRequested) {
//      return _playerItem.currentTime;
//    }
    Float64 currentTime = 0.0;
    AudioTimeStamp queueTime;
    Boolean discontinuity;
    
    OSStatus status = [_audioQueue getCurrentTime:&queueTime discontinuity:&discontinuity];
    //CDLog(BTDFLAG_AUDIO_PLAYER, @"discontinuity = %d", discontinuity);
    const OSStatus AudioQueueStopped = 0x73746F70; // 0x73746F70 is 'stop'
    if (status == AudioQueueStopped) {
      CVLog(BTDFLAG_AUDIO_PLAYER, @"AudioQueueStopped");
      currentTime = -2;
    } else if (status) {
      CVLog(BTDFLAG_AUDIO_PLAYER, @"status = %ld", status);
      currentTime = -3;
    } else {
      currentTime = _playerItem.seekTime + queueTime.mSampleTime / _playerItem.sampleRate;
      if (currentTime < 0.0) {
        currentTime = 0.0;
      }
      _playerItem.currentTime = currentTime;
    }
  }
  return _playerItem.currentTime;
  //CDLog(BTDFLAG_AUDIO_PLAYER, @"progress = %.3f", progress);
}

- (Float64)duration {
  return [_playerItem duration];
}

- (Float64)downloadProgress {
  return _playerItem.downloadProgress;
}

#pragma mark -

@end

