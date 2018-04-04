//
//  file: PrefsWindowController.h
//  project: DnD (main app)
//  description: preferences window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Update.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "DaemonComms.h"
#import "QuickResponseCode.h"
#import "PrefsWindowController.h"
#import "UpdateWindowController.h"

#import <objc/runtime.h>

@implementation PrefsWindowController

@synthesize toolbar;
@synthesize actionView;
@synthesize updateView;
@synthesize daemonComms;
@synthesize executePath;
@synthesize generalView;
@synthesize overlayView;
@synthesize updateButton;
@synthesize overlayIndicator;
@synthesize updateWindowController;

//init 'general' view
// add it, and make it selected
-(void)awakeFromNib
{
    //set title
    self.window.title = [NSString stringWithFormat:@"Do Not Disturb (v. %@)", getAppVersion()];
    
    //init daemon comms
    daemonComms = [[DaemonComms alloc] init];
    
    //make 'general' selected
    [self.toolbar setSelectedItemIdentifier:TOOLBAR_GENERAL_ID];
    
    //set general prefs as default
    [self toolbarButtonHandler:nil];
    
    //enable touchID mode option
    // if: < 10.13.4 (check first!) && no touch bar
    if( (YES == [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 13, 4}]) &&
        (YES == hasTouchID()) )
    {
        //enable button
        ((NSButton*)[self.generalView viewWithTag:BUTTON_TOUCHID_MODE]).enabled = YES;
    }
    
    return;
}

//required for toolbar item enable/disable
-(BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
    return [toolbarItem isEnabled] ;
}

//toolbar view handler
// toggle view based on user selection
-(IBAction)toolbarButtonHandler:(id)sender
{
    //view
    NSView* view = nil;
    
    //registered devices
    __block NSDictionary* registeredDevices = nil;
    
    //height of toolbar
    float toolbarHeight = 0.0f;
    
    //when we've prev added a view
    // remove the prev view cuz adding a new one
    if(nil != sender)
    {
        //remove
        [[[self.window.contentView subviews] lastObject] removeFromSuperview];
    }
    
    //get (latest) prefs
    self.preferences = [self.daemonComms getPreferences:nil];
    
    //get height of toolbar
    toolbarHeight = [self toolbarHeight];
    
    //assign view
    switch(((NSToolbarItem*)sender).tag)
    {
        //general
        case TOOLBAR_GENERAL:
        {
            //set view
            view = self.generalView;
            
            //set 'passive mode' button state
            ((NSButton*)[view viewWithTag:BUTTON_PASSIVE_MODE]).state = [self.preferences[PREF_PASSIVE_MODE] boolValue];
            
            //set 'no icon' button state
            ((NSButton*)[view viewWithTag:BUTTON_NO_ICON_MODE]).state = [self.preferences[PREF_NO_ICON_MODE] boolValue];
            
            //set 'touch id' button state
            ((NSButton*)[view viewWithTag:BUTTON_TOUCHID_MODE]).state = [self.preferences[PREF_TOUCHID_MODE] boolValue];
            
            //set 'start mode' button state
            ((NSButton*)[view viewWithTag:BUTTON_START_MODE]).state = [self.preferences[PREF_START_MODE] boolValue];
                         
            break;
        }
            
        //action
        case TOOLBAR_ACTION:
        {
            //set view
            view = self.actionView;
            
            //set 'execute action' button state
            ((NSButton*)[view viewWithTag:BUTTON_EXECUTE_ACTION]).state = [self.preferences[PREF_EXECUTE_ACTION] boolValue];
            
            //set 'execute action' 
            if(0 != [self.preferences[PREF_EXECUTE_PATH] length])
            {
                //set
                self.executePath.stringValue = self.preferences[PREF_EXECUTE_PATH];
            }
            
            //set state of 'execute action' to match
            self.executePath.enabled = [self.preferences[PREF_EXECUTE_ACTION] boolValue];
            
            //set 'monitor' button state
            ((NSButton*)[view viewWithTag:BUTTON_MONITOR_ACTION]).state = [self.preferences[PREF_MONITOR_ACTION] boolValue];
            
            //set 'disable camera' button state
            ((NSButton*)[view viewWithTag:BUTTON_NO_CAMERA]).state = [self.preferences[PREF_NO_CAMERA] boolValue];
            
            break;
        }
        
        //link/unlink
        // first show overlay view
        case TOOLBAR_LINK:
        {
            //set overlay view's rect
            self.overlayView.frame = CGRectMake(0, toolbarHeight, self.window.contentView.frame.size.width, self.window.contentView.frame.size.height-toolbarHeight);
            
            //start spinner
            [self.overlayIndicator startAnimation:nil];
            
            //show overlay view
            [self.window.contentView addSubview:self.overlayView];
            
            //disable all toolbar items
            for(NSToolbarItem* toolbarItem in self.toolbar.items)
            {
                //disable
                toolbarItem.enabled = NO;
            }
            
            //now get registered devices
            // this can ping server, so do in background
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                //get devices
                registeredDevices = [self.daemonComms getPreferences:PREF_REGISTERED_DEVICES];
                
                //nap to allow msg to show up
                [NSThread sleepForTimeInterval:0.5];
                
                //update UI
                dispatch_async(dispatch_get_main_queue(),
                ^{
                    //process / update UI
                    [self processRegisteredDevices:registeredDevices];
                    
                });
            });
            
            break;
        }
            
        //update
        case TOOLBAR_UPDATE:
        {
            //set view
            view = self.updateView;
            
            //set 'no update' button state
            ((NSButton*)[view viewWithTag:BUTTON_NO_UPDATES_MODE]).state = [self.preferences[PREF_NO_UPDATES_MODE] boolValue];
            
            break;
        }
            
        default:
            return;
    }
    
    //set frame rect
    view.frame = CGRectMake(0, toolbarHeight, self.window.contentView.frame.size.width, self.window.contentView.frame.size.height-toolbarHeight);
    
    //add to window
    [self.window.contentView addSubview:view];
    
    return;
}

