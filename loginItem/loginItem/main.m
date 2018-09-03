//
//  file: main.m
//  project: DND (login item)
//  description: main interface to login item
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
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
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"STARTED: login item (args: %@)", [[NSProcessInfo processInfo] arguments]]);
    
    //init crash reporting
    initCrashReporting();
    
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
