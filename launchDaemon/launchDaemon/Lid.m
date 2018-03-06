//
//  Lid.m
//  launchDaemon
//
//  Created by user on 11/25/17.
//  Copyright (c) 2017 Objective-See. All rights reserved.
//

// code inspired by:
//  https://github.com/zarigani/ClamshellWake/blob/master/ClamshellWake.cpp
//  https://github.com/dustinrue/ControlPlane/blob/master/Source/LaptopLidEvidenceSource.m

// note: manually get state from terminal via:
//       ioreg -r -k AppleClamshellState -d 4 | grep AppleClamshellState


#import "Lid.h"
#import "Consts.h"
#import "Queue.h"
#import "Logging.h"
#import "Monitor.h"
#import "AuthEvent.h"
#import "Utilities.h"
#import "Preferences.h"
#import "UserAuthMonitor.h"
#import "FrameworkInterface.h"


/* GLOBALS */

//last state
// sometimes multiple notifications are delivered!?
LidState lastLidState;

//lid obj
extern Lid* lid;

//queue object
extern Queue* eventQueue;

//user auth event listener
extern UserAuthMonitor* userAuthMonitor;

//preferences obj
extern Preferences* preferences;

//DnD framework interface obj
extern FrameworkInterface* framework;

//callback for power/lid events
static void pmDomainChange(void *refcon, io_service_t service, uint32_t messageType, void *messageArgument)
{
    //lid state
    int lidState = stateUnavailable;
    
    //sleep bit
    int sleepState = -1;

    //sanity check
    // ignore any messages that are related to lid state
    if(kIOPMMessageClamshellStateChange != messageType)
    {
        //bail
        goto bail;
    }

    //if user explicity set disabled
    // bail here, to ignore everything
    if(YES == [preferences.preferences[PREF_IS_DISABLED] boolValue])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"client disabled DnD, so ignoring lid open event");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"got 'kIOPMMessageClamshellStateChange' message");
    
    //get state
    lidState = ((int) messageArgument & kClamshellStateBit);
    
    //get sleep state
    sleepState = !!(((int)messageArgument & kClamshellSleepBit));
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"lid state: %@ (sleep bit: %d)", (lidState) ? @"closed" : @"open", sleepState]);
    
    //(new) open?
    if( (stateOpen == lidState) &&
        (stateOpen != lastLidState) )
    {
        //update 'prev' state
        lastLidState = stateOpen;
        
        //dbg msg
        // log to file
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"[NEW EVENT] lid state: open (sleep state: %d)", sleepState]);
        
        //touch id mode?
        // wait up to 5 seconds, and ignore event if user auth'd via biometrics
        if(YES == [preferences.preferences[PREF_TOUCHID_MODE] boolValue])
        {
            //user auth'd via touchID?
            if(YES == authViaTouchID())
            {
                //dbg msg
                // log to file
                logMsg(LOG_DEBUG|LOG_TO_FILE, @"user authenticated via touchID, so ignoring event");
                
                //bail
                // will ignore the event
                goto bail;
            }
            
            //dbg msg
            logMsg(LOG_DEBUG, @"no touchID auth event found, so will process event");
        }
        
        //process event
        // report to user, execute actions, etc
        [lid processEvent];
    }
    
    //(new) close?
    else if( (stateClosed == lidState) &&
             (stateClosed != lastLidState) )
    {
        //update 'prev' state
        lastLidState = stateClosed;
        
        //dbg msg
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"[NEW EVENT] lid state: closed (sleep state: %d)", sleepState]);
    }
    
bail:
    
    return;
}

//check if user auth'd
// a) within last 5 seconds
// b) via biometrics (touchID)
BOOL authViaTouchID()
{
    //result
    BOOL touchIDAuth = NO;
    
    //user auth events monitor
    UserAuthMonitor* userAuthMonitor = nil;
    
    //auth event
    AuthEvent* authEvent = nil;
    
    //init user auth monitor
    userAuthMonitor = [[UserAuthMonitor alloc] init];
    
    //kick off monitor for user auth events
    // do in background as it should never return
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //monitor
        if(YES != [userAuthMonitor start])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to initialize user auth monitoring (for touchID events)"]);
        }
        
    });
    
    //check up to 5 seconds
    for(int i=0; i<=5; i++)
    {
        //try grab
        authEvent = userAuthMonitor.authEvent;
        if( (nil != authEvent) &&
            ([authEvent.timestamp timeIntervalSinceNow] >= -5) )
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"user auth'd: %@", userAuthMonitor.authEvent]);
            
            //touch ID?
            if(YES == authEvent.wasTouchID)
            {
                //happy
                touchIDAuth =  YES;
            }
            
            //either way break
            // as auth event happened
            break;
        }
        
        //nap 1 second
        [NSThread sleepForTimeInterval:1.0];
    }
    
    //tell user auth monitor to sleep
    [userAuthMonitor stop];
           
bail:
      
    return touchIDAuth;
}

@implementation Lid

