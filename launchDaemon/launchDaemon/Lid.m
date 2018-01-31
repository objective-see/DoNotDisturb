//
//  Lid.m
//  launchDaemon
//
//  Created by user on 11/25/17.
//  Copyright © 2017 Objective-See. All rights reserved.
//

// code inspired by:
//  https://github.com/zarigani/ClamshellWake/blob/master/ClamshellWake.cpp
//  https://github.com/dustinrue/ControlPlane/blob/master/Source/LaptopLidEvidenceSource.m

// TODO: test external monitor w/ laptop shut?

// note: manually get state from terminal via:
//       ioreg -r -k AppleClamshellState -d 4 | grep AppleClamshellState


#import "Lid.h"
#import "Consts.h"
#import "Queue.h"
#import "Logging.h"
#import "Monitor.h"
#import "ProcListener.h"
#import "UserAuthMonitor.h"

#import <CoreTelephony/CoreTelephonyDefines.h>

/* GLOBALS */

//last state
// ->sometimes multiple notifications are delivered!?
LidState lastLidState;

//lid obj
// allows callback to access obj
Lid* lidObj;

//queue object
extern Queue* eventQueue;

//user auth event listener
extern UserAuthMonitor* userAuthMonitor;

//callback for power/lid events
static void pmDomainChange(void *refcon, io_service_t service, uint32_t messageType, void *messageArgument)
{
    //lid state
    int lidState = stateUnavailable;
    
    //sleep bit
    int sleepState = -1;
    
    //preferences
    NSDictionary* preferences = nil;
    
    //sanity check
    // ignore any messages that are related to lid state
    if(kIOPMMessageClamshellStateChange != messageType)
    {
        //bail
        goto bail;
    }
    
    //load prefs
    preferences = [NSMutableDictionary dictionaryWithContentsOfFile:PREFS_FILE];
    
    //if user has disabled
    // bail here to ignore everything
    if(YES == [preferences[PREF_STATUS_DISABLED] boolValue])
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
    logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"lid state: %@ (sleep bit: %d)", (lidState) ? @"closed" : @"open", sleepState]);
    
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
        if(YES == [preferences[PREF_TOUCHID_MODE] boolValue])
        {
            //user auth'd via touchID?
            if(YES == authViaTouchID())
            {
                //dbg msg
                // log to file
                logMsg(LOG_DEBUG|LOG_TO_FILE, @"user authenticated via touchID, so ignoring event");
            }
        }
        
        
        //process event
        // report to user, send email, etc.
        [lidObj processEvent:preferences];
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
    
    //check up to 5 seconds
    for(int i=0; i<=5; i++)
    {
        //auth event within 5 secs?
        if( (nil != userAuthMonitor.lastEvent) &&
            ([userAuthMonitor.lastEvent timeIntervalSinceNow] >= -5) )
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"user auth'd: %@", userAuthMonitor.lastEvent]);
            
            //touch ID?
            if(YES == userAuthMonitor.wasTouchID)
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
           
bail:
      
    return touchIDAuth;
}

@implementation Lid

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
        
        //save into global
        // allows static callback to access
        lidObj = self;
    }
    return self;
}

//get state
-(int)getState
{
    //state
    int state = stateUnavailable;
    
    //registry entry for power management
    io_registry_entry_t powerManagmentRE = MACH_PORT_NULL;
    
    //reference to 'kAppleClamshellStateKey' property
    CFBooleanRef clamshellState = NULL;
    
    //get registry entry for power management root domain
    powerManagmentRE = IORegistryEntryFromPath(kIOMasterPortDefault, kIOPowerPlane ":/IOPowerConnection/IOPMrootDomain");
    if(MACH_PORT_NULL == powerManagmentRE)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to look up the registry entry for 'IOPMrootDomain'");
        
        //error
        goto bail;
    }
    
    //get reference to state of 'kAppleClamshellStateKey'
    clamshellState = (CFBooleanRef)IORegistryEntryCreateCFProperty(powerManagmentRE, CFSTR(kAppleClamshellStateKey), kCFAllocatorDefault, 0);
    if(NULL == clamshellState)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to get property for 'kAppleClamshellStateKey'");
        
        //error
        goto bail;
    }
    
    //get state
    state = (LidState)CFBooleanGetValue(clamshellState);
    
bail:
    
    //release
    if(NULL != clamshellState)
    {
        //release
        CFRelease(clamshellState);
        
        //unset
        clamshellState = NULL;
    }
    
    //release
    if(MACH_PORT_NULL != powerManagmentRE)
    {
        //release
        IOObjectRelease(powerManagmentRE);
        
        //unset
        powerManagmentRE = MACH_PORT_NULL;
    }
    
    return state;
}

