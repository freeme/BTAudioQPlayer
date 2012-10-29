//
//  BTPlayerItem.h
//  BTAudioPlayer
//
//  Created by He baochen on 12-9-25.
//  Copyright (c) 2012年 He baochen. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol BTPlayerItem <NSObject>

@property (nonatomic, copy) NSString *title;
@property (nonatomic, retain) NSURL *url;

@end