@synthesize client;
@synthesize dispatchGroup;
@synthesize dispatchGroupEmpty;

//init
- (id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //init
        dispatchQ = NULL;
        
        //init
        notificationPort = NULL;
        
        //init
        notification = 0;
        
        //init
        lastLidState = stateUnavailable;
            
        //init dispatch group for dismiss events
        dispatchGroup = dispatch_group_create();
        
        //start empty
        dispatchGroupEmpty = YES;
    
        //init client device
        // a) there's an identity
        // b) there's a registered device
        if( (nil != framework.identity) &&
            (nil == preferences.preferences[PREF_REGISTERED_DEVICES]) )
        {
            //init client
            if(YES != [self clientInit])
            {
                //err msg
                logMsg(LOG_ERR, @"failed to initialize DnD client");
            }
        }
        
        //check if user has unregistered device
        // if so, set flag, disconnect and unset client
        if(nil != self.client)
        {
            //any registered device?
            if(0 == [[self.client getShadowSync].state.reported.endpoints count])
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"user unregistered device via phone, unregistering locally & disconnecting");
                
                //update preferences
                // pass in blank list to 'unregister'
                if(YES != [preferences update:@{PREF_REGISTERED_DEVICES:@[]}])
                {
                    //err msg
                    logMsg(LOG_ERR, @"failed to updated preferences ('device registered' : NO)");
                }
                
                //disconnect client
                [self.client disconnect];
                
                //unset
                self.client = nil;
            }
        }
    }
    
    return self;
}

//init dnd client
-(BOOL)clientInit
{
    //flag
    BOOL initialized = NO;
    
    //init client
    client = [[DNDClientMac alloc] initWithDndIdentity:framework.identity sendCA:true background:true];
    if(nil == self.client)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to initialize DnD client for lid events");
        
        //bail
        goto bail;
    }
    
    //set delegate
    client.delegate = self;
    
    //indicate we want tasking
    [client handleTasksWithFramework];
    
    //happy
    initialized = YES;
    
bail:
    
    return initialized;
}

//register for notifications
-(BOOL)register4Notifications
{
    //return var
    BOOL registered = NO;
    
    //status var
    kern_return_t status = kIOReturnError;
    
    //root domain for power management
    io_service_t powerManagementRD = MACH_PORT_NULL;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"registering for lid notifications");
    
    //make sure state is ok
    if(stateUnavailable == getLidState())
    {
        //err msg
        logMsg(LOG_ERR, @"failed to get lid state, so aborting lid notifications registration");
        
        //error
        goto bail;
    }

    //create queue
    dispatchQ = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
    if(NULL == dispatchQ)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to create dispatch queue for lid notifications");
        
        //error
        goto bail;
    }
    
    //set target
    dispatch_set_target_queue(dispatchQ, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    
    //create notification port
    notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
    if(NULL == notificationPort)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to create notification port for lid notifications");
        
        //error
        goto bail;
    }
    
    //set dispatch queue
    IONotificationPortSetDispatchQueue(notificationPort, dispatchQ);
    
    //get matching service for power management root domain
    powerManagementRD = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPMrootDomain"));
    if(0 == powerManagementRD)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to get power management root domain for lid notifications");
        
        //error
        goto bail;
    }
    
    //add interest notification
    status = IOServiceAddInterestNotification(notificationPort, powerManagementRD, kIOGeneralInterest,
                                     pmDomainChange, &lidState, &notification);
    if(KERN_SUCCESS != status)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to get add interest notifcation for lid notifications (error: 0x:%x)", status]);
        
        //error
        goto bail;
    }
    
    //happy
    registered = YES;

bail:

    //release
    if(MACH_PORT_NULL != powerManagementRD)
    {
        //release
        IOObjectRelease(powerManagementRD);
        
        //unset
        powerManagementRD = MACH_PORT_NULL;
    }
    
    return registered;
}

//register for notifications
-(void)unregister4Notifications
{
    //dbg msg
    logMsg(LOG_DEBUG, @"unregistering lid notifications");
    
    //release queue
    //dispatch_release(dispatchQ);
    
    //destroy notification port
    if(NULL != notificationPort)
    {
        //destroy
        IONotificationPortDestroy(notificationPort);
        
        //unset
        notificationPort = NULL;
    }
    
    //unset dispatch queue
    //IONotificationPortSetDispatchQueue(notificationPort, dispatchQ);
    
    //TODO: like this?
    //release notification
    if(0 != notification)
    {
        //release
        IOObjectRelease(notification);
        
        //unset
        notification = 0;
    }
    
    //add interest notification
    //status = IOServiceAddInterestNotification(notificationPort, powerManagementRD, kIOGeneralInterest,
    //                                          pmDomainChange, &lidState, &notification);
    

    return;
}