//register for notifications
-(BOOL)register4Notifications
{
    //return var
    BOOL registered = NO;
    
    //status var
    kern_return_t status = kIOReturnError;
    
    //root domain for power management
    io_service_t powerManagementRD = 0;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"register for lid notifications");
    
    //make sure state is ok
    if(stateUnavailable == [self getState])
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
    if(0 != powerManagementRD)
    {
        //release
        IOObjectRelease(powerManagementRD);
        
        //unset
        powerManagementRD = 0;
    }
    
    return registered;
}

//proces lid open event
// report to user, send sms, etc
-(void)processEvent:(NSDictionary*)preferences
{
    //process listener obj
    ProcessListener* processListener = nil;
    
    //usb/etc monitor
    Monitor* usbMonitor = nil;
    
    //only add events to queue
    // when client is not running in passive mode
    if(YES != [preferences[PREF_PASSIVE_MODE] boolValue])
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

    //send email?
    if( (YES == [preferences[PREF_EMAIL_ACTION] boolValue]) &&
        (0 != [preferences[PREF_EMAIL_ADDRESS] length] ) )
    {
        //dbg msg
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"sending alert to: %@", preferences[PREF_EMAIL_ADDRESS]]);
        
        //send email
        if(YES != [self sendAlertViaEmail:preferences[PREF_EMAIL_ADDRESS]])
        {
            //err msg
            logMsg(LOG_ERR|LOG_TO_FILE, [NSString stringWithFormat:@"failed to send alert to %@", preferences[PREF_EMAIL_ADDRESS]]);
        }
    }
    
    //execute cmd?
    if( (YES == [preferences[PREF_EXECUTE_ACTION] boolValue]) &&
        (0 != [preferences[PREF_EXECUTION_PATH] length] ) )
    {
        //dbg msg
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"executing: %@", preferences[PREF_EXECUTION_PATH]]);
        
        //exec payload
        if(YES != [self executeAction:preferences[PREF_EXECUTION_PATH]])
        {
            //err msg
            logMsg(LOG_ERR|LOG_TO_FILE, [NSString stringWithFormat:@"failed to execute %@", preferences[PREF_EXECUTION_PATH]]);
        }
    }
    
    //monitor?
    // processes, usb
    // TODO: add thunderbolt
    if(YES == [preferences[PREF_MONITOR_ACTION] boolValue])
    {
        //dbg msg
        logMsg(LOG_DEBUG|LOG_TO_FILE, @"enabling monitoring");
        
        //alloc/init process listener obj
        processListener = [[ProcessListener alloc] init];
        
        //start listening for process events
        // but only up to a minute, then will stop
        // TODO: longer?
        [processListener monitor:60];
        
        //alloc init usb monitor obj
        usbMonitor = [[Monitor alloc] init];
        
        //start monitoring
        // TODO: stop?
        if(YES != [usbMonitor initUSBMonitoring])
        {
            //err msg
            logMsg(LOG_ERR, @"failed to kick off USB monitoring");
        }
        
        //dbg msg
        #ifdef DEBUG
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"initialize USB monitoring");
        }
        #endif
    }
    
bail:
    
    return;
    
}

//TODO: try/except
-(BOOL)sendAlertViaEmail:(NSString*)emailAddresss
{
    //sent
    BOOL sent = NO;
    
    //task
    NSTask* task = nil;
    
    //pipe
    NSPipe* pipe = nil;
    
    //alloc task
    task = [[NSTask alloc] init];
    
    //alloc pipe
    pipe = [[NSPipe alloc] init];
    
    //set path
    task.launchPath = @"/usr/bin/mail";
    
    //set args
    task.arguments = @[@"-s", @"[Do Not Disturb Alert]", emailAddresss];
    
    //init pipe
    [task setStandardInput:pipe];
    
    //launch task
    [task launch];
    
    //add email body
    // TODO: more details
    [[pipe fileHandleForWriting] writeData:[@"lid opened" dataUsingEncoding:NSUTF8StringEncoding]];

    //close pipe
    [[pipe fileHandleForWriting] closeFile];
    
    //wait
    [task waitUntilExit];
    
    //check exit code
    if(0 != task.terminationStatus)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"sending alert email failed with %d", task.terminationStatus]);
        
        //bail
        goto bail;
    }
    
    //happy
    sent = YES;
    
bail:
    
    return sent;
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
