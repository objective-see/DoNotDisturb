//
//  file: UserCommsListener.m
//  project: DND (launch daemon)
//  description: XPC listener for connections for user components
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"

#import "Queue.h"
#import "UserComms.h"
#import "UserCommsListener.h"
#import "UserCommsInterface.h"

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//global queue object
extern Queue* eventQueue;

//interface for 'extension' to NSXPCConnection
// allows us to access the 'private' auditToken iVar
@interface ExtendedNSXPCConnection : NSXPCConnection
{
    //private iVar
    audit_token_t auditToken;
}
//private iVar
@property audit_token_t auditToken;

@end

//implementation for 'extension' to NSXPCConnection
// allows us to access the 'private' auditToken iVar
@implementation ExtendedNSXPCConnection

//private iVar
@synthesize auditToken;

@end

OSStatus SecTaskValidateForRequirement(SecTaskRef task, CFStringRef requirement);


//global queue object
extern Queue* eventQueue;

@implementation UserCommsListener


@synthesize listener;

//init
// create XPC listener
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //setup XPC listener
        if(YES != [self initListener])
        {
            //unset
            self =  nil;
            
            //bail
            goto bail;
            
        }
    }
    
bail:
    
    return self;
}

//setup XPC listener
-(BOOL)initListener
{
    //result
    BOOL result = NO;
    
    //init listener
    listener = [[NSXPCListener alloc] initWithMachServiceName:DAEMON_MACH_SERVICE];
    if(nil == self.listener)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to create mach service %@", DAEMON_MACH_SERVICE]);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"created mach service %@", DAEMON_MACH_SERVICE]);
    
    //set delegate
    self.listener.delegate = self;
    
    //ready to accept connections
    [self.listener resume];
    
    //happy
    result = YES;
    
bail:
    
    return result;
}


#pragma mark -
#pragma mark NSXPCConnection method overrides

//automatically invoked
// allows NSXPCListener to configure/accept/resume a new incoming NSXPCConnection
// note: we only allow binaries signed by Objective-See to talk to this!
-(BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    //flag
    BOOL shouldAccept = NO;
    
    //task ref
    SecTaskRef taskRef = 0;
    
    //signing req string
    NSString *requirementString = nil;
    
    //make weak ref
    // see: https://stackoverflow.com/a/23628986/3854841
    __weak typeof(NSXPCConnection*) weakConnection = newConnection;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"received request to connect to XPC interface");
    
    //set interrupt & invalidation handler
    newConnection.interruptionHandler = newConnection.invalidationHandler = ^{
        
        //make strong ref
        // see: https://stackoverflow.com/a/23628986/3854841
        __strong typeof(NSXPCConnection*)strongConnection = weakConnection;
        
        //dbg msg
        logMsg(LOG_DEBUG, @"connection interrupted/invalidated");
        
        //handle invalidation
        [self connectionInvalidated:strongConnection];
    };
    
    //init signing req string
    requirementString = [NSString stringWithFormat:@"anchor trusted and certificate leaf [subject.CN] = \"%@\"", SIGNING_AUTH];
    
    //step 1: create task ref
    // uses NSXPCConnection's (private) 'auditToken' iVar
    taskRef = SecTaskCreateWithAuditToken(NULL, ((ExtendedNSXPCConnection*)newConnection).auditToken);
    if(NULL == taskRef)
    {
        //bail
        goto bail;
    }
    
    //step 2: validate
    // check that client is signed with Objective-See's dev cert
    if(0 != SecTaskValidateForRequirement(taskRef, (__bridge CFStringRef)(requirementString)))
    {
        //bail
        goto bail;
    }

    //set the interface that the exported object implements
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(UserProtocol)];
    
    //set object exported by connection
    newConnection.exportedObject = [[UserComms alloc] init];

    //resume
    [newConnection resume];
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"allowed XPC connection: %@", newConnection.exportedObject]);
    
    //happy
    shouldAccept = YES;
    
bail:
    
    //release task ref object
    if(NULL != taskRef)
    {
        //release
        CFRelease(taskRef);
        
        //unset
        taskRef = NULL;
    }
    
    return shouldAccept;
}

//connection invalidated
// if there is an 'undelivered' alert, (re)enqueue it
-(void)connectionInvalidated:(NSXPCConnection *)connection
{
    //user comms obj
    UserComms* userComms = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC connection interrupted/invalidated");

    //sanity check
    if(nil == connection)
    {
        //bail
        goto bail;
    }
    
    //grab user comms object
    userComms = connection.exportedObject;
    
    //no undelivered (dequeued) alert?
    if(nil == userComms.dequeuedAlert)
    {
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"found undelivered alert, will (re)enqueue"]);
    
    //have alert
    // requeue it up
    [eventQueue enqueue:userComms.dequeuedAlert];

bail:
    
    //unset export obj
    connection.exportedObject = nil;
    
    //unset connection
    connection = nil;
    
    return;
}


@end
