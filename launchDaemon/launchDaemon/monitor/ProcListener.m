//
//  file: ProcListener.m
//  project: DND (launch daemon)
//  description: interface with process monitor library
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "ProcListener.h"

@implementation ProcessMonitor

@synthesize procMon;
@synthesize processes;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //alloc
        self.processes = [NSMutableDictionary dictionary];
        
        //init proc info (monitor)
        procMon = [[ProcInfo alloc] init];
    }
    
    return self;
}

//start
// tell proc info lib to start
-(void)start
{
    //callback block
    ProcessCallbackBlock block = ^(Process* process)
    {
        //process start?
        if(process.type != EVENT_EXIT)
        {
            //start
            [self processStart:process];
        }
    };
    
    [self.procMon start:block];
    
    return;
}

//tell proc info lib to stop
-(void)stop
{
    //stop
    [self.procMon stop];
    
    return;
}

//process start
// just log that fact
-(void)processStart:(Process*)process
{
    //dbg msg & log
    logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"monitor event: process start: (%d: %@ (args: %@))", process.pid, process.path, process.arguments]);
    
    return;
}

@end
