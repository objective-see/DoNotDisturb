//  file: Triggers.m
//  project: DND (launch daemon)
//  description: generic management of various triggers
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Queue.h"
#import "Logging.h"
#import "Monitor.h"
#import "Triggers.h"
#import "AuthEvent.h"
#import "Utilities.h"
#import "Preferences.h"
#import "UserAuthMonitor.h"
#import "FrameworkInterface.h"

/* GLOBALS */

//trigger obj
extern Triggers* triggers;

//queue object
extern Queue* eventQueue;

//user auth event listener
extern UserAuthMonitor* userAuthMonitor;

//preferences obj
extern Preferences* preferences;

//DND framework interface obj
extern FrameworkInterface* framework;

//check if user auth'd
// a) within last 10 seconds
// b) via biometrics (touchID)
BOOL authViaTouchID()
{
    //result
    __block BOOL touchIDAuth = NO;
    
    //user auth events monitor
    UserAuthMonitor* userAuthMonitor = nil;
    
    //notifcation
    __block id userAuthObserver = nil;
    
    //auth event
    __block AuthEvent* authEvent = nil;
    
    //wait semaphore
    dispatch_semaphore_t semaphore = 0;

    //init user auth monitor
    userAuthMonitor = [[UserAuthMonitor alloc] init];
    
    //init sema
    semaphore = dispatch_semaphore_create(0);
    
    //kick off monitor for user auth events
    // do in background, as it should never return
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
    
    //register listener for user auth events
    // executes block to process auth events as they come in
    userAuthObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AUTH_NOTIFICATION object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
    {
        //grab event
        authEvent = notification.userInfo[AUTH_NOTIFICATION];
        if(YES != [authEvent isKindOfClass:[AuthEvent class]])
        {
            //ignore
            return;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got user auth event: %@", authEvent]);
        
        //ignore unsuccessful auth id attempts
        if(noErr != authEvent.result)
        {
            //ignore
            return;
        }
            
        //set touch id flag
        touchIDAuth = authEvent.wasTouchID;
        
        //signal sema
        // either way, got an auth event and touch id flag has been set
        dispatch_semaphore_signal(semaphore);
        
    }];
    
    //monitor
    if(YES != [userAuthMonitor start])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to initialize user auth monitoring (for touchID events)"]);
    }
    
    });
    
    //wait for touch id auth
    // ...up to ten seconds for event
    dispatch_semaphore_wait(semaphore, dispatch_time(0, 10*NSEC_PER_SEC));

    //tell user auth monitor to stop
    [userAuthMonitor stop];
    
    //remove auth observer
    [[NSNotificationCenter defaultCenter] removeObserver:userAuthObserver];
    
    return touchIDAuth;
}

@implementation Triggers


@synthesize client;

@synthesize lidTrigger;
@synthesize powerTrigger;
@synthesize deviceTrigger;
@synthesize dispatchGroup;
@synthesize dispatchBlocks;
@synthesize undeliveredAlert;
@synthesize dispatchGroupEmpty;

//init
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //init lid (trigger) obj
        lidTrigger = [[LidTrigger alloc] init];
        
        //init device (trigger) obj
        deviceTrigger = [[DeviceTrigger alloc] init];
        
        //init power (trigger) obj
        powerTrigger = [[PowerTrigger alloc] init];
        
        //init dispatch group for dismiss events
        dispatchGroup = dispatch_group_create();
        
        //start empty
        self.dispatchGroupEmpty = YES;
        
        //init array for blocks
        dispatchBlocks = [NSMutableArray array];
        
        //should init client?
        if(YES == [self shouldInitClient])
        {
            //init client
            if(YES != [self clientInit])
            {
                //err msg
                logMsg(LOG_ERR, @"failed to initialize DND client");
            }
            //dbg msg
            else
            {
                //dbg msg
                logMsg(LOG_DEBUG, @"initialized DND client for framework");
            }
        }
    }
    
    return self;
}

//init client device, when:
// a) there's an identity
// b) there's a registered device
-(BOOL)shouldInitClient
{
    return ( (nil != framework.identity) &&
             (0 != [[preferences get:PREF_REGISTERED_DEVICES][PREF_REGISTERED_DEVICES] count]) );
}

