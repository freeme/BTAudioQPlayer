//
//  BTAppDelegate.h
//  BTAudioQPlayer
//
//  Created by Gary on 12-10-7.
//  Copyright (c) 2012年 Gary. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BTRootViewController.h"

@interface BTAppDelegate : UIResponder <UIApplicationDelegate> {
  UINavigationController *_navController;
  BTRootViewController *_rootController;
}

@property (strong, nonatomic) UIWindow *window;

@end
