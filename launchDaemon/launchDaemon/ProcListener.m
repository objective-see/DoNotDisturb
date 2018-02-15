//
//  file: ProcListener.m
//  project: DnD (launch daemon)
//  description: interface with process monitor library
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
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
-(BOOL)start
{
    //flag
    BOOL started = NO;
    
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
    
    //start
    if(YES != [self.procMon start:block])
    {
        //bail
        goto bail;
    }
    
    //happy
    started = YES;
    
bail:
    
    return started;
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
    logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"monitor event: process start: (%d: %@)", process.pid, process.path]);
    
    return;
}

@end
