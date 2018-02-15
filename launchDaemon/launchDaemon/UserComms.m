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
#import "UserCommsInterface.h"

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//global queue object
extern Queue* eventQueue;

@implementation UserComms

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
    }
    
    return self;
}

//process alert request from client
// blocks for queue item, then sends to client
-(void)qrcRequest:(void (^)(NSString *))reply
{
    //qrc info
    NSString* qrcInfo = nil;
    
    //TODO: remove
    NSMutableDictionary* info = [NSMutableDictionary dictionary];
    
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: qrc request");
    
    //init
    info[@"name"] = [[NSHost currentHost] localizedName];
    info[@"uuid"] = [[[NSUUID UUID] UUIDString] lowercaseString];
    info[@"key"] = @"dGhpcyBpcyBhIHRlc3Q=";
    info[@"size"] = @20;
    
    //TODO: call into framework
    
    //convert to string
    qrcInfo = info.description;
    
    //return qrc info
    reply(qrcInfo);
    
    return;
}

//wait for phone to complete registration
// calls into framework that comms w/ server to wait for phone
-(void)recvRegistrationACK:(void (^)(NSDictionary* registrationInfo))reply;
{
    //registration info
    NSDictionary* registrationInfo = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: recv registration ACK");
    
    //TODO: call into framework
    registrationInfo = @{KEY_PHONE_NUMBER : @"+1 123-456-789"};
    
    //return registration framework
    reply(registrationInfo);
    
    return;
}

//update preferences
-(void)updatePreferences:(NSDictionary *)preferences
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: UPDATE PREFERENCES (%@)", preferences]);
    
    //save to disk
    [preferences writeToFile:PREFS_FILE atomically:YES];
    
    //log
    logMsg(LOG_TO_FILE, [NSString stringWithFormat:@"saving (updated) preferences: %@", preferences]);
    
bail:
    
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

@end
