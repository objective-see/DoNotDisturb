//
//  file: StatusBarMenu.m
//  project: DnD (login item)
//  description: menu handler for status bar icon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "UserCommsInterface.h"
#import "StatusBarMenu.h"

//menu items
enum menuItems
{
    status = 100,
    toggleStatus,
    viewLog,
    showPrefs,
    end
};

@implementation StatusBarMenu

@synthesize isEnabled;
@synthesize statusItem;
@synthesize daemonComms;

//init method
// set some intial flags, init daemon comms, etc.
-(id)init:(NSMenu*)menu;
{
    //prefs
    NSDictionary* preferences = nil;
    
    //load from nib
    self = [super init];
    if(self != nil)
    {
        //init daemon comms
        daemonComms = [[DaemonComms alloc] init];
        
        //init status item
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        
        //set image
        self.statusItem.image = [NSImage imageNamed:@"statusIcon"];
        
        //tell OS to handle image
        self.statusItem.image.template = YES;
    
        //set menu
        self.statusItem.menu = menu;
        
        //set action handler for all items
        for(int i=toggleStatus; i<end; i++)
        {
            //set action
            [self.statusItem.menu itemWithTag:i].action = @selector(handler:);
            
            //set state
            [self.statusItem.menu itemWithTag:i].enabled = YES;
            
            //set target
            [self.statusItem.menu itemWithTag:i].target = self;
        }
        
        //load prefs
        preferences = [NSMutableDictionary dictionaryWithContentsOfFile:PREFS_FILE];
        
        //no prefs?
        // default to status: enabled
        if(nil == preferences)
        {
            //enable
            self.isEnabled = YES;
        }
        
        //got prefs
        // set status
        else
        {
            //set status
            self.isEnabled = [preferences[PREF_STATUS] boolValue];
        }
        
        //set initial menu state
        [self setState];
    }
    
    return self;
}

//menu handler
-(void)handler:(id)sender
{
    //path components
    NSArray *pathComponents = nil;
    
    //path to config (main) app
    NSString* mainApp = nil;
    
    //error
    NSError* error = nil;
    
    //dbg msg
    #ifndef NDEBUG
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"user clicked %ld", (long)((NSMenuItem*)sender).tag]);
    #endif
    
    //get path components
    pathComponents = [[[NSBundle mainBundle] bundlePath] pathComponents];
    if(pathComponents.count > 4)
    {
        //init path to full (main) app
        mainApp = [NSString pathWithComponents:[pathComponents subarrayWithRange:NSMakeRange(0, pathComponents.count - 4)]];
    }
    //handle action
    switch ((long)((NSMenuItem*)sender).tag)
    {
        //toggle on/off
        case toggleStatus:
        {
            //invert since toggling
            self.isEnabled = !self.isEnabled;
            
            //set menu state
            [self setState];
            
            break;
        }
        
        //log
        // show it!
        case viewLog:
        {
            //show
            [self showLog];
            
            break;
        }

        //launch main app
        // will show preferences
        case showPrefs:
        {
            //launch main app
            if(nil == [[NSWorkspace sharedWorkspace] launchApplicationAtURL:[NSURL fileURLWithPath:mainApp] options:0 configuration:@{} error:&error])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to launch %@ (%@)", mainApp, error]);
                
                //bail
                goto bail;
            }
            
            break;
        }
            
        default:
            break;
    }
    
bail:
    
    return;
}

//check if log file is present
// and then open its (via 'open') so Console.app pops
-(void)showLog
{
    //log file
    NSString* logFile = nil;
 
    //alert
    NSAlert *alert = nil;
    
    //init path
    logFile = logFilePath();
    
    //check if it exists
    if(YES != [[NSFileManager defaultManager] fileExistsAtPath:logFile])
    {
        //init alert
        alert = [[NSAlert alloc] init];
        
        //set main text
        alert.messageText = @"Log File Not Found";
        
        //set informative text
        alert.informativeText = [NSString stringWithFormat:@"path: %@", logFile];

        //add button
        [alert addButtonWithTitle:@"Ok"];
        
        //set style
        alert.alertStyle = NSWarningAlertStyle;
        
        //show it
        [alert runModal];
        
        //bail
        goto bail;

    }
    
    //open log
    execTask(OPEN, @[logFile], NO);
    
bail:
    
    return;
}

//set menu status
// logic based on 'isEnabled' iVar
-(void)setState
{
    //preferences
    NSMutableDictionary* preferences = nil;
    
    //load preferences from disk
    preferences = [NSMutableDictionary dictionaryWithContentsOfFile:PREFS_FILE];
    if(nil == preferences)
    {
        //default to blank
        preferences = [NSMutableDictionary dictionary];
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"setting state to: %@", (self.isEnabled) ? @"enabled" : @"disabled"]);
    
    //set to enabled
    if(YES == self.isEnabled)
    {
        //update status
        [self.statusItem.menu itemWithTag:status].title = @"DnD: enabled";
        
        //change text
        [self.statusItem.menu itemWithTag:toggleStatus].title = @"Disable";
    }
    
    //set to disabled
    else
    {
        //update status
        [self.statusItem.menu itemWithTag:status].title = @"DnD: disabled";
        
        //change text
        [self.statusItem.menu itemWithTag:toggleStatus].title = @"Enable";
    }
    
    //set preference
    preferences[PREF_STATUS] = [NSNumber numberWithBool:self.isEnabled];

    //send to daemon
    // will update preferences
    [self.daemonComms updatePreferences:preferences];
    
    return;
}

@end
