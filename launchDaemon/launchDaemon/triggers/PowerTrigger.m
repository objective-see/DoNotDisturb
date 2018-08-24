//  file: Power.m
//  project: DND (launch daemon)
//  description: monitor and alert logic for power events (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Triggers.h"
#import "Utilities.h"
#import "Preferences.h"
#import "PowerTrigger.h"

/* GLOBALS */

//triggers object
extern Triggers* triggers;

//preferences obj
extern Preferences* preferences;

@implementation PowerTrigger

@synthesize screenSaverNotification;


//toggle lid notifications
-(BOOL)toggle:(NSControlStateValue)state
{
    //flag
    BOOL wasToggled = NO;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"toggling power notifications: %lu", state]);
    
    //on?
    // enable
    if(NSOnState == state)
    {
        //enable
        wasToggled = [self enable];
    }
    //off
    // disable
    else
    {
        //disable
        [self disable];
        
        //manually set flag
        wasToggled = YES;
    }
    
    return wasToggled;
}

//start power event monitoring
-(BOOL)enable
{
    //status
    BOOL initialized = NO;
    
    /*
     com.apple.screensaver.didstart
     com.apple.screensaver.willstop
     com.apple.screensaver.didstop
     
    */
    
    //add observer for screen save on
    // we don't get a screen save stop, so this will trigger process monitoring for exit of ScreenSaverEngine
    self.screenSaverNotification = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"com.apple.screensaver.didlaunch" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification)
    {
        //TODO: trigger process monitoring
        
        //dbg msg
        // log to file
        //logMsg(LOG_DEBUG|LOG_TO_FILE, @"[NEW EVENT] screen saver did stop");
        
        //process event
        // report to user, server, execute actions, etc.
        //[triggers processEvent:POWER_TRIGGER info:@{KEY_POWER_TYPE:@"screen saver did stop"}];
        
    }];
    
    //dbg msg
    logMsg(LOG_DEBUG, @"enabled screen saver 'did launch'");

    
bail:
    
    return initialized;
}



//disable
-(void)disable
{
    //disable
    // screen saver start notification
    if(nil != self.screenSaverNotification)
    {
        //remove
        [[NSNotificationCenter defaultCenter] removeObserver:self.screenSaverNotification];
        
        //unset
        self.screenSaverNotification = nil;
    }
    
    //TODO: make sure to stop process monitoring, if it's still going
    
    return;
}

@end
