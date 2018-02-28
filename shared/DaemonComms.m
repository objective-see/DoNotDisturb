//
//  file: DaemonComms.m
//  project: DnD (shared)
//  description: talk to daemon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "DaemonComms.h"

@implementation DaemonComms

@synthesize daemon;
@synthesize xpcServiceConnection;

//init
// create XPC connection & set remote obj interface
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc/init
        xpcServiceConnection = [[NSXPCConnection alloc] initWithMachServiceName:DAEMON_MACH_SERVICE options:0];
        
        //set remote object interface
        self.xpcServiceConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(UserProtocol)];
        
        //resume
        [self.xpcServiceConnection resume];
    }
    
    return self;
}

//ask daemon for QRC info
// name, uuid, key, key size, etc...
-(void)qrcRequest:(void (^)(NSData* qrcInfo))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, for qrc info");
    
    //request qrc info
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
      {
          //err msg
          logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'qrcRequest' method on launch daemon (error: %@)", proxyError]);
          
      }] qrcRequest:^(NSData* qrcInfo)
     {
         //respond with info
         reply(qrcInfo);
     }];
    
    return;
}

//wait for phone to complete registration
// calls into framework that comms w/ server to wait for phone
-(void)recvRegistrationACK:(void (^)(NSDictionary* registrationInfo))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, for recv registration info");
    
    //recv registration info
    // note: this will block until phone pings server
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
          //err msg
          logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'recvRegistrationACK' method on launch daemon (error: %@)", proxyError]);
          
    }] recvRegistrationACK:^(NSDictionary* registrationInfo)
    {
         //respond with alert
         reply(registrationInfo);
    }];
    
    return;
    
}

//get preferences
-(void)getPreferences:(void (^)(NSDictionary* preferences))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, for preferences");
    
    //request preferences
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
      {
          //err msg
          logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'getPreferences' method on launch daemon (error: %@)", proxyError]);
          
      }] getPreferences:^(NSDictionary* preferences)
     {
         //respond
         reply(preferences);
     }];
    
}


//update (save) preferences
-(void)updatePreferences:(NSDictionary*)preferences
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, to update preferences");
    
    //update prefs
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
          //err msg
          logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'updatePreferences' method on launch daemon (error: %@)", proxyError]);
          
    }] updatePreferences:preferences];
    
    return;
}

//ask (and then block) for an alert
-(void)alertRequest:(void (^)(NSDictionary* alert))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, for alert");
    
    //request alert
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'alertRequest' method on launch daemon (error: %@)", proxyError]);
        
    }] alertRequest:^(NSDictionary* alert)
    {
        //respond with alert
        reply(alert);
    }];
    
    return;
}

//send alert response back to the daemon
// for now, it's just an 'ack' that it was recieved/shown
-(void)alertResponse
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, for alert response");
    
    //respond to alert
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
          //err msg
          logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'alertResponse' method on launch daemon (error: %@)", proxyError]);
          
    }] alertResponse];
    
    return;
}

//ask (and then block) for an alert dismiss
-(void)alertDismiss:(void (^)(NSDictionary* alert))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, for alert dismiss events");

    //request alert
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
          //err msg
          logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'alertDismiss' method on launch daemon (error: %@)", proxyError]);
          
    }] alertDismiss:^(NSDictionary* alert)
    {
         //respond with alert
         reply(alert);
    }];
    
    return;
}

//close/cleanup connection
-(void)close
{
    //invalidate
    [self.xpcServiceConnection invalidate];
    
    //unset
    self.xpcServiceConnection = nil;
    
    return;
}

@end
