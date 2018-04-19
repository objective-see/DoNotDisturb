//
//  file: main.m
//  project: DND (launch daemon)
//  description: main interface/entry point for launch daemon
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Lid.h"
#import "main.h"
#import "Consts.h"
#import "Queue.h"
#import "Logging.h"
#import "Utilities.h"
#import "Preferences.h"
#import "UserAuthMonitor.h"
#import "UserCommsListener.h"
#import "FrameworkInterface.h"

@import Sentry;

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

//DND framework interface
FrameworkInterface* framework = nil;

//dispatch source for SIGTERM
dispatch_source_t dispatchSource = nil;

//main
// init & kickoff stuffz
int main(int argc, const char * argv[])
{
    //return
    int result = -1;
    
    @autoreleasepool
    {
        //user comms listener (XPC) obj
        UserCommsListener* userCommsListener = nil;
        
        //current preferences
        NSDictionary* currentPrefs = nil;
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"DND launch daemon started (args: %@)", [[NSProcessInfo processInfo] arguments]]);
        
        //init crash reporting client
        SentryClient.sharedClient = [[SentryClient alloc] initWithDsn:CRASH_REPORTING_URL didFailWithError:nil];
        
        //start crash handler
        [SentryClient.sharedClient startCrashHandlerWithError:nil];
        
        //alloc/init/load prefs
        // to here (early) as other logic (below) uses prefs
        preferences = [[Preferences alloc] init];
        if(nil == preferences)
        {
            //err msg
            logMsg(LOG_ERR, @"failed to initialize preferences");
            
            //bail
            goto bail;
        }
        
        //get all current prefs
        currentPrefs = [preferences get:nil];
        
        //init framework obj
        framework = [[FrameworkInterface alloc] init];
        
        //uninstall?
        // delete DND identity and exit
        // note: only called (via script) during full uninstall
        if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:CMDLINE_FLAG_UNINSTALL])
        {
            //uninstall
            if(YES != uninstall())
            {
                //err msg
                logMsg(LOG_DEBUG, @"failed to perform daemon's 'uninstall' logic");
                
                //bail
                goto bail;
            }
            
            //happy
            result = 0;
            
            //bail
            goto bail;
        }
        
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
        
        //1st time identity generatation is done on demand
        // subsequent times though, can just always do here
        if(nil != currentPrefs[PREF_CLIENT_ID])
        {
            //load identity
            if(YES != [framework initIdentity:YES])
            {
                //err msg
                logMsg(LOG_ERR, @"failed to generate DND identity");
                
                //bail
                goto bail;
            }
            
            //dbg msg
            logMsg(LOG_DEBUG, @"initialized DND identity");
        }
    
        //init global lid object
        lid = [[Lid alloc] init];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"lid state: %d", getLidState()]);
        
        //not (prev) disabled?
        // register for lid notifications
        if(YES != [currentPrefs[PREF_IS_DISABLED] boolValue])
        {
            //register for lid notifications
            [lid register4Notifications];
            
            //dbg msg
            logMsg(LOG_DEBUG, @"registered for lid change notifications");
        }
        
        //(prev) disabled
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"currently disabled, so did not register for lid change notifications");
        }
    
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
    
    }//pool
    
    //happy
    result = 0;
    
bail:
    
    //dbg msg
    // should never happen unless box is shutting down
    logMsg(LOG_DEBUG, @"launch daemon exiting");
    
    return result;
}

//uninstall
// delete DND identity
BOOL uninstall()
{
    //result
    BOOL uninstalled = NO;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"performing daemon 'uninstall' logic");
    
    //no client id?
    // no need to delete identity
    if(nil == [preferences get:nil][PREF_CLIENT_ID])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"no client ID found, so no identity to delete");
        
        //happy
        uninstalled = YES;
        
        //bail
        goto bail;
    }
    
    //load identity
    // but no need to do full init
    if(YES != [framework initIdentity:NO])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to init DND identity");
        
        //bail
        goto bail;
    }
    
    //delete id
    if(YES != [framework.identity deleteIdentityWithDeleteAssociatedCA:YES])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to delete DND identity");
        
        //bail
        goto bail;
    }
    
    //unset
    framework.identity = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"deleted identity");
    
    //happy
    uninstalled = YES;
    
bail:

    return uninstalled;
}

//init a handler for SIGTERM
// can perform actions such as closing logging
void register4Shutdown()
{
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