//once daemon (and possibly server) has responded
// show either 'link/QRC' view or 'linked' view w/ devices
-(void)processRegisteredDevices:(NSDictionary*)registeredDevices
{
    //view
    NSView* view = nil;
    
    //height of toolbar
    float toolbarHeight = 0.0f;
    
    //get height of toolbar
    toolbarHeight = [self toolbarHeight];
    
    //remove overlay subview
    [[[self.window.contentView subviews] lastObject] removeFromSuperview];
    
    //if devices are registered
    // show linked devices view...
    if(0 != registeredDevices[PREF_REGISTERED_DEVICES])
    {
        //set view
        view = self.linkedView;
        
        //set host name
        self.hostName.stringValue = [[NSHost currentHost] localizedName];
        
        //set font
        self.deviceNames.font = [NSFont fontWithName:@"Avenir Next Condensed Regular" size:20];
        
        //set inset
        self.deviceNames.textContainerInset = NSMakeSize(5.0, 10.0);
        
        //reset
        self.deviceNames.string = @"";
        
        //populate text view w/ registered devices
        for(NSString* deviceToken in registeredDevices[PREF_REGISTERED_DEVICES])
        {
            //append
            self.deviceNames.string = [self.deviceNames.string stringByAppendingString:[NSString stringWithFormat: @"📱%@\n", registeredDevices[PREF_REGISTERED_DEVICES][deviceToken]]];
        }
        
        //remove final newline
        self.deviceNames.string = [self.deviceNames.string stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    }
    
    //no device registered
    // show 'generate QRC' view so user can link
    else
    {
        //set view
        view = self.linkView;
    }
    
    //set frame rect
    view.frame = CGRectMake(0, toolbarHeight, self.window.contentView.frame.size.width, self.window.contentView.frame.size.height-toolbarHeight);
    
    //add to window
    [self.window.contentView addSubview:view];
    
    //enable all toolbar items
    for(NSToolbarItem* toolbarItem in self.toolbar.items)
    {
        //disable
        toolbarItem.enabled = YES;
    }
    
    return;
}

//invoked when user toggles button
// update preferences for that button, and possibly perform (immediate) action
-(IBAction)togglePreference:(id)sender
{
    //preferences
    NSMutableDictionary* preferences = nil;
    
    //button state
    NSNumber* state = nil;
    
    //init
    preferences = [NSMutableDictionary dictionary];
    
    //get button state
    state = [NSNumber numberWithBool:((NSButton*)sender).state];
    
    //set appropriate preference
    switch(((NSButton*)sender).tag)
    {
        //passive mode
        case BUTTON_PASSIVE_MODE:
        {
            //set pref
            preferences[PREF_PASSIVE_MODE] = state;
            
            break;
        }
            
        //(no) icon mode
        // login item will be restarted below
        case BUTTON_NO_ICON_MODE:
        {
            //set pref
            preferences[PREF_NO_ICON_MODE] = state;
            
            break;
        }
            
        //touch id mode
        case BUTTON_TOUCHID_MODE:
        {
            //set pref
            preferences[PREF_TOUCHID_MODE] = state;
            
            break;
        }
            
        //start mode
        // also toggle here...
        case BUTTON_START_MODE:
        {
            //set pref
            preferences[PREF_START_MODE] = state;
            
            //toggle login item in background
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
            ^{
                //toggle
                if(YES != toggleLoginItem([NSURL fileURLWithPath:[((AppDelegate*)[[NSApplication sharedApplication] delegate]) path2LoginItem]], [preferences[PREF_START_MODE] intValue]))
                {
                    //err msg
                    logMsg(LOG_ERR, @"failed to toggle login item");
                }
            });
            
            break;
        }
            
        //execute action
        // also toggle state of path
        case BUTTON_EXECUTE_ACTION:
        {
            //set
            preferences[PREF_EXECUTE_ACTION] = state;
            
            //set path field state to match
            self.executePath.enabled = state.boolValue;
            
            break;
        }
        
        //monitor mode
        case BUTTON_MONITOR_ACTION:
        {
            //set pref
            preferences[PREF_MONITOR_ACTION] = state;
            
            break;
        }
            
        //no camera
        case BUTTON_NO_CAMERA:
        {
            //set pref
            preferences[PREF_NO_CAMERA] = state;
            
            break;
        }
        
        //(no) update mode
        case BUTTON_NO_UPDATES_MODE:
        {
            //set pref
            preferences[PREF_NO_UPDATES_MODE] = state;
            
            break;
        }
    }
    
    //tell daemon to update preferences
    [daemonComms updatePreferences:preferences];
    
    //restart login item if user toggle'd icon state
    // note: this has to be done after the prefs are written out by the daemon
    if(BUTTON_NO_ICON_MODE == ((NSButton*)sender).tag)
    {
        //restart login item
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            //restart
            [((AppDelegate*)[[NSApplication sharedApplication] delegate]) startLoginItem:TRUE];
        });
    }
    
    return;
}

