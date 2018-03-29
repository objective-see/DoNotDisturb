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
    
    //preferences
    NSDictionary* currentPrefs = nil;
    
    //ignore any messages that are related to lid state
    if(kIOPMMessageClamshellStateChange != messageType)
    {
        //bail
        goto bail;
    }
    
    //get prefs
    currentPrefs = [preferences get:nil];

    //if user explicity set disabled
    // bail here, to ignore everything
    if(YES == [currentPrefs[PREF_IS_DISABLED] boolValue])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"client disabled DnD, so ignoring lid event");
        
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
    // OS sometimes delivers 2x events, so ignore same same
    if( (stateOpen == lidState) &&
        (stateOpen != lastLidState) )
    {
        //ignore if lid isn't really open
        // on reboot, OS may deliver 'open' message if external monitors are connected
        if(stateOpen != getLidState())
        {
            //bail
            goto bail;
        }
        
        //update 'prev' state
        lastLidState = stateOpen;
        
        //dbg msg
        // log to file
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"[NEW EVENT] lid state: open (sleep state: %d)", sleepState]);
        
        //touch id mode?
        // wait up to 5 seconds, and ignore event if user auth'd via biometrics
        if(YES == [currentPrefs[PREF_TOUCHID_MODE] boolValue])
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
    // OS sometimes delivers 2x events, so ignore same same
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
        
        //init to current state
        lastLidState = getLidState();
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"initial lid state: %d", lastLidState]);
            
        //init dispatch group for dismiss events
        dispatchGroup = dispatch_group_create();
        
        //start empty
        self.dispatchGroupEmpty = YES;
        
        //init client device, when:
        // a) there's an identity
        // b) there's a registered device
        if( (nil != framework.identity) &&
            (0 != [[preferences get:PREF_REGISTERED_DEVICES][PREF_REGISTERED_DEVICES] count]) )
        {
            //init client
            if(YES != [self clientInit])
            {
                //err msg
                logMsg(LOG_ERR, @"failed to initialize DnD client");
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
    
    //dbg msg
    logMsg(LOG_DEBUG, @"initilizing DnD client");
    
    //init client
    client = [[DNDClientMac alloc] initWithDndIdentity:framework.identity sendCA:true background:true];
    if(nil == self.client)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to initialize client");
        
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

//unregister for notifications
-(void)unregister4Notifications
{
    //dbg msg
    logMsg(LOG_DEBUG, @"unregistering lid notifications");
    
    //release notification
    if(0 != notification)
    {
        //release
        IOObjectRelease(notification);
        
        //unset
        notification = 0;
        
        //dbg msg
        logMsg(LOG_DEBUG, @"released service interest notification");
    }
    
    //destroy notification port
    if(NULL != notificationPort)
    {
        //set queue to NULL
        IONotificationPortSetDispatchQueue(notificationPort, NULL);
        
        //unset dispatch queue
        dispatchQ = NULL;

        //destroy port
        IONotificationPortDestroy(notificationPort);
        
        //unset
        notificationPort = NULL;
        
        //dbg msg
        logMsg(LOG_DEBUG, @"destroyed notification port");
    }
    
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
    
    //current prefs
    NSDictionary* currentPrefs = nil;
    
    //timestamp
    NSDate* timestamp = nil;
    
    //get current prefs
    currentPrefs = [preferences get:nil];
    
    //init timestamp
    timestamp = [NSDate date];
    
    //only add events to queue
    // when client is not running in passive mode
    if(YES != [currentPrefs[PREF_PASSIVE_MODE] boolValue])
    {
        //add to global queue
        // this will trigger processing of alert to user
        [eventQueue enqueue:@{ALERT_TIMESTAMP:timestamp}];
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
    if(YES == [currentPrefs[PREF_MONITOR_ACTION] boolValue])
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
    if( (YES == [currentPrefs[PREF_EXECUTE_ACTION] boolValue]) &&
        (0 != [currentPrefs[PREF_EXECUTE_PATH] length] ) )
    {
        
        //dbg msg
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"executing: %@ as %@", currentPrefs[PREF_EXECUTE_PATH], currentPrefs[PREF_EXECUTE_USER]]);
        
        //exec payload
        if(YES != [self executeAction:currentPrefs[PREF_EXECUTE_PATH] user:currentPrefs[PREF_EXECUTE_USER]])
        {
            //err msg
            logMsg(LOG_ERR|LOG_TO_FILE, [NSString stringWithFormat:@"failed to execute %@", currentPrefs[PREF_EXECUTE_PATH]]);
        }
    }
    
    //before sending it to server
    // check and init client if needed
    if( (nil == self.client) &&
        (nil != framework.identity) &&
        (nil != currentPrefs[PREF_REGISTERED_DEVICES]) )
    {
        //init client
        if(YES != [self clientInit])
        {
            //err msg
            logMsg(LOG_ERR, @"failed to initialize client for framework");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"(re)initialized client for framework");
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
        [self.client sendAlertWithUuid:[NSUUID UUID] userName:consoleUser date:timestamp completion:^(NSNumber* response)
        {
            //log
            logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"response from server: %@", response]);
            
            //after getting server response
            // update list of registered devices...
            [preferences updateRegisteredDevices];
            
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
            // will be invoked when *everything* times out
            dispatch_group_notify(self.dispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
                
                //unset flag
                self.dispatchGroupEmpty = YES;
                
                //disconnect client
                [self.client disconnect];
                
                //unset client
                self.client = nil;
                
                //dbg msg
                logMsg(LOG_DEBUG, @"'wait/dismiss' dispatch group notified, disconnected/unset client");
                
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
// invoked when user dimisses event via phone
-(void)didGetDismissEvent:(Event *)event
{
    //broadcast event to everybody
    [[NSNotificationCenter defaultCenter] postNotificationName:DISMISS_NOTIFICATION object:nil userInfo:nil];
    
    return;
}

//execute action
-(int)executeAction:(NSString*)path user:(NSString*)user
{
    //results
    NSDictionary* results = nil;
    
    //result
    int result = -1;
    
    //exec script
    // su man -c catman
    results = execTask(@"/usr/bin/su", @[user, @"-c", path], YES);
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"executed %@ as %@, results:%@", path, user, results]);
    
    //grab result
    if(nil != results)
    {
        //grab
        result = [results[EXIT_CODE] intValue];
    }
    
    //no output means error
    // i.e. task exception, etc
    else
    {
        result = -1;
    }
    
bail:
    
    return result;
}

@end
