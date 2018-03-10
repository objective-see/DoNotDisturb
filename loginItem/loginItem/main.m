//
//  file: main.m
//  project: DnD (login item)
//  description: main; 'nuff said
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

#import "Logging.h"
#import "Exception.h"
#import "Utilities.h"

//main
// only allow one instance, but then just invoke app's main
int main(int argc, const char * argv[])
{
    //return var
    int iReturn = -1;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"STARTED: DnD helper/login item (args: %@)", [[NSProcessInfo processInfo] arguments]]);
    
    //first thing...
    // install exception handlers
    installExceptionHandlers();
    
    //already running?
    if(YES == isAppRunning([[NSBundle mainBundle] bundleIdentifier]))
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"an instance of DnD (helper app) is already running, will exit");
        
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
