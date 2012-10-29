//
//  BTDebugFlags.h
//  testLogLevel
//
//  Created by Zero on 9/18/12.
//  Copyright (c) 2012 21kunpeng. All rights reserved.
//

/*
 * 某个模块的Log信息是否打印的标识位
 * 1打印，0不打印
 * 注：可以自己扩展一个模块，定义一个宏
 */

#ifndef __BTDEBUGFLAGS_H__
#define __BTDEBUGFLAGS_H__
#define BTDFLAG_DEFAULT           1
#define BTDFLAG_AUDIO_QUEUE				1
#define BTDFLAG_NETWORK           1
#define BTDFLAG_FILE_STREAM	 			1
#define BTDFLAG_RUNLOOP           1
#define BTDFLAG_AUDIO_PLAYER      1
#endif