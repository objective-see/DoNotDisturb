//
//  file: StatusBarMenu.m
//  project: DND (login item)
//  description: menu handler for status bar icon
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "StatusBarMenu.h"
#import "XPCDaemonClient.h"
#import "StatusBarPopoverController.h"

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

@synthesize isDisabled;
@synthesize statusItem;
@synthesize daemonComms;

//init method
// set some intial flags, init daemon comms, etc.
-(id)init:(NSMenu*)menu firstTime:(BOOL)firstTime
{
    //preferences
    NSDictionary* preferences = nil;
    
    //load from nib
    self = [super init];
    if(self != nil)
    {
        //init daemon comms
        daemonComms = [[XPCDaemonClient alloc] init];
        
        //init status item
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        
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
        
        //first time?
        // show popover
        if(YES == firstTime)
        {
            //show
            [self showPopover];
        }
        
        //set notification for when theme toggles
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(interfaceChanged:) name:@"AppleInterfaceThemeChangedNotification" object:nil];
        
        //get prefs via XPC
        preferences = [self.daemonComms getPreferences:nil];
         
        //set state based on (existing) preferences
        self.isDisabled = [preferences[PREF_IS_DISABLED] boolValue];
        
        //set initial menu state
        [self setState];
    }
    
    return self;
}

//set status bar icon
// takes into account dark mode
-(void)setIcon
{
    //dark mode
    BOOL darkMode = NO;
    
    //set dark mode
    // !nil if dark mode is enabled
    darkMode = (nil != [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"]);
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"setting icon (dark mode: %d)", darkMode]);
    
    //enabled
    if(YES != self.isDisabled)
    {
        //alternate is always white
        self.statusItem.alternateImage = [NSImage imageNamed:@"statusIconWhite"];
        
        //normal (non) dark mode
        if(YES != darkMode)
        {
            //set icon
            self.statusItem.image = [NSImage imageNamed:@"statusIcon"];
        }
        //dark mode
        else
        {
            //set icon
            self.statusItem.image = [NSImage imageNamed:@"statusIconWhite"];
        }
    }
    //disabled
    else
    {
        //alternate is always white
        self.statusItem.alternateImage = [NSImage imageNamed:@"statusIconDisabledWhite"];
        
        //normal (non) dark mode
        if(YES != darkMode)
        {
            //set icon
            self.statusItem.image = [NSImage imageNamed:@"statusIconDisabled"];
        }
        //dark mode
        else
        {
            //set icon
            self.statusItem.image = [NSImage imageNamed:@"statusIconDisabledWhite"];
        }
    }
    
    return;
}

//callback for when theme changes
// just invoke helper method to change icon
-(void)interfaceChanged:(NSNotification *)notification
{
    #pragma unused(notification)
    
    //set icon
    [self setIcon];
    
    return;
}

//show popver
-(void)showPopover
{
    //alloc popover
    self.popover = [[NSPopover alloc] init];
    
    //don't want highlight for popover
    self.statusItem.highlightMode = NO;
    
    //set action
    // can close popover with click
    self.statusItem.action = @selector(closePopover:);
    
    //set target
    self.statusItem.target = self;
    
    //set view controller
    self.popover.contentViewController = [[StatusBarPopoverController alloc] initWithNibName:@"StatusBarPopover" bundle:nil];
    
    //set behavior
    // auto-close if user clicks button in status bar
    self.popover.behavior = NSPopoverBehaviorTransient;
    
    //set delegate
    self.popover.delegate = self;
    
    //show popover
    // have to wait cuz...
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(),
    ^{
       //show
       [self.popover showRelativeToRect:self.statusItem.button.bounds ofView:self.statusItem.button preferredEdge:NSMinYEdge];
    });
    
    //wait a bit
    // then automatically hide popup if user has not closed it
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(),
    ^{
        //close
        [self closePopover:nil];
    });
    
    return;
}

//close popover
// also unsets action handler, resets, highlighting, etc
-(void)closePopover:(id)sender
{
    //still visible?
    // close it then...
    if(YES == self.popover.shown)
    {
        //close
        [self.popover performClose:nil];
    }
    
    //remove action handler
    self.statusItem.action = nil;
    
    //reset highlight mode
    self.statusItem.highlightMode = YES;
    
    return;
}

//menu handler
-(void)handler:(id)sender
{
    //path to config (main) app
    NSString* mainApp = nil;
    
    //error
    NSError* error = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"user clicked %ld", (long)((NSMenuItem*)sender).tag]);
    
    //handle action
    switch ((long)((NSMenuItem*)sender).tag)
    {
        //toggle on/off
        case toggleStatus:
        {
            //invert since toggling
            self.isDisabled = !self.isDisabled;
            
            //set menu state
            [self setState];
            
            //send to daemon
            // will update preferences
            [self.daemonComms updatePreferences:@{PREF_IS_DISABLED: [NSNumber numberWithBool:self.isDisabled]}];
            
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
            //get path to main app
            mainApp = getMainAppPath();
            
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
        alert.alertStyle = NSAlertStyleWarning;
        
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
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"setting state to: %@", (self.isDisabled) ? @"disabled" : @"enabled"]);
    
    //set to disabled
    if(YES == self.isDisabled)
    {
        //update status
        [self.statusItem.menu itemWithTag:status].title = @"DND: disabled";
        
        //change text
        [self.statusItem.menu itemWithTag:toggleStatus].title = @"Enable";
    }
    
    //set to enabled
    else
    {
        //update status
        [self.statusItem.menu itemWithTag:status].title = @"DND: enabled";
        
        //change text
        [self.statusItem.menu itemWithTag:toggleStatus].title = @"Disable";
    }
    
    //set icon
    [self setIcon];
    
    return;
}

@end
