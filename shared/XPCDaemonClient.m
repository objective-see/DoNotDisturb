//
//  file: XPCDaemonClient.m
//  project: DND (shared)
//  description: talk to the daemon, via XPC (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "XPCUserProto.h"
#import "XPCDaemonClient.h"

#ifdef XPC_USER
#import "XPCUser.h"
#endif

@implementation XPCDaemonClient

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
        self.xpcServiceConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCDaemonProtocol)];
    
        #ifdef XPC_USER
        
        //set exported object interface (protocol)
        self.xpcServiceConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCUserProtocol)];
        
        //set exported object
        // this will allow daemon to invoke user methods!
        self.xpcServiceConnection.exportedObject = [[XPCUser alloc] init];
        
        #endif
        
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
    logMsg(LOG_DEBUG, @"sending request, via XPC, for recv registration ack/info");
    
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
// note: synchronous
-(NSDictionary*)getPreferences:(NSString*)preference
{
    //preferences
    __block NSDictionary* preferences = nil;
    
    //wait sema
    dispatch_semaphore_t semaphore = NULL;
    
    //init sema
    semaphore = dispatch_semaphore_create(0);
    
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, for preferences");

    //request preferences
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'getPreferences' method on launch daemon (error: %@)", proxyError]);
        
        //signal sema
        dispatch_semaphore_signal(semaphore);
          
    }] getPreferences:preference reply:^(NSDictionary* preferencesFromDaemon)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got preferences: %@", preferencesFromDaemon]);
        
        //save
        preferences = preferencesFromDaemon;
        
        //signal sema
        dispatch_semaphore_signal(semaphore);
        
    }];
    
    //XPC is async
    // wait for preferences from daemon
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    return preferences;
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

@end
