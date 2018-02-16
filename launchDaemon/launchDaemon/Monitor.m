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
//#import "ThunderboltMonitor.h"

@implementation Monitor

@synthesize usbMonitor;
@synthesize processMonitor;
@synthesize downloadMonitor;
@synthesize userAuthMonitor;
@synthesize userAuthObserver;

//start all monitoring
// processes, auth events, hardware insertions, etc
-(BOOL)start:(NSUInteger)timeout
{
    //flag
    BOOL started = NO;
    
    //alloc/init process listener obj
    processMonitor = [[ProcessMonitor alloc] init];
    
    //start
    // can't fail, so no need to check
    [self.processMonitor start];
    
    //alloc/init usb monitor obj
    usbMonitor = [[USBMonitor alloc] init];
    
    //start monitoring
    // can fail, so check
    if(YES != [self.usbMonitor start])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to start USB monitoring");
        
        //bail
        goto bail;
    }
    
    //alloc/init download monitor
    downloadMonitor = [[DownloadMonitor alloc] init];
    
    //start monitoring for downloads
    [self.downloadMonitor start];
    
    //alloc/init user auth monitor
    userAuthMonitor = [[UserAuthMonitor alloc] init];
    
    //start user auth monitoring
    // broadcasts events which we register for/handle below
    if(YES != [self.userAuthMonitor start])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to start user auth monitoring");
        
        //bail
        goto bail;
    }
    
    //register listener for user auth events
    // on event; just log to the log file for now...
    self.userAuthObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AUTH_NOTIFICATION object:nil queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *notification)
    {
         //dbg msg & log
         logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"monitor event: user authentication %@", notification.userInfo[AUTH_NOTIFICATION]]);
        
    }];
    
    //dbg msg
    #ifndef NDEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"initialized all monitoring (timeout: %lu)", (unsigned long)timeout]);
    #endif
    
    //timeout?
    // stop everything
    if(0 != timeout)
    {
        //dbg msg
        #ifndef NDEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"will stop monitoring after %lu", (unsigned long)timeout]);
        #endif
        
        //invoke stop after specified timeout
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC), dispatch_get_main_queue(),
        ^{
            //stop
            [self stop];
           
        });
    }
    
    //happy
    started = YES;
    
bail:
    
    return started;
}

//stop all monitoring
// contains extra checks since mighe be called 2x (user dismiss/timeout)
-(void)stop
{
    //dbg/log msg
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"stopping all monitoring, as timeout was hit");
    
    //stop process monitor
    if(nil != self.processMonitor)
    {
        //stop
        [self.processMonitor stop];
        
        //unset
        self.processMonitor = nil;
    }
    
    //stop usb monitor
    if(nil != self.usbMonitor)
    {
        //stop
        [self.usbMonitor stop];
        
        //unset
        self.usbMonitor = nil;
    }
    
    //stop download monitor
    if(nil != self.downloadMonitor)
    {
        //stop
        [self.downloadMonitor stop];
        
        //unset
        self.downloadMonitor = nil;
    }
    
    //stop user auth monitoring
    if(nil != self.userAuthMonitor)
    {
        //stop
        [self.userAuthMonitor stop];
        
        //unset
        self.userAuthMonitor = nil;
    }

    //remove user auth event notification observer
    if(nil != self.userAuthObserver)
    {
        //remove
        [[NSNotificationCenter defaultCenter] removeObserver:self.userAuthObserver];
        
        //unset
        self.userAuthObserver = nil;
    }
    
    return;
}

@end
