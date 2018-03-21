//
//  file: AppDelegate.m
//  project: DnD (login item)
//  description: app delegate for login item
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Update.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "AlertMonitor.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

@synthesize appObserver;
@synthesize daemonComms;
@synthesize updateWindowController;
@synthesize statusBarMenuController;

//app's main interface
// load status bar (unless prefs say otherwise) and kick off monitor
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //app preferences
    NSDictionary* preferences = nil;
    
    //path to main app
    NSURL* mainApp = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"starting DnD login item");
    
    //init deamon comms
    daemonComms = [[DaemonComms alloc] init];
    
    //get preferences
    // sends XPC message to daemon
    preferences = [self.daemonComms getPreferences];
    
    //no preferences yet? ... first run
    // a) set some defaults for login item (passive mode, etc)
    // b) wait for main app to exit before checking in with daemon
    if(0 == preferences.count)
    {
        //set some default prefs
        preferences = @{PREF_PASSIVE_MODE:@NO, PREF_NO_ICON_MODE:@NO, PREF_NO_UPDATES_MODE:@NO, PREF_START_MODE:@YES};
        
        //get path to main app
        mainApp = [NSURL fileURLWithPath:getMainAppPath()];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"waiting for %@ to terminate", mainApp.path]);
        
        //set up notification for main app exit
        // wait until it's exited to complete initializations
        self.appObserver = [[[NSWorkspace sharedWorkspace] notificationCenter] addObserverForName:NSWorkspaceDidTerminateApplicationNotification object:nil queue:nil usingBlock:^(NSNotification *notification)
         {
             //ignore others
             if(YES != [MAIN_APP_ID isEqualToString:[((NSRunningApplication*)notification.userInfo[NSWorkspaceApplicationKey]) bundleIdentifier]])
             {
                 return;
             }
             
             //dbg msg
             logMsg(LOG_DEBUG, @"main application completed");
             
             //remove observer
             [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self.appObserver];
             
             //unset
             self.appObserver = nil;
             
             //set defaults prefs
             [self.daemonComms updatePreferences:preferences];
             
             //complete initializations
             [self completeInitialization:preferences firstTime:YES];
         }];
    }
    
    //found prefs
    // main app already ran, so just complete init's
    else
    {
        //complete initializations
        [self completeInitialization:preferences firstTime:NO];
    }

bail:
    
    return;
}

//finish up initializations
// based on prefs, show status bar, check for updates, etc...
-(void)completeInitialization:(NSDictionary*)preferences firstTime:(BOOL)firstTime
{
    //alert monitor obj
    __block AlertMonitor* alertMonitor = nil;
    
    //run with status bar icon?
    if(YES != [preferences[PREF_NO_ICON_MODE] boolValue])
    {
        //alloc/load nib
        statusBarMenuController = [[StatusBarMenu alloc] init:self.statusMenu firstTime:firstTime];
        
        //dbg msg
        logMsg(LOG_DEBUG, @"initialized/loaded status bar (icon/menu)");
    }
    
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"running in 'no icon'' mode");
    }
    
    //automatically check for updates?
    if(YES != [preferences[PREF_NO_UPDATES_MODE] boolValue])
    {
        //after a 30 seconds
        // check for updates in background
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
        {
           //dbg msg
           logMsg(LOG_DEBUG, @"checking for update");

           //check
           [self check4Update];
           
        });
    }
    
    //wait to checkin
    // first time, need a bit to show the popover
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, firstTime * 5 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        //init alert monitor
        alertMonitor = [[AlertMonitor alloc] init];
        
        //in background
        // monitor / process alerts from daemon
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //monitor
            [alertMonitor monitor];
            
        });
        
        //in background
        // wait for alert dimiss msgs from daemon
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //monitor
            [alertMonitor dismissAlerts];
            
        });
        
    });
    
    return;
}

