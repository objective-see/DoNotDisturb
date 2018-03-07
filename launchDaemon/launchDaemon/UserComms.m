//
//  file: UserComms.m
//  project: DnD (launch daemon)
//  description: interface for user componets
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Queue.h"
#import "Logging.h"
#import "UserComms.h"
#import "Preferences.h"
#import "FrameworkInterface.h"
#import "UserCommsInterface.h"

#import <dnd/dnd-swift.h>

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//global queue object
extern Queue* eventQueue;

//global prefs obj
extern Preferences* preferences;

//framework interface obc
extern FrameworkInterface* framework;

@implementation UserComms

@synthesize currentStatus;
@synthesize dequeuedAlert;
@synthesize registrationInfo;
@synthesize registrationSema;

//init
// set connection to unknown
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //set status
        self.currentStatus = STATUS_CLIENT_UNKNOWN;
    }
    
    return self;
}

//XPC method
// returns preferences to client
-(void)getPreferences:(void (^)(NSDictionary* alert))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: get preferences");
    
    //get current prefs
    reply([preferences get]);
    
    return;
}

//XPC method
// returns QRC data to client
-(void)qrcRequest:(void (^)(NSData *))reply
{
    //qrc data
    NSData* qrcData = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: qrc request");
    
    //need DnD identity obj?
    if(nil == framework.identity)
    {
        //create it
        if(YES != [framework initIdentity:YES])
        {
            //err msg
            logMsg(LOG_ERR, @"failed to initialize DnD identity");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"created DnD identity");
    }
    
    //get qrc data
    qrcData = framework.identity.qrCodeData;

bail:
    
    //return qrc
    reply(qrcData);
    
    return;
}

//delegate callback when a registered device
-(void)didDeviceRegister:(RegisteredEndpoint*)endpoint
{
    //dbg msg
    logMsg(LOG_DEBUG, @"delegate callback (from framework) 'didDeviceRegister' invoked");
    
    //save info
    // also add host name
    self.registrationInfo = @{KEY_DEVICE_NAME: endpoint.name, KEY_HOST_NAME:[[NSHost currentHost] localizedName]};

    //update preferences
    if(YES != [preferences update:@{PREF_REGISTERED_DEVICES:@{endpoint.token:endpoint.name}}])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to updated preferences ('device registered' : %@)", endpoint.name]);
    }
    
    //signal sema
    // triggers response to client
    dispatch_semaphore_signal(self.registrationSema);
       
    return;
}

//XPC method:
// wait for phone to complete registrations...
// calls into framework that comms w/ server to wait for phone
-(void)recvRegistrationACK:(void (^)(NSDictionary* registrationInfo))reply;
{
    //client
    DNDClientMac *client = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: recv registration ack/info");
    
    //reset any registration info
    self.registrationInfo = nil;

    //init registration sema
    if(0 == self.registrationSema)
    {
        //create
        registrationSema = dispatch_semaphore_create(0);
    }
    
    //init client
    client = [[DNDClientMac alloc] initWithDndIdentity:framework.identity sendCA:true background:true];
    if(nil == client)
    {
        //bail
        goto bail;
    }
    
    //set delegate
    client.delegate = self;
    
    //listen on 'device registered' topic
    [client listenOnDelegate:@[client.deviceRegisteredTopic]];
    
    //dbg msg
    logMsg(LOG_DEBUG, @"listening on 'deviceRegisteredTopic' topic...");
    
    //wait until registration info has come back
    dispatch_semaphore_wait(self.registrationSema, DISPATCH_TIME_FOREVER);
    
    //disconnect client
    [client disconnect];
    
    //dbg msg
    logMsg(LOG_DEBUG, @"received & processed registration ACK from server");
    
bail:
    
    //return registration info
    reply(self.registrationInfo);
    
    return;
}

//update preferences
-(void)updatePreferences:(NSDictionary *)prefs
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: update preferences (%@)", preferences]);
    
    //call into prefs obj to update
    if(YES != [preferences update:prefs])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to save preferences to %@", PREFS_FILE]);
    }
    
    return;
}

//process alert request from client
// blocks for queue item, then sends to client
-(void)alertRequest:(void (^)(NSDictionary* alert))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: alert request");
    
    //reset
    self.dequeuedAlert = nil;
    
    //read off queue
    // will block until alert is ready
    self.dequeuedAlert = [eventQueue peek];

    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found alert on queue: %@", self.dequeuedAlert]);
    
    //log to file
    logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"sending alert to login item to display to user: %@", self.dequeuedAlert]);

    //return alert
    reply(self.dequeuedAlert);
    
    return;
}

//invoke when alert has been displayed
// for now, just remove it from the queue
-(void)alertResponse
{
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: alert response");
    
    //remove
    [eventQueue dequeue];
    
    //unset
    self.dequeuedAlert = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"removed alert, as it's been consumed by the user");
}

//process alert dismiss request from client
// blocks until framework tell us it was dismissed via the phone
-(void)alertDismiss:(void (^)(NSDictionary* alert))reply
{
    //alert details
    __block NSMutableDictionary* alert = nil;
    
    //observer for dimiss alerts
    id dismissObserver = nil;
    
    //wait sema
    dispatch_semaphore_t semaphore = NULL;
    
    //init sema
    semaphore = dispatch_semaphore_create(0);
    
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: alert dismiss");
    
    //register listener for user auth events
    // on event; just log to the log file for now...
    dismissObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DISMISS_NOTIFICATION object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
    {
        //signal that a response came in
        dispatch_semaphore_signal(semaphore);
         
    }];
    
    //XPC is async
    // wait for preferences from daemon
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    

    //log to file
    logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"sending alert dismiss to login item to display to user: %@", alert]);
    
    //return alert
    reply(alert);
    
    return;
}

@end