//init dnd client
-(BOOL)clientInit
{
    //flag
    BOOL initialized = NO;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"initializing DND client");
    
    //init client
    client = [[DNDClientMac alloc] initWithDndIdentity:framework.identity sendCA:YES background:YES taskable:YES];
    if(nil == self.client)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to initialize client");
        
        //bail
        goto bail;
    }
    
    //set delegate
    self.client.delegate = self;
    
    //indicate we want tasking
    [self.client handleTasksWithFramework:[[preferences get:nil][PREF_NO_REMOTE_TASKING] boolValue]];
    
    //happy
    initialized = YES;
    
bail:
    
    return initialized;
}

//toggle trigger(s)
-(void)toggle:(NSUInteger)type state:(NSControlStateValue)state
{
    //current prefs
    NSDictionary* currentPrefs = nil;
    
    //dbd msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"toggling trigger (type: %lu, state: %lu)", (unsigned long)type, state]);
    
    //enable based on type
    switch(type)
    {
        //all
        // based on triggers
        case ALL_TRIGGERS:
            
            //dbg msg
            logMsg(LOG_DEBUG, @"toggling all triggers");
            
            //get current prefs
            currentPrefs = [preferences get:nil];
            
            //lid trigger?
            if(YES == [currentPrefs[PREF_LID_TRIGGER] boolValue])
            {
                //toggle
                [self.lidTrigger toggle:state];
            }
            
            //device trigger?
            if(YES == [currentPrefs[PREF_DEVICE_TRIGGER] boolValue])
            {
                //toggle
                [self.deviceTrigger toggle:state];
            }
            
            //power trigger
            if(YES == [currentPrefs[PREF_POWER_TRIGGER] boolValue])
            {
                //toggle
                [self.powerTrigger toggle:state];
            }
            
            break;
            
        //lid trigger
        case LID_TRIGGER:
            
            //toggle
            [self.lidTrigger toggle:state];
            
            break;
        
        //device trigger
        case DEVICE_TRIGGER:
            
            //toggle
            [self.deviceTrigger toggle:state];
            
            break;
            
        //power trigger
        case POWER_TRIGGER:
            
            //toggle
            [self.powerTrigger toggle:state];
            
            break;

            
        default:
            break;
    }
    
    return;
}

//proces trigger event
// report to user, execute cmd, send alert to server, etc
-(void)processEvent:(NSUInteger)type info:(NSDictionary*)info
{
    //monitor obj
    Monitor* monitor = nil;

    //current prefs
    NSDictionary* currentPrefs = nil;
    
    //get current prefs
    currentPrefs = [preferences get:nil];
    
    //auth mode?
    // wait up to 10 seconds, and ignore event if user auth'd via biometrics or apple watch
    if(YES == [currentPrefs[PREF_AUTH_MODE] boolValue])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"'auth' mode enabled, waiting up to 10 seconds for biometric auth || apple watch event");
        
        //TODO: add apple watch
        
        //user auth'd via touchID?
        // will wait for up to 10 seconds
        if(YES == authViaTouchID())
        {
            //dbg msg
            // log to file
            logMsg(LOG_DEBUG|LOG_TO_FILE, @"user authenticated via touchID, so ignoring event");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"no touch id auth event found, so will continue processing event");
    }
    
    //only add events to queue
    // when client is not running in passive mode
    if(YES != [currentPrefs[PREF_PASSIVE_MODE] boolValue])
    {
        //add to global queue
        // this will trigger processing of alert to user
        [eventQueue enqueue:@{ALERT_TYPE:[NSNumber numberWithInteger:type], ALERT_TIMESTAMP:[NSDate date], ALERT_INFO:info}];
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
        if(0 != [self executeAction:currentPrefs[PREF_EXECUTE_PATH] user:currentPrefs[PREF_EXECUTE_USER]])
        {
            //err msg
            logMsg(LOG_ERR|LOG_TO_FILE, [NSString stringWithFormat:@"failed to execute %@", currentPrefs[PREF_EXECUTE_PATH]]);
        }
    }
    
    //before sending it to server
    // check and init client if needed
    if( (nil == self.client) &&
        (YES == [self shouldInitClient]) )
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
        logMsg(LOG_DEBUG, @"(re)initialized DND client for framework");
    }
    
    //registered device?
    // send alert to server
    if(nil != self.client)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"found registerd device/client, will try send alert to server");
        
        //no undelivered alert?
        // spawn off dispatch to deliver
        if(nil == self.undeliveredAlert)
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"no (prev) alerts undelivered");
            
            //save timestamp
            self.undeliveredAlert = [NSDate date];
            
            //send to server
            // will wait up to x minutes if there's no network connectivity
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                //wait
                [self send2Server:getConsoleUser()];
                
            });
        }
        
        //already send(ing) alert
        // just update, so if network comes online, will use this one (as latest)
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"previously alert undelivered, just updating that...");
            
            //save timestamp
            self.undeliveredAlert = [NSDate date];
        }
    }
    
    //didn't send
    // ...as not registered w/ server
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"did not send to server, as there's no client/registered device");
    }
    
