//
//  file: AppDelegate.m
//  project: DoNotDisturb (login item)
//  description: app delegate for login item
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Update.h"
#import "utilities.h"
#import "AppDelegate.h"
#import <AVFoundation/AVFoundation.h>

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//xpc connection to daemon
XPCDaemonClient* xpcDaemonClient;

@implementation AppDelegate

@synthesize aboutWindowController;
@synthesize prefsWindowController;
@synthesize updateWindowController;
@synthesize statusBarItemController;

//app's main interface
-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
    //'no daemon' alert
    NSAlert* alert = nil;
    
    //parent
    NSDictionary* parent = nil;
    
    //flag
    BOOL autoLaunched = NO;
    
    //preferences
    NSDictionary* preferences = nil;
    
    //get real parent
    parent = getRealParent(getpid());
    
    //dbg msg(s)
    os_log_debug(logHandle, "(real) parent: %{public}@", parent);
    
    //set auto launched flag (i.e. login item)
    if(YES == [parent[@"CFBundleIdentifier"] isEqualToString:@"com.apple.loginwindow"])
    {
        //set flag
        autoLaunched = YES;
    }

    //init deamon comms
    // establishes connection to daemon
    xpcDaemonClient = [[XPCDaemonClient alloc] init];
    
    //first launch?
    // save any prefs passed in from installer
    if([NSProcessInfo.processInfo.arguments containsObject:INITIAL_LAUNCH]) {
        
        NSArray* args = NSProcessInfo.processInfo.arguments;
        NSMutableDictionary* initialPreferences = [NSMutableDictionary dictionary];
        NSArray* prefKeys = @[PREF_PASSIVE_MODE, PREF_TOUCH_ID_MODE, PREF_APPLE_WATCH_MODE];
            
        //extract set key/value pairs
        for(NSString* key in prefKeys) {
            NSUInteger index = [args indexOfObject:key];
            if(index != NSNotFound && index + 1 < args.count) {
                initialPreferences[key] = @([args[index + 1] integerValue]);
            }
        }
        
        os_log_debug(logHandle, "initial preferences: %{public}@", initialPreferences);
            
        //set init prefs
        [xpcDaemonClient updatePreferences:initialPreferences];
    }
    
    //observer to screen locked
    [NSDistributedNotificationCenter.defaultCenter addObserver:self
               selector:@selector(screenLockedNotification:)
                   name:@"com.apple.screenIsLocked"
                 object:nil];
    
    //observer screen unlocked
    [NSDistributedNotificationCenter.defaultCenter addObserver:self
               selector:@selector(screenUnlockedNotification:)
                   name:@"com.apple.screenIsUnlocked"
                 object:nil];
    
    os_log_debug(logHandle, "registered for screen lock/unlock notifications");

    //get preferences
    // sends XPC message to daemon
    preferences = [xpcDaemonClient getPreferences];
    if(!preferences.count) {
        
        //init alert
        alert = [[NSAlert alloc] init];
        
        //set style
        alert.alertStyle = NSAlertStyleInformational;
        
        //set main text
        alert.messageText = [NSString stringWithFormat:@"Could Not Connect to the %@ Daemon", PRODUCT_NAME];
        
        //set informative test
        alert.informativeText = [NSString stringWithFormat:@"Please ensure that the %@ daemon is currently running.", PRODUCT_NAME];
        
        //add button
        [alert addButtonWithTitle:@"OK"];
        
        //show modal
        [alert runModal];
        
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "loaded preferences: %{public}@", preferences);
    
    //when user (manually) runs app
    // show the app's preferences window
    if( (!autoLaunched) &&
        (![NSProcessInfo.processInfo.arguments containsObject:INITIAL_LAUNCH]) ) {
    
        [self showPreferences:0];
    }
    
    //complete initializations
    [self completeInitialization:preferences];
    
bail:
        
    return;
}

//notification callback: screen locked
-(void)screenLockedNotification:(NSNotification *)notification {
    
    os_log_debug(logHandle, "received screen locked notification");
    self.screenLocked = YES;
}

//notification callback: screen unlocked
-(void)screenUnlockedNotification:(NSNotification *)notification {
    
    os_log_debug(logHandle, "received screen unlocked notification");
    self.screenLocked = NO;
}

//handler for main menu
-(IBAction)menuHandler:(id)sender
{
    //handle selection
    switch(((NSButton*)sender).tag) {
            
        //about
        case MENU_ITEM_ABOUT:
            [self showAbout:nil];
            break;
    
        //settings
        case MENU_ITEM_SETTINGS:
            [self showPreferences:0];
            break;
           
        //quit
        case MENU_ITEM_QUIT:
            [self quit:nil];
            break;
            
        default:
            break;
    }
    
    return;
}

