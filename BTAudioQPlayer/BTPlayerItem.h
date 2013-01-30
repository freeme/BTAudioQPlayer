//
//  BTPlayerItem.h
//  BTAudioQPlayer
//
//  Created by Gary on 13-1-23.
//  Copyright (c) 2013年 Gary. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, BTPlayerItemStatus) {
	BTPlayerItemStatusStop, //TODO: Or unknown
  BTPlayerItemStatusWaiting,
  BTPlayerItemStatusPlaying,
  BTPlayerItemStatusPaused,
};

@class BTPlayerItemInternal;
@interface BTPlayerItem : NSObject {
  BTPlayerItemInternal *_internalItem;
}

@property (nonatomic, readonly) BTPlayerItemStatus status;
@property (nonatomic, retain) NSError *error;
@property (nonatomic, readonly) Float64 duration;
@property (nonatomic, readonly) Float64 currentTime;
+ (BTPlayerItem *)playerItemWithURL:(NSURL *)URL;
- (id)initWithURL:(NSURL *)URL;

@end
