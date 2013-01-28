//
//  BTPlayingViewController
//  BTAudioQPlayer
//
//  Created by Gary on 12-10-7.
//  Copyright (c) 2012年 Gary. All rights reserved.
//

#import "BTPlayingViewController.h"
#import "BTAudioPlayer.h"
#import "Music.h"
#import "BTPlayerItem.h"

static void *AVAudioPlayerStatusObservationContext = &AVAudioPlayerStatusObservationContext;
static void *AVAudioPlayerItemObservationContext = &AVAudioPlayerItemObservationContext;


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

- (void)dealloc {
  [self clearTimer];
  
  [super dealloc];
}

- (id)init
{
  self = [super init];
  if (self) {
    // Custom initialization
    _player = [[BTAudioPlayer alloc] init];

  }
  return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

  [self addObserver];
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
//  [_player stop];
//  [_player release];
//  _player = nil;
//  _playProgressBar.value = 0.0;
//  _downloadProgressView.progress = 0.0;
//  _curTime.text = @"0";
//  _totalTime.text = @"0";
//  [self updateUIPauseMusic];
//  
//  Music *music = [_playList objectAtIndex:_playingIndex];
//  _musicTitle.text = music.title;
//  
//  /** load file from local filesystem
//  NSURL *url = [[NSBundle mainBundle] URLForResource:@"lpzd" withExtension:@"mp3"];
//  _player = [[BTAudioPlayer alloc] initPlayerWithURL:url delegate:self];
//  */
//  _player = [[BTAudioPlayer alloc] initWithURL:[NSURL URLWithString:music.downloadLink]];
//
//  [_player start];
//  [self setUpdateTimer];

}

- (void)addObserver {
  [_player addObserver:self
            forKeyPath:@"status"
               options:(NSKeyValueObservingOptionNew |
                        NSKeyValueObservingOptionInitial)
               context:AVAudioPlayerStatusObservationContext];
  [_player addObserver:self
            forKeyPath:@"currentItem"
               options:(NSKeyValueObservingOptionNew |
                        NSKeyValueObservingOptionInitial)
               context:AVAudioPlayerItemObservationContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  DLog(@"keyPath = %@ . object = %@ . change = %@", keyPath,object,change);
  DLog(@"th:%d,_player.status = %d", [NSThread isMainThread],_player.status);
  if (context == AVAudioPlayerStatusObservationContext) {
    BTAudioPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
    [self updateUIWithStatus:status];
  } else if (context == AVAudioPlayerItemObservationContext) {
    BTPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
    
    /* Is the new player item null? */
    if (newPlayerItem == (id)[NSNull null]) {
      
    } else {
      
    }
  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}
- (void)setUpdateTimer {
  if (progressUpdateTimer) {
    [self clearTimer];
  }
  progressUpdateTimer =
  [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateProgress:) userInfo:nil repeats:YES];
}

- (void)clearTimer {
  if (progressUpdateTimer) {
    [progressUpdateTimer invalidate];
    progressUpdateTimer = nil;
  }
}

- (IBAction) playAndPauseAction {
  if (_player.status == BTAudioPlayerStatusPaused) {
    [_player play];
  } else {
    [_player pause];
  }
}
- (IBAction) fastForwardAction;{
  Float32 seekTime = _playProgressBar.value * [_player duration] + 5;
  [_player seekToTime:seekTime];
}
- (IBAction) backwardAction;{
  Float32 seekTime = _playProgressBar.value * [_player duration] - 5;
  [_player seekToTime:seekTime];
}
- (IBAction) nextAction;{

  if (_playingIndex + 1 < [_playList count]) {
    _playingIndex ++;
  } else {
    _playingIndex = 0;
  }
  Music *music = [_playList objectAtIndex:_playingIndex];
  _musicTitle.text = music.title;
  [_player replaceCurrentItemWithURL:[NSURL URLWithString:music.downloadLink]];
  
}
- (IBAction) previousAction;{

}
- (IBAction) progressWillChangedAction;{
  [self clearTimer];
}
- (IBAction) progressChangedAction;{

}
- (IBAction) progressDidChangedAction;{
  
  Float32 seekTime = _playProgressBar.value * [_player duration];
  [_player seekToTime:seekTime];
  [self setUpdateTimer];
}

- (IBAction) progressCancelChangedAction {
  [self setUpdateTimer];
}

- (void)updateUIWithStatus:(BTAudioPlayerStatus) status{
  if (status == BTAudioPlayerStatusStop) {
    [self setPlayButtonsEnable:NO];
  } else if (status == BTAudioPlayerStatusReadyToPlay) {
    [self setPlayButtonsEnable:NO];
  } else if (status == BTAudioPlayerStatusPlaying) {
    [self updateUIPlayingMusic];
  } else if (status == BTAudioPlayerStatusPaused) {
    [self updateUIPauseMusic];
  } else if (status == BTAudioPlayerStatusWaiting) {
    [self updateUIWaitMusicToPlay];
  } else { //BTAudioPlayerStatusFailed
    NSError *error = _player.error;
  }
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

- (void) setPlayButtonsEnable:(BOOL)enable {
  _playAndPauseButton.enabled = enable;
  _fastForwardButton.enabled = enable;
  _nextButton.enabled = enable;
  _previousButton.enabled = enable;
  _backwardButton.enabled = enable;
  _playProgressBar.enabled = enable;
}
#pragma mark -

- (void)audioPlayer:(BTAudioPlayerInternal *) audioPlayer downloadProgress:(float)progress{
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
//  progress = [_player playProgress];
//  duration = [_player duration];
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
    //[_playProgressBar setEnabled:NO];
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
