//
//  BTRunLoopSource.h
//  BTAudioQPlayer
//
//  Created by He baochen on 13-1-21.
//  Copyright (c) 2013年 Gary. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol BTRunLoopSourcePerformDelegate <NSObject>

- (void)performCommand:(NSString*)command;

@end


@interface BTRunLoopSource : NSObject {
  CFRunLoopSourceRef _runLoopSource;
  NSMutableArray*    _commands;
  CFRunLoopRef       _runLoop;
  id<BTRunLoopSourcePerformDelegate> _delegate;
}

@property(nonatomic,assign) id<BTRunLoopSourcePerformDelegate> delegate;

- (void) addToCurrentRunLoop;
- (void) invalidate;
- (void) sourceFired;
- (void) addCommand:(NSString*)command;
- (void) fireAllCommands;
@end

void BTRunLoopSourceScheduleRoutine (void *info, CFRunLoopRef rl, CFStringRef mode);
void BTRunLoopSourcePerformRoutine (void *info);
void BTRunLoopSourceCancelRoutine (void *info, CFRunLoopRef rl, CFStringRef mode);
//// RunLoopContext is a container object used during registration of the input source.
//@interface BTRunLoopContext : NSObject {
//  CFRunLoopRef runLoop;
//  BTRunLoopSource* source;
//}
//@property (readonly) CFRunLoopRef runLoop;
//@property (readonly) BTRunLoopSource* source;
//- (id)initWithSource:(BTRunLoopSource*)src andLoop:(CFRunLoopRef)loop;
//@end
