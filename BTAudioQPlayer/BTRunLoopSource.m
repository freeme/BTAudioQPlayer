//
//  BTRunLoopSource.m
//  BTAudioQPlayer
//
//  Created by He baochen on 13-1-21.
//  Copyright (c) 2013年 Gary. All rights reserved.
//

#import "BTRunLoopSource.h"

@implementation BTRunLoopSource
@synthesize delegate = _delegate;


void BTRunLoopSourceScheduleRoutine (void *info, CFRunLoopRef rl, CFStringRef mode) {
  
}
void BTRunLoopSourcePerformRoutine (void *info) {
  BTRunLoopSource* obj = (BTRunLoopSource*)info;
  [obj sourceFired];
}
void BTRunLoopSourceCancelRoutine (void *info, CFRunLoopRef rl, CFStringRef mode) {
  
}
- (id)init {
  self = [super init];
  if (self) {
    CFRunLoopSourceContext context = {0, self, NULL, NULL, NULL, NULL, NULL,
      &BTRunLoopSourceScheduleRoutine,&BTRunLoopSourceCancelRoutine,&BTRunLoopSourcePerformRoutine};
    _runLoopSource = CFRunLoopSourceCreate(NULL, 0, &context);
    _commands = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void) addCommand:(NSString*)command {
  if (![_commands containsObject:command]) {
    [_commands addObject:command];
  }
}
- (void) sourceFired {
  if ([_commands count] > 0) {
    if (_delegate && [_delegate respondsToSelector:@selector(performCommand:)]) {
      NSString *command = [_commands objectAtIndex:0];
      [_delegate performCommand:command];
      [_commands removeObjectAtIndex:0];
      [self sourceFired];
    }
  }
}

- (void)addToCurrentRunLoop {
  _runLoop = CFRunLoopGetCurrent();
  CFRunLoopAddSource(_runLoop, _runLoopSource, kCFRunLoopDefaultMode);
}

- (void)fireAllCommands {
  CFRunLoopSourceSignal(_runLoopSource);
  CFRunLoopWakeUp(_runLoop);
}

- (void) invalidate {
  
}

- (void)dealloc {
  CFRunLoopRemoveSource(_runLoop, _runLoopSource, kCFRunLoopDefaultMode);
  CFRelease(_runLoopSource);
  _runLoopSource = NULL;
  _runLoop = NULL;
  _delegate = nil;
  [_commands release];
  [super dealloc];
}
@end
