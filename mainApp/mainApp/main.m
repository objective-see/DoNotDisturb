//
//  file: main.m
//  project: Do Not Disturb (main app)
//  description: main interface, toggle login item, or just kick off app interface
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;
@import Sentry;

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"

#import <ServiceManagement/ServiceManagement.h>

int main(int argc, const char * argv[])
{
    //return var
    int iReturn = -1;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"STARTED: config/prefs app (args: %@)", [[NSProcessInfo processInfo] arguments]]);
    
    //init crash reporting client
    SentryClient.sharedClient = [[SentryClient alloc] initWithDsn:CRASH_REPORTING_URL didFailWithError:nil];
    
    //start crash handler
    [SentryClient.sharedClient startCrashHandlerWithError:nil];
    
    //already running?
    if(YES == isAppRunning([[NSBundle mainBundle] bundleIdentifier]))
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"an instance of DND (main app) is already running");
        
        //bail
        goto bail;
    }
    
    //launch app normally
    iReturn = NSApplicationMain(argc, argv);
    
bail:
    
    return iReturn;
}
