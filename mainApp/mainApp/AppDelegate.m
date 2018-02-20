//
//  file: AppDelegate.m
//  project: DnD (main app)
//  description: application delegate
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Update.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "SyncViewController_One.h"
#import "SyncViewController_Two.h"
#import "SyncViewController_Three.h"

@implementation AppDelegate

@synthesize window;
@synthesize linkWindowController;
@synthesize aboutWindowController;
@synthesize prefsWindowController;

//center window
// also make front, init title bar, etc
-(void)awakeFromNib
{
    //install?
    // kick off phone sync ui logic flow
    if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:CMDLINE_FLAG_INSTALL])
    {
        //alloc
        linkWindowController = [[LinkWindowController alloc] initWithWindowNibName:@"Link"];
        
        //center
        [self.linkWindowController.window center];
        
        //key and front
        [self.linkWindowController.window makeKeyAndOrderFront:self];
        
    }
    
    //otherewise show prefs
    else
    {
        //show preferences window
        [self showPreferences:nil];
        
        //center
        [self.prefsWindowController.window center];
        
        //key and front
        [self.prefsWindowController.window makeKeyAndOrderFront:self];
    }
    
    //make app active
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//app interface
// init user interface
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //dbg msg
    #ifndef NDEBUG
    logMsg(LOG_DEBUG, @"main (config) app launched");
    #endif

    //start login item in background
    // method checks first to make sure only single instance is running
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        //start
        [self startLoginItem:NO];
    });
    
    return;
}

//start the (helper) login item
-(BOOL)startLoginItem:(BOOL)shouldRestart
{
    //status var
    BOOL result = NO;
    
    //path to login item app
    NSString* loginItem = nil;
    
    //path to login item binary
    NSString* loginItemBinary = nil;
    
    //login item's pid
    NSNumber* loginItemPID = nil;
    
    //init path to login item app
    loginItem = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"/Contents/Library/LoginItems/%@.app", LOGIN_ITEM_NAME]];
                 
    //init path to binary
    loginItemBinary = [NSString pathWithComponents:@[loginItem, @"Contents", @"MacOS", LOGIN_ITEM_NAME]];
    
    //get pid(s) of login item for user
    loginItemPID = [getProcessIDs(loginItemBinary, getuid()) firstObject];
    
    //didn't find it?
    // try lookup bundle as login items sometimes show up as that
    if(nil == loginItemPID)
    {
        //lookup via bundle
        loginItemPID = [getProcessIDs(HELPER_BUNDLE_ID, getuid()) firstObject];
    }
    
    //already running and no restart?
    if( (nil != loginItemPID) &&
        (YES != shouldRestart) )
    {
        //dbg msg
        #ifndef NDEBUG
        logMsg(LOG_DEBUG, @"login item already running and 'shouldRestart' not set, so no need to start it");
        #endif
        
        //happy
        result = YES;
        
        //bail
        goto bail;
    }
    
    //running?
    // kill, as restart flag set
    else if(nil != loginItemPID)
    {
        //kill it
        kill(loginItemPID.unsignedShortValue, SIGKILL);
        
        //dbg msg
        #ifndef NDEBUG
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"killed login item (%@)", loginItemPID]);
        #endif
        
        //nap
        [NSThread sleepForTimeInterval:0.5];
    }
    
    #ifndef NDEBUG
    else
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"did not find running instance of login item\n");
    }
    #endif
    
    //dbg msg
    #ifndef NDEBUG
    logMsg(LOG_DEBUG, @"starting (helper) login item\n");
    #endif
    
    //start (helper) login item
    // 'open -g' prevents focus loss!
    execTask(OPEN, @[@"-g", loginItem], NO);
    
    //happy
    result = YES;
    
//bail
bail:

    return result;
}

//automatically close when user closes last window
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

//'preferences' menu item handler
// alloc and show preferences window
-(IBAction)showPreferences:(id)sender
{
    //alloc prefs window controller
    if(nil == self.prefsWindowController)
    {
        //alloc
        prefsWindowController = [[PrefsWindowController alloc] initWithWindowNibName:@"Preferences"];
    }
    
    //center
    [self.prefsWindowController.window center];

    //show it
    [self.prefsWindowController showWindow:self];
    
    //make it key window
    [[self.prefsWindowController window] makeKeyAndOrderFront:self];
    
    return;
}

//'about' menu item handler
// alloc/show about window
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
    
    //invoke function in background that will make window modal
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        //make modal
        makeModal(self.aboutWindowController);
        
    });
    
    return;
}

//paste support
// see: https://stackoverflow.com/a/3176930
- (void) sendEvent:(NSEvent *)event {
    if ([event type] == NSKeyDown) {
        if (([event modifierFlags] & NSDeviceIndependentModifierFlagsMask) == NSCommandKeyMask) {
            if ([[event charactersIgnoringModifiers] isEqualToString:@"x"]) {
                if ([self sendAction:@selector(cut:) to:nil from:self])
                    return;
            }
            else if ([[event charactersIgnoringModifiers] isEqualToString:@"c"]) {
                if ([self sendAction:@selector(copy:) to:nil from:self])
                    return;
            }
            else if ([[event charactersIgnoringModifiers] isEqualToString:@"v"]) {
                if ([self sendAction:@selector(paste:) to:nil from:self])
                    return;
            }
    
            else if ([[event charactersIgnoringModifiers] isEqualToString:@"a"]) {
                if ([self sendAction:@selector(selectAll:) to:nil from:self])
                    return;
            }
        }
    }
    [super sendEvent:event];
}

@end