//handle user double-clicks
// app is (likely) already running as login item, so show (or) activate window
-(BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)hasVisibleWindows
{
    //dbg msg
    os_log_debug(logHandle, "method '%s' invoked (hasVisibleWindows: %d)", __PRETTY_FUNCTION__, hasVisibleWindows);
    
    //no visible window(s)
    // default to show preferences
    if(YES != hasVisibleWindows)
    {
        //show prefs
        [self showPreferences:0];
    }
    
    return NO;
}

//show settings
-(void)showPreferences:(NSInteger)tag {
    
    NSToolbarItemIdentifier identifier = nil;
    
    //alloc prefs window controller
    if(nil == self.prefsWindowController)
    {
        //alloc
        prefsWindowController = [[PrefsWindowController alloc] initWithWindowNibName:@"Preferences"];
    }
    
    //map tag -> toolbar identifier
    switch(tag)
    {
        case TOOLBAR_ALERTS:
            identifier = TOOLBAR_ALERTS_ID;
            break;
            
        case TOOLBAR_ACTIONS:
            identifier = TOOLBAR_ACTIONS_ID;
            break;
            
        case TOOLBAR_UPDATES:
            identifier = TOOLBAR_UPDATES_ID;
            break;
            
        case TOOLBAR_MODES:
        default:
            tag = TOOLBAR_MODES;
            identifier = TOOLBAR_MODES_ID;
            break;
    }
    
    //make active
    [self makeActive:self.prefsWindowController];
    
    //select toolbar item
    [self.prefsWindowController.toolbar setSelectedItemIdentifier:identifier];
    
    //update toolbar view
    [self.prefsWindowController showToolbarView:tag];
    
    return;
}

//'about' menu item handler
// alloc/show the about window
-(IBAction)showAbout:(id)sender
{
    //alloc/init settings window
    if(nil == self.aboutWindowController)
    {
        //alloc/init
        aboutWindowController = [[AboutWindowController alloc] initWithWindowNibName:@"AboutWindow"];
    }
    
    //center window
    [[self.aboutWindowController window] center];
    
    //show it
    [self.aboutWindowController showWindow:self];
    
    return;
}

//quit button handler
// do any cleanup, then exit
-(IBAction)quit:(id)sender
{
    //response
    NSModalResponse response = 0;
    
    //dbg msg
    os_log_debug(logHandle, "function '%s' invoked", __PRETTY_FUNCTION__);
    
    //show alert
    response = showAlert(NSAlertStyleInformational, [NSString stringWithFormat:@"Quit %@?", PRODUCT_NAME], @"Protection will be paused until your next login.", @[@"Quit", @"Cancel"]);
    
    //show alert
    // cancel? ignore
    if(NSAlertSecondButtonReturn == response)
    {
         //dbg msg
         os_log_debug(logHandle, "user canceled quitting");
         
         //(re)background
         [self setActivationPolicy];
    }
    //ok
    // user wants to quit!
    else
    {
        //dbg msg
        os_log_debug(logHandle, "user confirmed quit");
        
        //slight delay to let alert dismiss
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                  
            //tell daemon to quit
            [xpcDaemonClient quit];
            
            //and terminate self
            [NSApplication.sharedApplication terminate:self];
            
        });
    }
    
    return;
}

//close window handler
-(IBAction)closeWindow:(id)sender {
    
    //key window
    NSWindow *keyWindow = nil;
    
    //get key window
    keyWindow = [[NSApplication sharedApplication] keyWindow];
    
    //dbg msg
    os_log_debug(logHandle, "close window request (key window: %{public}@)", keyWindow);

    //close
    // but only for pref/about window
    if( (keyWindow != self.aboutWindowController.window) &&
        (keyWindow != self.prefsWindowController.window) )
    {
        //dbg msg
        os_log_debug(logHandle, "key window is not about or pref window, so ignoring...");
        
        //ignore
        goto bail;
    }
    
    //close
    [keyWindow close];
    
    //set activation policy
    [self setActivationPolicy];
    
bail:
    
    return;
}