//init/show touch bar
-(void)initTouchBar
{
    //touch bar items
    NSArray *touchBarItems = nil;
    
    //touch bar API is only 10.12.2+
    if(@available(macOS 10.12.2, *))
    {
        //alloc/init
        self.touchBar = [[NSTouchBar alloc] init];
        if(nil == self.touchBar)
        {
            //no touch bar?
            goto bail;
        }
        
        //set delegate
        self.touchBar.delegate = self;
        
        //set id
        self.touchBar.customizationIdentifier = @"com.objective-see.dnd";
        
        //init items
        touchBarItems = @[@".icon", @".label", @".button"];
        
        //set items
        self.touchBar.defaultItemIdentifiers = touchBarItems;
        
        //set customization items
        self.touchBar.customizationAllowedItemIdentifiers = touchBarItems;
        
        //want button in center
        self.touchBar.principalItemIdentifier = @".button";
        
        //activate so touch bar shows up
        [NSApp activateIgnoringOtherApps:YES];
    }
    
bail:
    
    return;
}

//delegate method
// init item for touch bar
-(NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier
{
    //icon view
    NSImageView *iconView = nil;
    
    //icon
    NSImage* icon = nil;
    
    //item
    NSCustomTouchBarItem *touchBarItem = nil;
    
    //init item
    touchBarItem = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
    
    //icon
    if(YES == [identifier isEqualToString: @".icon" ])
    {
        //init icon view
        iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 30.0, 30.0)];
        
        //enable layer
        [iconView setWantsLayer:YES];
        
        //set color
        [iconView.layer setBackgroundColor:[[NSColor whiteColor] CGColor]];
        
        //mask
        iconView.layer.masksToBounds = YES;
        
        //round corners
        iconView.layer.cornerRadius = 3.0;
        
        //load icon image
        icon = [NSImage imageNamed:@"dndIcon"];
        
        //set size
        icon.size = CGSizeMake(32, 32);
        
        //add image
        iconView.image = icon;
    
        //set view
        touchBarItem.view = iconView;
    }
    
    //label
    else if(YES == [identifier isEqualToString:@".label"])
    {
        //item label
        touchBarItem.view = [NSTextField labelWithString:@"Do Not Disturb Alert: lid opened!"];
    }
    
    //button
    else if(YES == [identifier isEqualToString:@".button"])
    {
        //init button
        touchBarItem.view = [NSButton buttonWithTitle: @"Dismiss" target:self action: @selector(touchBarButtonHandler:)];
    }
    
    return touchBarItem;
}

//button handler
-(IBAction)touchBarButtonHandler:(id)sender
{
    //show notification
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
    
    //unset
    // will hide
    self.touchBar = nil;

    return;
}


//is there an update?
-(void)check4Update
{
    //update obj
    Update* update = nil;
    
    //init update obj
    update = [[Update alloc] init];
    
    //check for update
    // 'updateResponse newVersion:' method will be called when check is done
    [update checkForUpdate:^(NSUInteger result, NSString* newVersion) {
        
        //process response
        [self updateResponse:result newVersion:newVersion];
        
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
            logMsg(LOG_ERR, @"update check failed");
            break;
            
        //no updates
        case 0:
            
            //dbg msg
            logMsg(LOG_DEBUG, @"no updates available");
            
            break;
            
        //new version
        case 1:
            
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"a new version (%@) is available", newVersion]);
     
            //alloc update window
            updateWindowController = [[UpdateWindowController alloc] initWithWindowNibName:@"UpdateWindow"];
            
            //configure
            [self.updateWindowController configure:[NSString stringWithFormat:@"a new version (%@) is available!", newVersion] buttonTitle:@"Update"];
            
            //center window
            [[self.updateWindowController window] center];
            
            //show it
            [self.updateWindowController showWindow:self];
            
            //invoke function in background that will make window modal
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                //make modal
                makeModal(self.updateWindowController);
                
            });
        
            break;
    }
    
    return;
}

@end
