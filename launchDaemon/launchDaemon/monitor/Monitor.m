//
//  file: Monitor.m
//  project: DND (launch daemon)
//  description: monitor all things
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Monitor.h"

@implementation Monitor

@synthesize usbMonitor;
@synthesize volumeMonitor;
@synthesize processMonitor;
@synthesize dimisssObserver;
@synthesize downloadMonitor;
@synthesize userAuthMonitor;
@synthesize userAuthObserver;
@synthesize thunberboltMonitor;

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
    
    //start usb monitoring
    // can fail, so check, but keep going
    if(YES != [self.usbMonitor start])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to start USB monitoring");
    }
    
    //alloc/init thunderbolt monitor obj
    thunberboltMonitor = [[ThunderboltMonitor alloc] init];
    
    //start thunberbolt monitoring
    // can fail, so check, but keep going
    if(YES != [self.thunberboltMonitor start])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to start thunderbolt monitoring");
    }
    
    //alloc/init download monitor
    downloadMonitor = [[DownloadMonitor alloc] init];
    
    //start monitoring for downloads
    [self.downloadMonitor start];
    
    //(mounted) volume monitor
    volumeMonitor = [[VolumeMonitor alloc] init];
    
    //start monitoring for volumes
    [self.volumeMonitor start];
    
    //alloc/init user auth monitor
    userAuthMonitor = [[UserAuthMonitor alloc] init];
    
    //start user auth monitoring
    // broadcasts events which we register for/handle below
    if(YES == [self.userAuthMonitor start])
    {
        //register listener for user auth events
        // on event; just log to the log file for now...
        self.userAuthObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AUTH_NOTIFICATION object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
        {
            //dbg msg & log
            logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"monitor event: user authentication %@", notification.userInfo[AUTH_NOTIFICATION]]);
         
        }];
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"initialized all monitoring (timeout: %lu)", (unsigned long)timeout]);

    //register listener for dimiss event
    self.dimisssObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DISMISS_NOTIFICATION object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"got dismiss notification, will stop monitoring");
        
        //set flag
        self.wasDismissed = YES;
        
        //stop
        [self stop];
        
    }];

    //timeout?
    // exec block to stop everything once timeout is hit
    if(0 != timeout)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"will stop monitoring after %lu", (unsigned long)timeout]);
    
        //invoke stop after specified timeout
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC), dispatch_get_main_queue(),
        ^{
            //make sure alert wasn't dismissed (via phone)
            if(YES != self.wasDismissed)
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"monitoring timeout hit, will stop monitoring");
                
                //stop
                [self stop];
            }
        });
    }
    
    //happy
    started = YES;
    
bail:
    
    return started;
}

//stop all monitoring
-(void)stop
{
    //dbg/log msg
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"stopping all monitoring...");
    
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
    
    //stop thunderbolt monitor
    if(nil != self.thunberboltMonitor)
    {
        //stop
        [self.thunberboltMonitor stop];
        
        //unset
        self.thunberboltMonitor = nil;
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

    //stop (mounted) volume monitoring
    if(nil != self.volumeMonitor)
    {
        //stop
        [self.volumeMonitor start];
        
        //unset
        self.volumeMonitor = nil;
    }
    
    //remove user auth event notification observer
    // note: just remove observer, since other code still needs these events
    if(nil != self.userAuthObserver)
    {
        //remove
        [[NSNotificationCenter defaultCenter] removeObserver:self.userAuthObserver];
        
        //unset
        self.userAuthObserver = nil;
    }
    
    //dbg/log msg
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"stopped all monitoring");
    
    return;
}

@end
