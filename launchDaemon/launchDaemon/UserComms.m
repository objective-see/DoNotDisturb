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
#import "UserCommsInterface.h"
#import <dnd/dnd-swift.h>

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//global queue object
extern Queue* eventQueue;

//global prefs obj
extern Preferences* preferences;

//DnD identity
extern DNDIdentity* identity;


@implementation UserComms
{
    NSString *_clientid;
    DNDIdentity *_identity;
    NSDictionary *_registration;
    dispatch_semaphore_t _deviceRegistered;
}

@synthesize currentStatus;
@synthesize dequeuedAlert;


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
       
        //TODO:
        _deviceRegistered = dispatch_semaphore_create(0);
    }
    
    return self;
}

//load preferences and send them back to client
-(void)getPreferences:(void (^)(NSDictionary* alert))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: get preferences");
    
    //preference obj has em
    reply(preferences.preferences);
    
    return;
}


//process alert request from client
// blocks for queue item, then sends to client
-(void)qrcRequest:(void (^)(NSData *))reply
{
    //qrc data
    NSData* qrcData = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: qrc request");
    
    //get qrc data from identity obj
    if(nil != identity)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"querying framework 'identity' object to get QRC code");
        
        //get
        qrcData = identity.qrCodeData;
    }
    
    //TODO: rem
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"qrc data from framework: %@/%@", qrcData.bytes, [[NSString alloc] initWithData:qrcData encoding:NSUTF8StringEncoding]]);
    
    reply(qrcData);
    
    return;
}

//delegate callback when a registered device
-(void)didDeviceRegister:(RegisteredEndpoint*)endpoint
{
    NSLog(@"Recieved registration ack from %@", endpoint.name);

    // save off the endpoint name
    _registration = @{@"Device Name": endpoint.name};

    // signal complete
    dispatch_semaphore_signal(_deviceRegistered);
}

//wait for phone to complete registration
// calls into framework that comms w/ server to wait for phone
-(void)recvRegistrationACK:(void (^)(NSDictionary* registrationInfo))reply;
{
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: recv registration ACK");

    DNDClientMac *client = [[DNDClientMac alloc] initWithDndIdentity:_identity sendCA:true background:true];
    if (client) {
        client.delegate = self;

        // Might need to async this to get delegate callback
        [client listenOnDelegate:@[client.deviceRegisteredTopic]];

        // wait for the delegate callback to hit
        // @TODO: might want to time this out
        dispatch_semaphore_wait(_deviceRegistered, DISPATCH_TIME_FOREVER);

        // note the info to be returned
        reply(_registration);

        // disconnect the client
        [client disconnect];
    } else {
        reply(nil);
    }
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

    DNDClientMac *client = [[DNDClientMac alloc] initWithDndIdentity:_identity sendCA:true background:true];
    if (client) {
        // Send an alert. @TODO: fill in username and use a better uuid if necessary
        NSUUID *alertid = [NSUUID UUID];
        NSNumber *num = [client sendAlertSyncWithUuid:alertid userName:@"User1"];
        NSLog(@"Sent alert %@, published %@", alertid, num);
    }
    
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

// Delegate callback when a registered device tells us all is good
-(void)didGetDismissEvent:(Event *)event {
    NSLog(@"Recieved dismiss event");

    // signal complete (TODO: Change this signal)
    dispatch_semaphore_signal(_deviceRegistered);
}

//process alert dismiss request from client
// blocks until framework tell us it was dismissed via the phone
-(void)alertDismiss:(void (^)(NSDictionary* alert))reply
{
    //alert details
    NSMutableDictionary* alert = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: alert dismiss");
    
    //TODO:
    [NSThread sleepForTimeInterval:10000];

    //@TODO: This is not a good for this. Move this code to the proper place
    DNDClientMac *client = [[DNDClientMac alloc] initWithDndIdentity:_identity sendCA:true background:true];
    if (client) {
        // set ourselves as the delegate so we get delegate callback for alert dismiss
        client.delegate = self;

        // tell the framework to handle the rest of the tasking
        [client handleTasksWithFramework];

        [client listenOnDelegate:nil];

        // wait for the delegate callback to hit
        // @TODO: might want to time this out, change semaphore
        dispatch_semaphore_wait(_deviceRegistered, DISPATCH_TIME_FOREVER);
    }
    
    //log to file
    logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"sending alert dismiss to login item to display to user: %@", alert]);
    
    //return alert
    reply(alert);
    
    return;
}

@end