//proces lid open event
// report to user, execute cmd, send alert to server, etc
-(void)processEvent
{
    //monitor obj
    Monitor* monitor = nil;
    
    //console user
    NSString* consoleUser = nil;
    
    //only add events to queue
    // when client is not running in passive mode
    if(YES != [preferences.preferences[PREF_PASSIVE_MODE] boolValue])
    {
        //add to global queue
        // this will trigger processing of alert to user
        [eventQueue enqueue:@{ALERT_TIMESTAMP:[NSDate date]}];
    }
    //passive mode
    // just log a msg about this fact
    else
    {
        //dbg msg
        // also log to file
        logMsg(LOG_DEBUG|LOG_TO_FILE, @"client in passive mode, so won't display");
    }
    
    //monitor
    // start with first, as other actions might take a bit...
    if(YES == [preferences.preferences[PREF_MONITOR_ACTION] boolValue])
    {
        //dbg msg
        logMsg(LOG_DEBUG|LOG_TO_FILE, @"enabling monitoring (processes, usb, logins, etc.)");
        
        //alloc/init
        monitor = [[Monitor alloc] init];
        
        //kick off monitoring
        if(YES != [monitor start:MONITORING_TIMEOUT])
        {
            //err msg
            logMsg(LOG_ERR|LOG_TO_FILE, @"failed to start monitoring");
        }
    }

    //execute cmd?
    if( (YES == [preferences.preferences[PREF_EXECUTE_ACTION] boolValue]) &&
        (0 != [preferences.preferences[PREF_EXECUTION_PATH] length] ) )
    {
        //dbg msg
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"executing: %@", preferences.preferences[PREF_EXECUTION_PATH]]);
        
        //exec payload
        if(YES != [self executeAction:preferences.preferences[PREF_EXECUTION_PATH]])
        {
            //err msg
            logMsg(LOG_ERR|LOG_TO_FILE, [NSString stringWithFormat:@"failed to execute %@", preferences.preferences[PREF_EXECUTION_PATH]]);
        }
    }
    
    //before sending it to server
    // check and init client if needed
    if( (nil == self.client) &&
        (nil != framework.identity) &&
        (nil != preferences.preferences[PREF_REGISTERED_DEVICES]) )
    {
        //init client
        if(YES != [self clientInit])
        {
            //err msg
            logMsg(LOG_ERR, @"failed to initialize DnD client");
            
            //bail
            //goto bail;
        }
    }
    
    //send to server
    // and wait for dismiss
    if(nil != self.client)
    {
        //get user
        consoleUser = getConsoleUser();
        if(0 == consoleUser.length)
        {
            //defult
            consoleUser = @"unknown";
        }
        
        //dbg msg
        // and log to file
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"sending alert to server (user: %@)", consoleUser]);
        
        //send
        [self.client sendAlertWithUuid:[NSUUID UUID] userName:consoleUser completion:^(NSNumber* response)
        {
             //log
             logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"response from server: %@", response]);
             
        }];
        
        //wait for dismiss
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //wait
            [self wait4Dismiss];
            
        });
    }
    
    //didn't send
    // ...as not registered w/ server
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"did not send to server - no client/registered device");
    }
    
bail:
    
    return;
}

//wait for dismiss
// note: handles multiple client via dispatch group
-(void)wait4Dismiss
{
    //enter dispatch group
    dispatch_group_enter(self.dispatchGroup);
    
    //debug msg
    logMsg(LOG_DEBUG, @"entered 'wait/dismiss' dispatch group");
    
    //sync
    @synchronized(self)
    {
        //only start listening if nobody else is
        if(YES == self.dispatchGroupEmpty)
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"dispatch group currently empty");
            
            //set flag
            self.dispatchGroupEmpty = NO;
            
            //listen
            [self.client listenOnDelegate:nil];
            
            //'register' notification code
            // will be invoked when everything times out
            dispatch_group_notify(self.dispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
                
                //dbg msg
                logMsg(LOG_DEBUG, @"'wait/dismiss' dispatch group notified, disconnecting");
                
                //disconnect client
                [self.client disconnect];
                
                //unset flag
                self.dispatchGroupEmpty = YES;
                
            });
        }
        
    }//sync
    
    //wait for 5 minutes
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (60 * 5) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        //debug msg
        logMsg(LOG_DEBUG, @"leaving 'wait/dismiss' dispatch group");
        
        //done
        // so leave!
        dispatch_group_leave(self.dispatchGroup);
        
    });
    
    return;
}

//(framework) callback delegate
// invoked when user dimisses event on phone
-(void)didGetDismissEvent:(Event *)event {

    //broadcast event
    [[NSNotificationCenter defaultCenter] postNotificationName:DISMISS_NOTIFICATION object:nil userInfo:nil];
    
    return;
}


//execute action
-(BOOL)executeAction:(NSString*)path
{
    //flag
    BOOL executed = NO;
    
    //return (from 'system()')
    int status = -1;
    
    //execute it
    // ...quick and dirty
    status = system(path.UTF8String);
    if(-1 == status)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"execing %@ failed with %d", path, status]);
        
        //bail
        goto bail;
    }
    
    //happy
    executed = YES;
    
bail:
    
    return executed;
}

//unregister for notifications?

@end
