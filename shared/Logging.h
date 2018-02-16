//
//  Logging.h
//  BlockBlock
//
//  Created by Patrick Wardle on 12/21/14.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#ifndef __BlockBlock__Logging__
#define __BlockBlock__Logging__

#import <syslog.h>
#import <Foundation/Foundation.h>

//log to file flag
#define LOG_TO_FILE 0x10

//log a msg to syslog
// also disk, if error
void logMsg(int level, NSString* msg);

//prep/open log file
BOOL initLogging(void);

//get path to log file
NSString* logFilePath(void);

//de-init logging
void deinitLogging(void);

//log to file
void log2File(NSString* msg);

#endif /* defined(__BlockBlock__Logging__) */
