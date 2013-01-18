//
//  BTRootViewController.m
//  BTAudioQPlayer
//
//  Created by Gary on 12-10-7.
//  Copyright (c) 2012年 Gary. All rights reserved.
//

#import "BTRootViewController.h"
#import "Music.h"
#import "BTPlayingViewController.h"

@interface BTRootViewController ()

@end

@implementation BTRootViewController

- (void)dealloc {
  [_musicList release];
  [super dealloc];
}

- (id)init
{
  self = [super init];

  if (self) {
    
    //[self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    // Custom initialization
    _musicList = [[NSMutableArray alloc] initWithCapacity:16];
    
    [self addTestMusicWithTitle:@"老婆最大" link:@"http://www.ycsky100.com/blog/Qq1274076003/upload/2011112410110590.mp3"];
    NSURL *url0 = [[NSBundle mainBundle] URLForResource:@"lpzd" withExtension:@"mp3"];
    [self addTestMusicWithTitle:@"老婆最大(本地资源)" link:[url0 absoluteString]];
    NSURL *url1 = [[NSBundle mainBundle] URLForResource:@"01-002" withExtension:@"mp3"];
    [self addTestMusicWithTitle:@"01-002(本地资源)" link:[url1 absoluteString]];
    [self addTestMusicWithTitle:@"伤不起" link:@"http://mul1.tximg.cn/music/group/bbs/mp3/13/110830/1314711786255.mp3"];
    [self addTestMusicWithTitle:@"序曲" link:@"http://www.mglmusic.com/geqv/zuhegeqv/fenghuangchuanqi/01.mp3"];
    [self addTestMusicWithTitle:@"等一分钟" link:@"http://xkpt.txsyxx.com/uploadresource/netstudyresource/2011920130152.mp3"];
    [self addTestMusicWithTitle:@"套马杆 dj" link:@"http://www.zltsz.com/video/%CE%DA%C0%BC%CD%D0%E6%AB-%CC%D7%C2%ED%B8%CB(DJ).mp3"];
    [self addTestMusicWithTitle:@"郎的诱惑" link:@"http://wenhua.youth.cn/yis/yy/201003/W020100323428725798476.mp3"];
    
    [self addTestMusicWithTitle:@"月亮之上" link:@"http://bu.xmanyao.info/COFFdD0xMzQ3OTQ0OTY2Jmk9MTI0LjkzLjIyMy4xMTQmdT1Tb25ncy92Mi9mYWludFFDL2Q4LzJjLzUxYjJiYmMzZWZiMWNhYWIzZWU3M2ZiYmU1NzkyY2Q4Lm1wMyZtPTY1MzVkNWI3ZWM5MGU5MDdkNTkxM2FlNmE2NmQ5MTU2JnY9bGlzdGVuJm491MLBwdauyc8mcz2377vLtKvG5iZwPW4=.mp3"];
    
    [self addTestMusicWithTitle:@"自由飞翔" link:@"http://data1.act.qq.com/20071025/17/119330398213504.mp3"];
  }
  return self;
}

- (void) addTestMusicWithTitle:(NSString*)title link:(NSString*)link {
  Music *music = [[Music alloc] init];
  music.title = title;
  music.downloadLink = link;
  [_musicList addObject:music];
  [music release];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
  
  BTPlayingViewController *playerController = [BTPlayingViewController sharePlayerController];

  CGRect tableFrame = self.view.bounds;
  CGRect playViewFrame = playerController.view.bounds;
  tableFrame.size.height -= (playViewFrame.size.height + 44);
  playViewFrame.origin.y = tableFrame.size.height + 44;
  playerController.view.frame = playViewFrame;
  UITableView *tableView = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
  tableView.dataSource = self;
  tableView.delegate = self;
  [self.view addSubview:tableView];
  [self.view addSubview:playerController.view];
  
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
#warning Potentially incomplete method implementation.
    // Return the number of sections.
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
#warning Incomplete method implementation.
    // Return the number of rows in the section.
  return [_musicList count];;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *identifier = @"Cell";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    
    // Configure the cell...
  if (cell == nil) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier] autorelease];
  }
  Music *music = [_musicList objectAtIndex:indexPath.row];
  cell.textLabel.text = music.title;
  return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  BTPlayingViewController *playerController = [BTPlayingViewController sharePlayerController];
  // ...
  // Pass the selected object to the new view controller.
  
  //[self.navigationController pushViewController:playerController animated:YES];
  [playerController playWithIndex:indexPath.row inList:_musicList];
}

@end
