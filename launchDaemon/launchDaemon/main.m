//
//  file: main.m
//  project: DnD (launch daemon)
//  description: main interface/entry point for launch daemon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Lid.h"
#import "main.h"
#import "Consts.h"
#import "Queue.h"
#import "Logging.h"
#import "Exception.h"
#import "Utilities.h"
#import "Preferences.h"
#import "UserAuthMonitor.h"
#import "UserCommsListener.h"

//3rd-party
#import <dnd/dnd-swift.h>

//GLOBALS

//prefs obj
Preferences* preferences = nil;

//lid object
// registers for notifications, gets state, etc
Lid* lid = nil;

//queue object
// contains watch items that should be processed
Queue* eventQueue = nil;

//user auth event listener
UserAuthMonitor* userAuthMonitor = nil;

//dnd identity (from framework)
DNDIdentity *identity = nil;

//main
// init & kickoff stuffz
int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        //user comms listener (XPC) obj
        UserCommsListener* userCommsListener = nil;
        
        //dbg msg
        logMsg(LOG_DEBUG, @"DnD launch daemon started");
        
        //first thing...
        // install exception handlers
        installExceptionHandlers();
        
        //init logging
        if(YES != initLogging())
        {
            //err msg
            logMsg(LOG_ERR, @"failed to init logging");

            //bail
            goto bail;
        }
        
        //log to file
        logMsg(LOG_TO_FILE, @"launch daemon started");
        
        //alloc/init/load prefs
        preferences = [[Preferences alloc] init];
        if(nil == preferences)
        {
            //err msg
            logMsg(LOG_ERR, @"failed to initialize preferences");
            
            //bail
            goto bail;
        }
        	
        //register for shutdown
        // allows to close logging, etc.
        register4Shutdown();
        
        //generate DnD identity
        if(YES != initIdentity())
        {
            //err msg
            logMsg(LOG_ERR, @"failed to generate DnD identity");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"initialized DnD identity");
        
        //init global lid object
        lid = [[Lid alloc] init];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"lid state: %@", ([lid getState]) ? @"closed" : @"open"]);
        
        //register for lid notifications
        [lid register4Notifications];
        
        //dbg msg
        logMsg(LOG_DEBUG, @"registered for lid change notifications");
        
        //init global queue
        eventQueue = [[Queue alloc] init];

        //dbg msg
        logMsg(LOG_DEBUG, @"initialized global queue");
        
        //alloc/init user comms XPC obj
        userCommsListener = [[UserCommsListener alloc] init];
        if(nil == userCommsListener)
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to initialize user comms XPC listener"]);
            
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"listening for client XPC connections");
        
        //run loop
        [[NSRunLoop currentRunLoop] run];
    }
    
bail:
    
    //dbg msg
    // should never happen unless box is shutting down
    logMsg(LOG_DEBUG, @"launch daemon exiting");
    
    return 0;
}

//initialize an identity for DnD comms
// generates client id, etc. and then creates identity
BOOL initIdentity()
{
    //flag
    BOOL initialized = NO;
    
    //path to digita CA
    NSString* digitaCAPath = nil;
    
    //path to csr
    NSString* csrPath = nil;
    
    //path to aws CA
    NSString* awsCAPath = nil;
    
    //client ID
    NSString* clientID = nil;
    
    //error
    NSError *error = nil;
    
    //csr identity
    DNDIdentity *csrIdentity = nil;
    
    //csr client
    DNDClientCsr *csrClient = nil;
    
    //init digita CA path
    digitaCAPath = [[NSBundle mainBundle] pathForResource:@"rootCA" ofType:@"pem"];
    if(nil == digitaCAPath)
    {
        //bail
        goto bail;
    }
    
    //init csr path
    csrPath = [[NSBundle mainBundle] pathForResource:@"deviceCSRRequest" ofType:@"p12"];
    if(nil == digitaCAPath)
    {
        //bail
        goto bail;
    }
    
    //init AWS CA path
    awsCAPath = [[NSBundle mainBundle] pathForResource:@"awsRootCA" ofType:@"pem"];
    if(nil == awsCAPath)
    {
        //bail
        goto bail;
    }
    
    //try load client id
    clientID = preferences.preferences[PREF_CLIENT_ID];
    if(nil == clientID)
    {
        //generate
        clientID = [[[NSUUID UUID] UUIDString] lowercaseString];
        
        //save
        [preferences update:@{PREF_CLIENT_ID:clientID}];
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"client id: %@", clientID]);
    
    //TODO: pass phrase
    //alloc init csr identity
    csrIdentity = [[DNDIdentity alloc] init:clientID p12Path:csrPath passphrase:@"csr" caPath:awsCAPath error:&error];
    if( (nil == csrIdentity) ||
        (nil != error) )
    {
        //err msg
        logMsg(LOG_ERR, @"fail to get/create CSR identity");
        
        //bail
        goto bail;
    }
    
    //alloc/init csr client
    csrClient = [[DNDClientCsr alloc] initWithDndIdentity:csrIdentity sendCA:false background:true];
    if(nil == csrClient)
    {
        //err msg
        logMsg(LOG_ERR, @"fail to get/create CSR client");
        
        //bail
        goto bail;
    }
    
    //get (or create) dnd identity
    identity = [csrClient getOrCreateIdentity:clientID caPath:digitaCAPath];
    if(nil == identity)
    {
        //err msg
        logMsg(LOG_ERR, @"fail to get/create DND identity");
        
        //bail
        goto bail;
    }

    //happy
    initialized = YES;
    
bail:
    
    return initialized;
}

//init a handler for SIGTERM
// can perform actions such as disabling firewall and closing logging
void register4Shutdown()
{
    //TODO: needs to be global
    //dispatch source for SIGTERM
    dispatch_source_t dispatchSource = nil;
    
    //ignore sigterm
    // handling it via GCD dispatch
    signal(SIGTERM, SIG_IGN);
    
    //init dispatch source for SIGTERM
    dispatchSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, dispatch_get_main_queue());
    
    //set handler
    // disable kext & close logging
    dispatch_source_set_event_handler(dispatchSource, ^{
        
        //close logging
        deinitLogging();
        
        //bye!
        exit(SIGTERM);
    });
    
    //resume
    dispatch_resume(dispatchSource);
    
    return;
}
