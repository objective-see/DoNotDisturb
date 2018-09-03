//
//  file: XPCDaemon.m
//  project: DND (launch daemon)
//  description: interface for user XPC methods
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "XPCDaemon.h"
#import "Preferences.h"
#import "FrameworkInterface.h"

#import <dnd/dnd-swift.h>

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//global prefs obj
extern Preferences* preferences;

//framework interface obc
extern FrameworkInterface* framework;

@implementation XPCDaemon

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
        
    }
    
    return self;
}

//XPC method
// returns preferences to client
-(void)getPreferences:(NSString*)preference reply:(void (^)(NSDictionary* preferences))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"XPC request: get preferences (pref: %@)", preference]);
    
    //get current prefs
    reply([preferences get:preference]);
    
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
    
    //need DND identity obj?
    if(nil == framework.identity)
    {
        //create it
        if(YES != [framework initIdentity:YES])
        {
            //err msg
            logMsg(LOG_ERR, @"failed to initialize DND identity");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"created DND identity");
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
    client = [[DNDClientMac alloc] initWithDndIdentity:framework.identity sendCA:YES background:YES taskable:YES];
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
    
    //unset
    client = nil;
    
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



//process alert dismiss request from client
// blocks until framework tell us it was dismissed via the phone || login item said 'disable'
-(void)alertDismiss:(void (^)(NSDictionary* alert))reply
{
    //alert details
    // for now, nil...
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
    // signal wait semaphore when notification is triggered
    dismissObserver = [[NSNotificationCenter defaultCenter] addObserverForName:DISMISS_NOTIFICATION object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"'DISMISS_NOTIFICATION' notification triggered");
        
        //signal that a response came in
        dispatch_semaphore_signal(semaphore);
    }];
    
    //XPC is async
    // wait for preferences from daemon
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    //log to file
    logMsg(LOG_DEBUG|LOG_TO_FILE, @"sending 'alert dismiss' to login item");
    
    //return alert
    reply(alert);
    
    return;
}

@end
