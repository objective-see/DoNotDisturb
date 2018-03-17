//
//  file: main.m
//  project: DND (login item)
//  description: main; 'nuff said
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;
@import Sentry;

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"

//main
// only allow one instance, but then just invoke app's main
int main(int argc, const char * argv[])
{
    //return var
    int iReturn = -1;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"STARTED: DND login item (args: %@)", [[NSProcessInfo processInfo] arguments]]);
    
    //init crash reporting client
    SentryClient.sharedClient = [[SentryClient alloc] initWithDsn:CRASH_REPORTING_URL didFailWithError:nil];

    //start crash handler
    [SentryClient.sharedClient startCrashHandlerWithError:nil];
    
    //already running?
    if(YES == isAppRunning([[NSBundle mainBundle] bundleIdentifier]))
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"an instance of DND login item is already running, will exit");
        
        //no error per se
        iReturn = 0;
        
        //bail
        goto bail;
    }
    
    //launch app normally
    iReturn = NSApplicationMain(argc, argv);
    
bail:
    
    return iReturn;
}
