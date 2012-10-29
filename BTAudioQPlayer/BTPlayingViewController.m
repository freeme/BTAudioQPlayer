//
//  BTPlayingViewController
//  BTAudioQPlayer
//
//  Created by Gary on 12-10-7.
//  Copyright (c) 2012年 Gary. All rights reserved.
//

#import "BTPlayingViewController.h"
#import "Music.h"

static BTPlayingViewController *instance;

@interface BTPlayingViewController ()

@end

@implementation BTPlayingViewController

+ (id) sharePlayerController {
  if (instance == nil) {
    instance = [[BTPlayingViewController alloc] init];
  }
  return instance;
}

- (id)init
{
  self = [super init];
  if (self) {
      // Custom initialization

  }
  return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void) playWithIndex:(NSInteger)playIndex inList:(NSMutableArray*)newPlayList;{
  if (newPlayList!=nil) {
    if (newPlayList != _playList) {
      if (_playList) {
        [_playList release];
      }
      _playList = [newPlayList retain];
      _playingIndex = playIndex;
      [self playNewMusic];
    } else {
      if (playIndex != _playingIndex) {
        _playingIndex = playIndex;
        [self playNewMusic];
      }
    }
  }
}


#pragma mark --
- (void) playNewMusic {
  [_player stop];
  [_player release];
  _player = nil;
  _playProgressBar.value = 0.0;
  _downloadProgressView.progress = 0.0;
  _curTime.text = @"0";
  _totalTime.text = @"0";
  [self updateUIPauseMusic];
  
  Music *music = [_playList objectAtIndex:_playingIndex];
  _musicTitle.text = music.title;
  
  /** load file from local filesystem
  NSURL *url = [[NSBundle mainBundle] URLForResource:@"lpzd" withExtension:@"mp3"];
  _player = [[BTAudioPlayer alloc] initPlayerWithURL:url delegate:self];
  */
  _player = [[BTAudioPlayer alloc] initPlayerWithURL:[NSURL URLWithString:music.downloadLink ] delegate:self];

  [_player start];
  [self setUpdateTimer];
  
//  [_player addObserver:self
//            forKeyPath:@"status"
//               options:(NSKeyValueObservingOptionNew |
//                        NSKeyValueObservingOptionOld)
//               context:NULL];

}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  DLog(@"keyPath = %@ . object = %@ . change = %@", keyPath,object,change);
//  if ([keyPath isEqual:@"status"]) {
//    [openingBalanceInspectorField setObjectValue:
//     [change objectForKey:NSKeyValueChangeNewKey]];
//  }
  /*
   Be sure to call the superclass's implementation *if it implements it*.
   NSObject does not implement the method.
   */
//  [super observeValueForKeyPath:keyPath
//                       ofObject:object
//                         change:change
//                        context:context];
}
- (void)setUpdateTimer {
  progressUpdateTimer =
  [NSTimer
   scheduledTimerWithTimeInterval:1
   target:self
   selector:@selector(updateProgress:)
   userInfo:nil
   repeats:YES];
}

- (IBAction) playAndPauseAction {
  _player.paused = !_player.paused;
  if (_player.paused) {
    [self updateUIPauseMusic];
  } else {
    [self updateUIPlayingMusic];
  }
}
- (IBAction) fastForwardAction;{
  
}
- (IBAction) backwardAction;{
  
}
- (IBAction) nextAction;{
  
  //Add for test
  if (_player) {
    [_player stop];
    [_player release];
    _player = nil;
  }
  
}
- (IBAction) previousAction;{

}
- (IBAction) progressWillChangedAction;{
  [progressUpdateTimer invalidate];
  progressUpdateTimer = nil;
}
- (IBAction) progressChangedAction;{

}
- (IBAction) progressDidChangedAction;{
  [self setUpdateTimer];
  Float32 seekTime = _playProgressBar.value * [_player duration];
  [_player seekToTime:seekTime];
}

- (IBAction) progressCancelChangedAction {
  [self setUpdateTimer];
}

- (void) updateUIPlayingMusic {
  [_waitView stopAnimating];
  [_playAndPauseButton setTitle:@"||" forState:UIControlStateNormal];
}

- (void) updateUIPauseMusic {
  [_waitView stopAnimating];
  [_playAndPauseButton setTitle:@"|>" forState:UIControlStateNormal];
}

- (void) updateUIWaitMusicToPlay {
  [_waitView startAnimating];
  [_playAndPauseButton setTitle:@"" forState:UIControlStateNormal];
}
#pragma mark -
#pragma mark BTAudioPlayerDelegate

/*
 * Notifies the delegate that the requested file was not playable.
 */
- (void)audioPlayer:(BTAudioPlayer *)audioPlayer failedWithError:(NSError*)error{
  
}

/*
 * Notifies the delegate that playback of the requested file has begun.
 */
- (void)audioPlayerStarted:(BTAudioPlayer *)audioPlayer {
  [self updateUIPlayingMusic];
}

- (void)audioPlayerWaiting:(BTAudioPlayer *)audioPlayer {
  [self updateUIWaitMusicToPlay];
}

/*
 * Notifies the delegate that playback of the request file is complete.
 */
- (void)audioPlayerFinished:(BTAudioPlayer *)audioPlayer {
  [self updateUIPauseMusic];
}

- (void)audioPlayer:(BTAudioPlayer *) audioPlayer downloadProgress:(float)progress{
//  float p = [progress floatValue];
  CVLog(BTDFLAG_NETWORK,@"progress = %.4f", progress);
  _downloadProgressView.progress = progress;
}

#pragma mark -

- (void)updateProgress:(NSTimer *)updatedTimer
{
//	if (streamer.bitRate != 0.0) {
  float progress = 0.0;
  float duration = 0.0;
  progress = [_player playProgress];
  duration = [_player duration];
//
//		if (duration > 0) {
  {
    int minute = progress / 60;
    int second = (int)progress % 60;
    _curTime.text = [NSString stringWithFormat:@"%d:%.2d",minute,second];
  }
  {
    int minute = duration / 60;
    int second = (int)duration % 60;
     _totalTime.text = [NSString stringWithFormat:@"%d:%.2d",minute,second];
  }
  if (duration) {
    [_playProgressBar setEnabled:YES];
    [_playProgressBar setValue:progress / duration];
  } else {
    [_playProgressBar setEnabled:NO];
  }
//			[_progressBar setEnabled:YES];
//			[_progressBar setValue:progress / duration];
//    }
//		else {
//			[_progressBar setEnabled:NO];
//    }
//  }
//	else {
//    _curTime.text = @"0.0";
//    _totalTime.text = @"0.0";
//  }
}
@end
