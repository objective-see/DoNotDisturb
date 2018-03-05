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
    #ifndef NDEBUG
    logMsg(LOG_DEBUG, @"starting DnD login item");
    #endif
    
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
        preferences = @{PREF_PASSIVE_MODE:@NO, PREF_NO_ICON_MODE:@NO, PREF_NO_UPDATES_MODE:@NO};
        
        //get path to main app
        mainApp = [NSURL fileURLWithPath:[self getAppPath]];
        
        //set up notification for app exit
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

//get path to (main) app
// login item is in app bundle, so parse up to get main app
-(NSString*)getAppPath
{
    //path components
    NSArray *pathComponents = nil;
    
    //path to config (main) app
    NSString* mainApp = nil;
    
    //get path components
    // then build full path to main app
    pathComponents = [[[NSBundle mainBundle] bundlePath] pathComponents];
    if(pathComponents.count > 4)
    {
        //init path to full (main) app
        mainApp = [NSString pathWithComponents:[pathComponents subarrayWithRange:NSMakeRange(0, pathComponents.count - 4)]];
    }
    
    //when (still) nil
    // use default path
    if(nil == mainApp)
    {
        //default
        mainApp = [@"/Applications" stringByAppendingPathComponent:APP_NAME];
    }
    
    return mainApp;
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
            #ifndef NDEBUG
            logMsg(LOG_DEBUG, @"no updates available");
            #endif
            
            break;
            
        //new version
        case 1:
            
            //dbg msg
            #ifndef NDEBUG
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"a new version (%@) is available", newVersion]);
            #endif
     
            //alloc update window
            updateWindowController = [[UpdateWindowController alloc] initWithWindowNibName:@"UpdateWindow"];
            
            //configure
            [self.updateWindowController configure:[NSString stringWithFormat:@"a new version (%@) is available!", newVersion] buttonTitle:@"update"];
            
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