bail:
    
    return;
}

//send alert to server
// contains extra logic to check/wait for network connectivty
-(void)send2Server:(NSString*)user
{
    //flag
    BOOL sent = NO;
    
    //response
    __block NSNumber* response = nil;
    
    //no user?
    // set to default, but will try again
    if(0 == user.length)
    {
        //default
        user = USER_UNKNOWN;
    }
    
    //try send up to 10 times
    // basically gives time for network to reconnect if lid-shut disconnected wifi, etc...
    for(NSUInteger i=0; i<10; i++)
    {
        //unknown user?
        // try get user again
        if(YES == [user isEqualToString:USER_UNKNOWN])
        {
            //get user
            user = getConsoleUser();
            if(0 == user.length)
            {
                //default
                user = USER_UNKNOWN;
            }
        }
        
        //dbg msg
        // and log to file
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"sending alert to server (user: %@)", user]);
        
        //send
        response = [self.client sendAlertSyncWithUuid:[NSUUID UUID] userName:user date:self.undeliveredAlert];
        if(nil != response)
        {
            //log
            logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"response from server: %@", response]);
            
            //after getting server response
            // update list of registered devices
            [preferences updateRegisteredDevices];
            
            //set flag
            sent = YES;
            
            //wait for dismiss
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                //wait
                [self wait4Dismiss];
                
            });
            
            //done
            break;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"could not reach endpoint - network offline?");
        
        //not online
        //... so tak a nap
        [NSThread sleepForTimeInterval:i*1.5];
    }
    
    //check
    // log err
    if(YES != sent)
    {
        //log
        logMsg(LOG_DEBUG|LOG_TO_FILE, @"unable to deliver alert (network offline?)");
    }
    
    //unset
    // even if we failed to send
    self.undeliveredAlert = nil;
    
    return;
}

//wait for dismiss
// note: handles multiple client via dispatch group
-(void)wait4Dismiss
{
    //dispatch block
    dispatch_block_t dispatchBlock = nil;
    
    //init dispatch block
    dispatchBlock = dispatch_block_create(DISPATCH_BLOCK_ASSIGN_CURRENT, ^{
        
        //debug msg
        logMsg(LOG_DEBUG, @"dispatch block invoked, so leaving 'wait/dismiss' dispatch group");
        
        //done
        // so leave!
        dispatch_group_leave(self.dispatchGroup);
        
    });
    
    //sync
    @synchronized(self)
    {
        //save it
        [self.dispatchBlocks addObject:dispatchBlock];
    }
    
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
            // will be invoked when *everything* times out or is dismissed
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (60 * 5) * NSEC_PER_SEC), dispatch_get_main_queue(),
    ^{
        //dbg msg
        logMsg(LOG_DEBUG, @"dismiss timeout hit");
        
        //invoke dispatch block
        dispatchBlock();
        
        //sync
        @synchronized(self)
        {
            //remove it
            [self.dispatchBlocks removeObject:dispatchBlock];
            
            //dbg msg
            logMsg(LOG_DEBUG, @"removed dispatch block from array");
        }
        
     });
    
    return;
}

//cancel and remove all dipatch blocks
-(void)cancelDispatchBlocks
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"canceling %lu dispatch blocks", (unsigned long)self.dispatchBlocks.count]);
    
    //sync
    @synchronized(self)
    {
        //cancel all
        for(dispatch_block_t dispatchBlock in self.dispatchBlocks)
        {
            //cancel
            dispatch_block_cancel(dispatchBlock);
            
            //leave
            dispatch_group_leave(self.dispatchGroup);
        }
        
        //now, remove all from saved list
        [self.dispatchBlocks removeAllObjects];
    }
    
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
// note: executed with user's permissions
-(int)executeAction:(NSString*)path user:(NSString*)user
{
    //results
    NSDictionary* results = nil;
    
    //result
    int result = -1;
    
    //exec script
    // su -c <user> <path>
    results = execTask(@"/usr/bin/su", @[user, @"-c", path], YES);
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"executed %@ as %@, results:%@", path, user, results]);
    
    //grab result
    if(nil != results[EXIT_CODE])
    {
        //grab
        result = [results[EXIT_CODE] intValue];
    }
    
bail:
    
    return result;
}

@end