//ping daemon for QRC, display it, etc
-(IBAction)generateQRC:(id)sender
{
    //qrc object
    QuickResponseCode* qrcObj = nil;
    
    //daemon comms obj
    __block DaemonComms* daemonComms = nil;
    
    //size
    CGSize qrcSize = {0};
    
    //alloc qrc obj
    qrcObj = [[QuickResponseCode alloc] init];
    
    //grab size while still on main thread
    qrcSize = self.qrcImageView.frame.size;
    
    //set msg color
    self.activityMessage.textColor = [NSColor blackColor];
    
    //set msg
    self.activityMessage.stringValue = @"Generating QR Code\nplease wait...";
    
    //make sure it's showing
    self.activityMessage.hidden = NO;
    
    //start spinnner
    [self.activityIndicator startAnimation:nil];
    
    //show qrc sheet
    // block executed when sheet is closed
    [self.window beginSheet:self.qrcPanel completionHandler:^(NSInteger result) {
    
        //trigger refresh of link view
        [self toolbarButtonHandler:self.linkToolbarItem];
        
        //no need to do anything else...
        // when daemon reponds with registration ack/info, will close sheet
    }];
    
    //generate QRC
    [qrcObj generateQRC:qrcSize.height reply:^(NSImage* qrcImage)
    {
        //allow msg to show
        [NSThread sleepForTimeInterval:0.25];
        
        //sanity check
        if(nil == qrcImage)
        {
            //show error msg on main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                
                //stop spinner
                [self.activityIndicator stopAnimation:nil];
            
                //set message color to red
                self.activityMessage.textColor = [NSColor redColor];
                
                //show err msg
                self.activityMessage.stringValue = @"Error Generating QR Code";
                
            });
            
            return;
        }
        
        //show QRC
        // on main thread since it's UI-related
        dispatch_async(dispatch_get_main_queue(), ^{
        
             //display QRC
             [self displayQRC:qrcImage];
             
        });
        
        //dbg msg
        logMsg(LOG_DEBUG, @"displayed QRC...now waiting for user to scan, server to register and ack");
         
        //init daemon comms
        // will connect, etc.
        daemonComms = [[DaemonComms alloc] init];
        
        //call into daemon/framework
        // this will block until phone linking/registration is complete
        [daemonComms recvRegistrationACK:^(NSDictionary* registrationInfo)
        {
             //dbg msg
             logMsg(LOG_DEBUG, [NSString stringWithFormat:@"received registration ack/info from server/daemon: %@", registrationInfo]);
             
             //call into main thread to display
             dispatch_sync(dispatch_get_main_queue(), ^{
                 
                 //hide qrc sheet
                 [self.window endSheet:self.qrcPanel];
                 
                 //trigger refresh of link view
                 [self toolbarButtonHandler:self.linkToolbarItem];
        
             });
             
        }];
         
    }];
        
    return;
}

