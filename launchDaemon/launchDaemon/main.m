//
//  file: main.m
//  project: DnD (launch daemon)
//  description: main interface/entry point for launch daemon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Lid.h"
#import "Consts.h"
#import "Queue.h"
#import "Logging.h"
#import "Utilities.h"
#import "UserAuthMonitor.h"
#import "UserCommsListener.h"

//GLOBALS

//lid object
// registers for notifications, gets state, etc
Lid* lid = nil;

//queue object
// ->contains watch items that should be processed
Queue* eventQueue = nil;

//user auth event listener
UserAuthMonitor* userAuthMonitor = nil;

//'rule changed' semaphore
dispatch_semaphore_t rulesChanged = 0;

/* FUNCTIONS */

//init a handler for SIGTERM
// can perform actions such as disabling firewall and closing logging
void register4Shutdown(void);

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
        	
        //register for shutdown
        // allows to close logging, etc.
        register4Shutdown();
        
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

//init a handler for SIGTERM
// can perform actions such as disabling firewall and closing logging
void register4Shutdown()
{
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
