//
//  BTDebug.h
//  testLogLevel
//
//  Created by Zero on 9/18/12.
//  Copyright (c) 2012 21kunpeng. All rights reserved.
//

/*
 * LOG级别定义
 * 优先级有下列集中，是按照从低到高顺利排列的:
 * V — Verbose (lowest priority)
 * D — Debug
 * I — Info
 * W — Warning
 * E — Error
 * F — Fatal
 * S — Silent (highest priority, on which nothing is ever printed)
 */

#import "BTDebugFlags.h"

#ifndef __BTDEBUG_H__
#define __BTDEBUG_H__

#pragma mark - Log级别定义
#define BTLOGLEVEL_VERBOSE	100	//最低优先级，如打印字典、数组类信息
#define BTLOGLEVEL_DEBUG	80	//打印调试信息（默认级别）
#define BTLOGLEVEL_INFO		60	//打印程序关键路径信息，如打印“发起请求”、“取消请求”、“请求结束”、“打开某页面”等等信息
#define BTLOGLEVEL_WARNING	40	//打印警告信息
#define BTLOGLEVEL_ERROR	20	//打印错误信息
#define BTLOGLEVEL_FATAL	10	//打印致命错误信息
#define BTLOGLEVEL_SILENT	0	//静默，什么也不打印

/*
 * 允许的最高Log级别
 * 这里可以根据自己的需要修改
 */
#pragma mark - 允许的最高Log级别
#ifndef	BTMAXLOGLEVEL
//#	define BTMAXLOGLEVEL BTLOGLEVEL_INFO
#	define BTMAXLOGLEVEL BTLOGLEVEL_DEBUG
//#	define BTMAXLOGLEVEL BTLOGLEVEL_VERBOSE
#endif

/*
 * 打印Log，忽略优先级，不推荐使用
 */
#pragma mark - 打印Log，忽略优先级，不推荐使用
#ifdef DEBUG 
#	define ALog(...)  NSLog(@"th:(%@)-%s(%d): %@", \
  [[NSThread currentThread] name], __PRETTY_FUNCTION__, __LINE__, \
  [NSString stringWithFormat:__VA_ARGS__])
#else
#	define ALog(...)  ((void)0)
#endif // #ifdef DEBUG

/*
 * 条件Log，忽略优先级，不推荐使用
 */
#pragma mark - 条件Log，忽略优先级，不推荐使用
#ifdef DEBUG
#define CLog(condition,...) {	if ((condition)) { \
									ALog(__VA_ARGS__); \
								} \
							} ((void)0)
#else
#define CLog(condition,...) ((void)0)
#endif // #ifdef DEBUG


/*
 * 基于优先级的带参数的Log
 */
#pragma mark - 基于优先级的带参数的Log
#if BTLOGLEVEL_VERBOSE <= BTMAXLOGLEVEL
#define CVLog(xx,...) CLog(xx,__VA_ARGS__)
#else
#define CVLog(xx,...) ((void)0)
#endif // #if BTLOGLEVEL_VERBOSE <= BTMAXLOGLEVEL

#if BTLOGLEVEL_DEBUG <= BTMAXLOGLEVEL
#define CDLog(xx,...) CLog(xx,__VA_ARGS__)
#else
#define CDLog(xx,...) ((void)0)
#endif // #if BTLOGLEVEL_DEBUG <= BTMAXLOGLEVEL

#if BTLOGLEVEL_INFO <= BTMAXLOGLEVEL
#define CILog(xx,...) CLog(xx,__VA_ARGS__)
#else
#define CILog(xx,...) ((void)0)
#endif // #if BTLOGLEVEL_INFO <= BTMAXLOGLEVEL

#if BTLOGLEVEL_WARNING <= BTMAXLOGLEVEL
#define CWLog(xx,...) CLog(xx,__VA_ARGS__)
#else
#define CWLog(xx,...) ((void)0)
#endif // #if BTLOGLEVEL_WARNING <= BTMAXLOGLEVEL

#if BTLOGLEVEL_ERROR <= BTMAXLOGLEVEL
#define CELog(xx,...) CLog(xx,__VA_ARGS__)
#else
#define CELog(xx,...) ((void)0)
#endif // #if BTLOGLEVEL_ERROR <= BTMAXLOGLEVEL

#if BTLOGLEVEL_FATAL <= BTMAXLOGLEVEL
#define CELog(xx,...) CLog(xx,__VA_ARGS__)
#else
#define CELog(xx,...) ((void)0)
#endif // #if BTLOGLEVEL_FATAL <= BTMAXLOGLEVEL

#if BTLOGLEVEL_SILENT <= BTMAXLOGLEVEL
#define CELog(xx,...) CLog(xx,__VA_ARGS__)
#else
#define CELog(xx,...) ((void)0)
#endif // #if BTLOGLEVEL_SILENT <= BTMAXLOGLEVEL


/*
 * 基于优先级的不带参数的Log
 */
#pragma mark - 基于优先级的不带参数的Log
#define VLog(...) CVLog(BTDFLAG_DEFAULT,__VA_ARGS__)
#define DLog(...) CDLog(BTDFLAG_DEFAULT,__VA_ARGS__)
#define ILog(...) CILog(BTDFLAG_DEFAULT,__VA_ARGS__)
#define WLog(...) CWLog(BTDFLAG_DEFAULT,__VA_ARGS__)
#define ELog(...) CELog(BTDFLAG_DEFAULT,__VA_ARGS__)
#define FLog(...) CFLog(BTDFLAG_DEFAULT,__VA_ARGS__)
#define SLog(...) CSLog(BTDFLAG_DEFAULT,__VA_ARGS__)

/*
 * 只在Debug下打印当前函数名
 * 目前认为打印函数名比较啰嗦，所以优先级设为了Verbose（最低）
 */
#pragma mark - 打印当前函数名
#ifdef DEBUG
#if BTLOGLEVEL_VERBOSE <= BTMAXLOGLEVEL
#define PrintFunctionName() printf("%s", __PRETTY_FUNCTION__)
#else
#define PrintFunctionName() ((void)0)
#endif // #if BTLOGLEVEL_VERBOSE <= BTMAXLOGLEVEL
#else
#define PrintFunctionName() ((void)0)
#endif // #ifdef DEBUG

/*
 * 只在Debug下的iPhone模拟器使用断言
 */
#ifdef DEBUG

#import <TargetConditionals.h>

#if TARGET_IPHONE_SIMULATOR

BOOL BTIsInDebugger(void);
#define DASSERT(xx) {	if (!(xx)) { \
							DLog(@"DASSERT failed: %s", #xx); \
							if (BTIsInDebugger()) { \
								__asm__("int $3\n" : : ); \
							}; \
						} \
					} ((void)0)
#else
#define DASSERT(xx) {	if (!(xx)) { \
							DLog(@"DASSERT failed: %s", #xx); \
						} \
					} ((void)0)
#endif // #if TARGET_IPHONE_SIMULATOR

#else
#define DASSERT(xx) ((void)0)
#endif // #ifdef DEBUG

#endif // #ifndef __BTDEBUG_H__