//display QRC code
-(void)displayQRC:(NSImage*)qrcImage
{
    //stop spinner
    // will also hide it
    [self.activityIndicator stopAnimation:nil];
    
    //hide message
    self.activityMessage.hidden = YES;
    
    //set image
    self.qrcImageView.image = qrcImage;
    
    //show
    self.qrcImageView.hidden = NO;
    
    return;
}

//invoked when user closes QRC view
// normally view is closed automatically when registration is complete
-(IBAction)closeQRC:(id)sender
{
    //hide qrc
    self.qrcImageView.hidden = YES;
    
    //hide qrc sheet
    [self.window endSheet:self.qrcPanel];
    
    return;
}

//automatically called when 'enter' is hit
// save values that were entered in text field
-(void)controlTextDidEndEditing:(NSNotification *)notification
{
    //execute path?
    if([notification object] != self.executePath)
    {
        //bail
        goto bail;
    }
    
    //send to daemon
    // will update preferences
    [self.daemonComms updatePreferences:@{PREF_EXECUTE_PATH:self.executePath.stringValue, PREF_EXECUTE_USER:getConsoleUser()}];
    
bail:

    return;
}

//the 'controlTextDidEndEditing' notification might not fire
// so always capture/save the all values from text fields here...
-(void)windowWillClose:(NSNotification *)notification
{
    //send to daemon
    // will update preferences
    [self.daemonComms updatePreferences:@{PREF_EXECUTE_PATH:self.executePath.stringValue, PREF_EXECUTE_USER:getConsoleUser()}];
 
    return;
}

//button handler for adding new device
-(IBAction)addDevice:(id)sender
{
    //generate QRC
    [self generateQRC:nil];
    
    return;
}

//'check for update' button handler
-(IBAction)check4Update:(id)sender
{
    //update obj
    Update* update = nil;
    
    //disable button
    self.updateButton.enabled = NO;
    
    //reset
    self.updateLabel.stringValue = @"";
    
    //show/start spinner
    [self.updateIndicator startAnimation:self];
    
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
    //re-enable button
    self.updateButton.enabled = YES;
    
    //stop/hide spinner
    [self.updateIndicator stopAnimation:self];
    
    switch (result)
    {
        //error
        case -1:
            
            //set label
            self.updateLabel.stringValue = @"error: update check failed";
            
            break;
            
        //no updates
        case 0:
            
            //dbg msg
            logMsg(LOG_DEBUG, @"no updates available");
    
            //set label
            self.updateLabel.stringValue = @"no new versions";
            
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

//get height of toolbar
// based on: https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Toolbars/Tasks/DeterminingOverflow.html#//apple_ref/doc/uid/20000859-SW2
-(float)toolbarHeight
{
    //height
    float toolbarHeight = 0.0;
    
    //toolbar
    NSToolbar *toolbar = nil;
    
    //frame
    NSRect windowFrame;
    
    //get toolbard
    toolbar = [self.window toolbar];
    
    //toolbar not found or not visible?
    if( (nil == toolbar) ||
        (YES != toolbar.isVisible) )
    {
        //bail
        goto bail;
    }
    
    //get window frame
    windowFrame = [NSWindow contentRectForFrameRect:[self.window frame] styleMask:[self.window styleMask]];
    
    //calc height
    toolbarHeight = NSHeight(windowFrame) - NSHeight([[self.window contentView] frame]);
    
bail:
    
    return toolbarHeight;
}

@end