//make a window control/window front/active
-(void)makeActive:(NSWindowController*)windowController
{
    //make foreground
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    
    //center
    [windowController.window center];

    //show it
    [windowController showWindow:self];
    
    //make it key window
    [[windowController window] makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//toggle (status) bar icon
-(void)toggleIcon:(NSDictionary*)preferences
{
    //dbg msg
    os_log_debug(logHandle, "toggling icon state");
    
    //should run with no icon?
    // init and show status bar item
    if(YES != [preferences[PREF_NO_ICON_MODE] boolValue])
    {
        //already showing?
        if(nil != self.statusBarItemController)
        {
            //bail
            goto bail;
        }
        
        //alloc/load status bar icon/menu
        // will configure, and show popup/menu
        statusBarItemController = [[StatusBarItem alloc] init:self.statusMenu preferences:(NSDictionary*)preferences];
    }
    
    //run without icon
    // remove status bar item
    else
    {
        //already removed?
        if(nil == self.statusBarItemController)
        {
            //bail
            goto bail;
        }
        
        //remove status item
        [self.statusBarItemController removeStatusItem];
        
        //unset
        self.statusBarItemController = nil;
    }
    
bail:
    
    return;
}

//set app foreground/background
-(void)setActivationPolicy
{
    //visible window
    BOOL visibleWindow = NO;
    
    //dbg msg
    os_log_debug(logHandle, "setting app's activation policy");
    
    //dbg msg
    os_log_debug(logHandle, "windows: %{public}@", NSApp.windows);
    
    //find any visible windows
    for(NSWindow* window in NSApp.windows)
    {
        //ignore status bar
        if(YES == [window.className isEqualToString:@"NSStatusBarWindow"])
        {
            //skip
            continue;
        }
        
        //visible?
        if(YES == window.isVisible)
        {
            //set flag
            visibleWindow = YES;
            
            //done
            break;
        }
    }
    
    //any windows?
    //bring app to foreground
    if(YES == visibleWindow)
    {
        //dbg msg
        os_log_debug(logHandle, "window(s) visible, setting policy: NSApplicationActivationPolicyRegular");
        
        //foreground
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    }
    
    //no more windows
    // send app to background
    else
    {
        //dbg msg
        os_log_debug(logHandle, "window(s) not visible, setting policy: NSApplicationActivationPolicyAccessory");
        
        //background
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    }
    
    return;
}


//finish up initializations
// based on prefs, show status bar, check for updates, etc...
-(void)completeInitialization:(NSDictionary*)preferences
{
    //run with status bar icon?
    if(YES != [preferences[PREF_NO_ICON_MODE] boolValue])
    {
        //alloc/load nib
        statusBarItemController = [[StatusBarItem alloc] init:self.statusMenu preferences:(NSDictionary*)preferences];
        
        //dbg msg
        os_log_debug(logHandle, "initialized/loaded status bar (icon/menu)");
    }
    else
    {
        //dbg msg
        os_log_debug(logHandle, "running in 'no icon' mode (so no need for status bar)");
    }
    
    //automatically check for updates?
    if(YES != [preferences[PREF_NO_UPDATE_MODE] boolValue])
    {
        //after a 30 seconds
        // check for updates in background
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
        {
            //dbg msg
            os_log_debug(logHandle, "checking for update");
           
            //check
            [self check4Update];
       });
    }
    
    return;
}

//call into Update obj
// check to see if there an update?
-(void)check4Update
{
    //update obj
    Update* update = nil;
    
    //init update obj
    update = [[Update alloc] init];
    
    //check for update
    // ->'updateResponse newVersion:' method will be called when check is done
    [update checkForUpdate:^(NSUInteger result, NSString* newVersion) {
        
        //process response on main thread (UI work)
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateResponse:result newVersion:newVersion];
        });
        
    }];
    
    return;
}

//process update response
// error, no update, update/new version
-(void)updateResponse:(NSInteger)result newVersion:(NSString*)newVersion
{
    //handle response
    // new version, show popup
    switch (result)
    {
        //error
        case -1:
            
            //err msg
            os_log_error(logHandle, "ERROR: update check failed");
            break;
            
        //no updates
        case 0:
            
            //dbg msg
            os_log_debug(logHandle, "no updates available");
            break;
            
        //new version
        case 1:
            
            //dbg msg
            os_log_debug(logHandle, "a new version (%{public}@) is available", newVersion);

            //alloc update window
            updateWindowController = [[UpdateWindowController alloc] initWithWindowNibName:@"UpdateWindow"];
            
            //configure
            [self.updateWindowController configure:[NSString stringWithFormat:@"a new version (%@) is available!", newVersion] buttonTitle:@"Update"];
            
            //center window
            [[self.updateWindowController window] center];
            
            //show it
            [self.updateWindowController showWindow:self];
            
            //float above other windows
            [self.updateWindowController.window setLevel:NSFloatingWindowLevel];
            [self.updateWindowController.window makeKeyAndOrderFront:nil];
        
            break;
    }
    
    return;
}

@end
