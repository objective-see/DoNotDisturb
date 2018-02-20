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
    // framework will generate this
    NSMutableDictionary* info = [NSMutableDictionary dictionary];
    
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: qrc request");
    
    //TODO: remove
    // framework will generate this
    info[@"name"] = [[NSHost currentHost] localizedName];
    info[@"uuid"] = [[[NSUUID UUID] UUIDString] lowercaseString];
    info[@"key"] = @"dGhpcyBpcyBhIHRlc3Q=";
    info[@"size"] = @20;
    
    //TODO: call into framework
    // expect it to return us a dictionary that contains 'name', 'uuid', 'key', and 'size'
    // ...or it can generate a string, we really don't care as we're just going to display it in a QRC
    
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
    // expect a callback that contains info about the linked device (name? number?)
    
    //TODO:
    // remove as framework will return this/something similar
    registrationInfo = @{KEY_PHONE_NUMBER : @"+1 123-456-7890"};
    
    //return registration framework
    reply(registrationInfo);
    
    return;
}

//update preferences
-(void)updatePreferences:(NSDictionary *)preferences
{
    //existing preferences
    NSMutableDictionary* existingPreferences = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: UPDATE PREFERENCES (%@)", preferences]);
    
    //load current preferences
    existingPreferences = [NSMutableDictionary dictionaryWithContentsOfFile:PREFS_FILE];
    
    //merge in new prefs and save
    if(nil != existingPreferences)
    {
        //update
        // merge in
        [existingPreferences addEntriesFromDictionary:preferences];
        
        //save
        [existingPreferences writeToFile:PREFS_FILE atomically:YES];
    }
    //no existing ones
    // just saved passed in ones
    else
    {
        //save
        [preferences writeToFile:PREFS_FILE atomically:YES];
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
    NSMutableDictionary* alert = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request: alert dismiss");
    
    //TODO: call into framework to block
    // expect a response when the user on the phone has dismissed
    // can just be a BOOL (was dimissed) as currently we just dismiss any on-screen alerts...
    [NSThread sleepForTimeInterval:100000];
    
    //log to file
    logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"sending alert dismiss to login item to display to user: %@", alert]);
    
    //return alert
    reply(alert);
    
    return;
}

@end
