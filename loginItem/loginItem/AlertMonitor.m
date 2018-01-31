//
//  file: AlertMonitor.m
//  project: DnD (login item)
//  description: monitor for alerts from daemom
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "AppDelegate.h"
#import "DaemonComms.h"
#import "AlertMonitor.h"

@implementation AlertMonitor

@synthesize lastAlert;

//forever,
// receive & display alerts
-(void)monitor
{
    //daemon comms object
    DaemonComms* daemonComms = nil;
    
    //wait semaphore
    dispatch_semaphore_t semaphore = 0;
    
    //init daemon
    // use local var here, as we need to block
    daemonComms = [[DaemonComms alloc] init];
    
    //init sema
    semaphore = dispatch_semaphore_create(0);
    
    //process alerts
    // call daemon and block, then display, and repeat!
    while(YES)
    {
        //pool
        @autoreleasepool
        {
            
        //dbg msg
        logMsg(LOG_DEBUG, @"requesting alert(s) from daemon, will block");
        
        //wait for alert from daemon via XPC
        [daemonComms alertRequest:^(NSDictionary* alert)
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got alert from daemon: %@", alert]);
            
            //tell daemon we got it
            // allows it to be discarded
            [daemonComms alertResponse];
            
            //signal alert
            // indicates it was processed
            dispatch_semaphore_signal(semaphore);
            
            //ignore if it's same/same
            // sometimes lid open/awake cause weird stuff with XPC resume, so multiple deliveries
            if(YES == [self.lastAlert isEqualToDate:alert[ALERT_TIMESTAMP]])
            {
                //ignore
                // will just exit block
                return;
            }
            
            //update
            self.lastAlert = alert[ALERT_TIMESTAMP];
            
            //show alert window on main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                     
                 //show notification
                 [self showNotification:alert];
                     
            });

         }];
        
        //wait for alert to be received
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
        }//pool
            
    }//forevers
    
    return;
}

//format, then show notification
-(void)showNotification:(NSDictionary*)alert
{
    //notification
    NSUserNotification* notification = nil;
    
    //formatter
    NSDateFormatter* dateFormat = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"displaying alert to user...");
    
    //alloc notification
    notification = [[NSUserNotification alloc] init];
    
    //alloc formatter
    dateFormat = [[NSDateFormatter alloc] init];
    
    //set date format
    [dateFormat setDateFormat:@"MM/dd/yyyy HH:mm:ss"];
    
    //set other button title
    notification.otherButtonTitle = @"ok";
    
    //remove action button
    notification.hasActionButton = NO;
    
    //set title
    notification.title = @"⚠️ Do Not Disturb Alert";
    
    //set subtitle
    notification.subtitle = [NSString stringWithFormat:@"lid opened: %@", [dateFormat stringFromDate:alert[ALERT_TIMESTAMP]]];
    
    //set informative text
    //notification.informativeText = @"<blah>";
    
    //set delegate to self
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    
    //deliver notification
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

//delegate method
// always should alert to user
-(BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

@end
