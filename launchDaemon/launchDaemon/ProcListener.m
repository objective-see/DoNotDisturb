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

@implementation ProcessListener

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

//setup/start process monitoring
-(void)monitor:(NSUInteger)timeout
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
    
    //start
    [self.procMon start:block];
    
    //timeout?
    if(0 != timeout)
    {
        //invoke stop after specified timeout
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC), dispatch_get_main_queue(),
        ^{
            //dbg/log msg
            logMsg(LOG_DEBUG|LOG_TO_FILE, @"stopping process monitoring, as timeout was hit");
            
            //stop
            [self.procMon stop];
        });
    }
    
    return;
}

//process start
// just log that fact
-(void)processStart:(Process*)process
{
    //dbg msg
    logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"process start: %@ (%d)\n", process.path, process.pid]);
    
    return;
}

@end
