//
//  BTPlayingViewController
//  BTAudioQPlayer
//
//  Created by Gary on 12-10-7.
//  Copyright (c) 2012年 Gary. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BTAudioPlayer.h"

@interface BTPlayingViewController : UIViewController<BTAudioPlayerDelegate> {
  IBOutlet UIButton *_playAndPauseButton;
  IBOutlet UIButton *_fastForwardButton;
  IBOutlet UIButton *_backwardButton;
  IBOutlet UIButton *_nextButton;
  IBOutlet UIButton *_previousButton;
  IBOutlet UILabel *_curTime;
  IBOutlet UILabel *_totalTime;
  IBOutlet UILabel *_musicTitle;
  IBOutlet UISlider  *_playProgressBar;
  IBOutlet UIActivityIndicatorView *_waitView;
  IBOutlet UIProgressView *_downloadProgressView;
  NSMutableArray *_playList;
  NSInteger      _playingIndex;
  

	NSTimer *progressUpdateTimer;
  
  BTAudioPlayer *_player;
  
  NSObject *_obj;
}


+ (id) sharePlayerController;

- (IBAction) playAndPauseAction;
- (IBAction) fastForwardAction;
- (IBAction) backwardAction;
- (IBAction) nextAction;
- (IBAction) previousAction;
- (IBAction) progressWillChangedAction;
- (IBAction) progressChangedAction;
- (IBAction) progressDidChangedAction;
- (IBAction) progressCancelChangedAction;
- (void) playWithIndex:(NSInteger)playIndex inList:(NSMutableArray*)newPlayList;
@end
