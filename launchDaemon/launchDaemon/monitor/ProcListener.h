//
//  file: ProcListener.h
//  project: DND (launch daemon)
//  description: interface with process monitor library (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//


@import Foundation;

#import "procInfo.h"

@interface ProcessMonitor : NSObject
{
    
}

/* PROPERTIES */

//process info (monitor) object
@property(nonatomic, retain)ProcInfo* procMon;

//list of active processes
@property(nonatomic, retain)NSMutableDictionary* processes;

/* METHODS */

//init
-(id)init;

//start
-(void)start;

//stop
-(void)stop;

@end
