//
//  file: main.m
//  project: donotdisturb (main app)
//  description: main interface, toggle login item, or just kick off app interface
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;
#import <ServiceManagement/ServiceManagement.h>

#import "Consts.h"
#import "Logging.h"
#import "Exception.h"
#import "Utilities.h"

int main(int argc, const char * argv[])
{
    //return var
    int iReturn = -1;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"starting config/pref's app (args: %@)", [[NSProcessInfo processInfo] arguments]]);
    
    //first thing...
    // install exception handlers
    installExceptionHandlers();
    
    //install
    // enable login item
    if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:CMDLINE_FLAG_INSTALL])
    {
        //toggle login item
        if(YES != SMLoginItemSetEnabled((__bridge CFStringRef)HELPER_BUNDLE_ID, YES))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to enable login item (%@)", [[NSBundle mainBundle] bundleIdentifier]]);
            
            //bail
            goto bail;
        }
    }
    
    //uninstall
    // disable login item and bail
    else if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:CMDLINE_FLAG_UNINSTALL])
    {
        //toggle login item
        if(YES != SMLoginItemSetEnabled((__bridge CFStringRef)HELPER_BUNDLE_ID, NO))
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to disable login item (%@)", [[NSBundle mainBundle] bundleIdentifier]]);
            
            //bail
            goto bail;
        }
        
        //don't want to show UI or do anything else, so bail
        goto bail;
    }
    
    //already running?
    if(YES == isAppRunning([[NSBundle mainBundle] bundleIdentifier]))
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"an instance of DnD (main app) is already running");
        
        //bail
        goto bail;
    }
    
    //launch app normally
    iReturn = NSApplicationMain(argc, argv);
    
bail:
    
    return iReturn;
}
