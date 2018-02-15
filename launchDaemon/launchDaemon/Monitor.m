//
//  Monitor.m
//  launchDaemon
//
//  Created by Patrick Wardle on 2/13/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Monitor.h"
#import "USBMonitor.h"
#import "ProcListener.h"
#import "UserAuthMonitor.h"
//#import "ThunderboltMonitor.h"

@implementation Monitor

//init
-(id)init:(NSUInteger)timeout
{
    //super
    self = [super init];
    if(nil != self)
    {
        //self.timeout = timeout;
    }
    
    return self;
}

//start all monitoring
// processes, auth events, hardware insertions, etc
-(BOOL)start:(NSUInteger)timeout
{
    //flag
    BOOL started = NO;
    
    //process listener obj
    ProcessMonitor* processMonitor = nil;
    
    //usb monitor
    USBMonitor* usbMonitor = nil;
    
    //user auth events monitor
    UserAuthMonitor* userAuthMonitor = nil;
    
    //alloc/init process listener obj
    processMonitor = [[ProcessMonitor alloc] init];
    
    //start
    if(YES != [processMonitor start])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to start process monitoring");
        
        //bail
        goto bail;
    }
    
    //alloc/init usb monitor obj
    usbMonitor = [[USBMonitor alloc] init];
    
    //start monitoring
    if(YES != [usbMonitor start])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to start USB monitoring");
        
        //bail
        goto bail;
    }
    
    //alloc/init user auth monitor
    userAuthMonitor = [[UserAuthMonitor alloc] init];
    
    //start user auth monitoring
    if(YES != [userAuthMonitor start])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to start user auth monitoring");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    #ifndef NDEBUG
    logMsg(LOG_DEBUG, @"initialize all monitoring");
    #endif
    
    //timeout?
    // stop everything
    if(0 != timeout)
    {
        //invoke stop after specified timeout
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC), dispatch_get_main_queue(),
        ^{
            //dbg/log msg
            logMsg(LOG_DEBUG|LOG_TO_FILE, @"stopping all monitoring, as timeout was hit");
           
            //stop process monitor
            [processMonitor stop];
           
            //stop usb monitor
            [usbMonitor stop];
            
            //stop user auth monitoring
            [userAuthMonitor stop];
           
        });
    }
    
    //happy
    started = YES;
    
bail:
    
    return started;
}


@end
