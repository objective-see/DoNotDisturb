//  file: LidTrigger.m
//  project: DND (launch daemon)
//  description: monitor and alert logic for lid open events

// code inspired by:
//  https://github.com/zarigani/ClamshellWake/blob/master/ClamshellWake.cpp
//  https://github.com/dustinrue/ControlPlane/blob/master/Source/LaptopLidEvidenceSource.m

// note: manually get state from terminal via:
//       ioreg -r -k AppleClamshellState -d 4 | grep AppleClamshellState

#import "Consts.h"
#import "Logging.h"
#import "Triggers.h"
#import "Utilities.h"
#import "LidTrigger.h"
#import "Preferences.h"

/* GLOBALS */

//last state
// sometimes multiple notifications are delivered!?
LidState lastLidState;

//triggers object
extern Triggers* triggers;

//preferences obj
extern Preferences* preferences;

//callback for power/lid events
static void pmDomainChange(void *refcon, io_service_t service, uint32_t messageType, void *messageArgument)
{
    //lid state
    int lidState = stateUnavailable;
    
    //sleep bit
    int sleepState = -1;
    
    //preferences
    NSDictionary* currentPrefs = nil;
    
    //timestamp
    NSDate* timestamp = nil;
    
    //init timestamp
    timestamp = [NSDate date];
    
    //ignore any messages that are related to lid state
    if(kIOPMMessageClamshellStateChange != messageType)
    {
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"got 'kIOPMMessageClamshellStateChange' message");
    
    //get prefs
    currentPrefs = [preferences get:nil];

    //if user explicity set disabled
    // bail here, to ignore everything
    if(YES == [currentPrefs[PREF_IS_DISABLED] boolValue])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"client disabled DND, so ignoring lid event");
        
        //update 'prev' state?
        lastLidState = stateOpen;
        
        //bail
        goto bail;
    }
    
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
        
        //process event
        // report to user, server, execute actions, etc.
        [triggers processEvent:LID_TRIGGER info:nil];
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

@implementation LidTrigger

@synthesize lidState;
@synthesize dispatchQ;
@synthesize notification;
@synthesize notificationPort;

//init
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //init
        notificationPort = NULL;
        
        //init
        notification = 0;
        
        //init to current state
        lastLidState = getLidState();
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"initial lid state: %d", lastLidState]);
        
        //init
        dispatchQ = NULL;
    }
    
    return self;
}

//toggle lid notifications
-(BOOL)toggle:(NSControlStateValue)state
{
    //flag
    BOOL wasToggled = NO;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"toggling lid notifications: %lu", state]);
    
    //on?
    // enable
    if(NSOnState == state)
    {
        //enable
        wasToggled = [self enable];
    }
    //off
    // disable
    else
    {
        //disable
        [self disable];
        
        //manually set flag
        wasToggled = YES;
    }
    
    return wasToggled;
}

//register for notifications
-(BOOL)enable
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
-(void)disable
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

@end
