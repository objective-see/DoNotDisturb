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
@synthesize updateMode;
@synthesize updateView;
@synthesize daemonComms;
@synthesize executePath;
@synthesize generalView;
@synthesize passiveMode;
@synthesize headlessMode;
@synthesize executeAction;
@synthesize monitorAction;
@synthesize updateWindowController;

//init 'general' view
// add it, and make it selected
-(void)awakeFromNib
{
    //init w/ 'general' view
    [self.window.contentView addSubview:self.generalView];
    
    //set title
    self.window.title = [NSString stringWithFormat:@"DoNotDisturb (v. %@)", getAppVersion()];
    
    //set frame rect
    self.generalView.frame = CGRectMake(0, 100, self.window.contentView.frame.size.width, self.window.contentView.frame.size.height-100);
    
    //make 'general' selected
    [self.toolbar setSelectedItemIdentifier:TOOLBAR_GENERAL_ID];
    
    //disable touchID mode option
    // if: no touch bar || < 10.13.4
    if( (YES != hasTouchID()) ||
        (YES != [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 13, 4}]) )
    {
        //disable
        self.touchIDMode.enabled = NO;
    }
    
    //load/serialize preferences
    [self loadPreferences];

    //init daemon
    // use local var here, as we need to block
    daemonComms = [[DaemonComms alloc] init];
    
    return;
}

//load preferences from disk
// serialize each into iVar (button, text field, etc)
-(void)loadPreferences
{
    //preferences
    NSDictionary* preferences = nil;
    
    //instance varialble
    Ivar instanceVariable = nil;
    
    //instance variable obj
    id iVarObj = nil;
    
    //load from disk
    preferences = [NSDictionary dictionaryWithContentsOfFile:PREFS_FILE];
    
    //extract each key/value pair an assign to iVar
    for(NSString* key in preferences)
    {
        //get instance variable by name
        instanceVariable = class_getInstanceVariable([self class], key.UTF8String);
        if(NULL == instanceVariable)
        {
            //skip
            continue;
        }
        
        //get iVar object
        iVarObj = object_getIvar(self, instanceVariable);
        if(nil == iVarObj)
        {
            //skip
            continue;
        }
        
        //button iVar
        if(YES == [[iVarObj class] isSubclassOfClass:[NSButton class]])
        {
            //set button's state
            ((NSButton*)iVarObj).state = [preferences[key] boolValue];
        }
        
        //text field iVar
        else if(YES == [[iVarObj class] isSubclassOfClass:[NSTextField class]])
        {
            //set text field's string
            ((NSTextField*)iVarObj).stringValue = preferences[key];
        }
    }
    
    //set execute path field state to match
    self.executePath.enabled = self.executeAction.state;
    
    return;
}

//toolbar view handler
// toggle view based on user selection
-(IBAction)toolbarButtonHandler:(id)sender
{
    //view
    NSView* view = nil;
    
    //height of toolbar
    float toolbarHeight = 0.0f;
    
    //remove previous subview
    [[[self.window.contentView subviews] lastObject] removeFromSuperview];
    
    //assign view
    switch(((NSToolbarItem*)sender).tag)
    {
        //general
        case TOOLBAR_GENERAL:
            view = self.generalView;
            break;
            
        //action
        case TOOLBAR_ACTION:
            view = self.actionView;
            break;
            
        //link
        case TOOLBAR_LINK:
            view = self.linkView;
            
            //generate/display QRC
            [self generateQRC];
            
            break;
            
        //update
        case TOOLBAR_UPDATE:
            view = self.updateView;
            break;
            
        default:
            break;
    }
    
    //get height of toolbar
    toolbarHeight = [self toolbarHeight];
    
    //set frame rect
    view.frame = CGRectMake(0, toolbarHeight, self.window.contentView.frame.size.width, self.window.contentView.frame.size.height-toolbarHeight);
    
    //add to window
    [self.window.contentView addSubview:view];
    
    return;
}

//invoked when user toggles button
// update preferences for that button, and possibly perform immediate action
-(IBAction)togglePreference:(id)sender
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
    
    //passiveMode
    if(sender == self.passiveMode)
    {
        //set
        preferences[PREF_PASSIVE_MODE] = [NSNumber numberWithBool:self.passiveMode.state];
    }
    
    //icon/headless
    // also restart login item
    else if(sender == self.headlessMode)
    {
        //set
        preferences[PREF_HEADLESS_MODE] = [NSNumber numberWithBool:self.headlessMode.state];
    }

    //touchID mode
    else if(sender == self.touchIDMode)
    {
        //set
        preferences[PREF_TOUCHID_MODE] = [NSNumber numberWithBool:self.touchIDMode.state];
    }

    //execute action
    else if(sender == self.executeAction)
    {
        //set
        preferences[PREF_EXECUTE_ACTION] = [NSNumber numberWithBool:self.executeAction.state];
        
        //set path field state to match
        self.executePath.enabled = self.executeAction.state;
    }
    
    //monitoring action
    else if(sender == self.monitorAction)
    {
        //set
        preferences[PREF_MONITOR_ACTION] = [NSNumber numberWithBool:self.monitorAction.state];
    }
    
    //update
    else if(sender == self.updateMode)
    {
        //set
        preferences[PREF_NOUPDATES_MODE] = [NSNumber numberWithBool:self.updateMode.state];
    }
    
    //send to daemon
    // will update preferences
    [daemonComms updatePreferences:preferences];
    
    //restart login item if user toggle'd icon state
    // this has to be done after the prefs are written out by the daemon
    if(sender == self.headlessMode)
    {
        //restart login item
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) startLoginItem:TRUE];
    }
    
    return;
}

//invoked when we show QRC view
// ping daemon for QRC, display it, etc
-(void)generateQRC
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
    
    //generate QRC
    [qrcObj generateQRC:qrcSize reply:^(NSImage* qrcImage)
     {
         //show QRC
         // on main thread since it's UI-related
         dispatch_sync(dispatch_get_main_queue(), ^{
             
             //display QRC
             [self displayQRC:qrcImage];
             
         });
         
         //init daemon comms
         // will connect, etc.
         daemonComms = [[DaemonComms alloc] init];
         
         //call into daemon/framework
         // this will block until phone linking/registration is complete
         [daemonComms recvRegistrationACK:^(NSDictionary* registrationInfo)
          {
              //TODO: remove
              [NSThread sleepForTimeInterval:2.0f];
              
              dispatch_sync(dispatch_get_main_queue(), ^{
                  
                  //update image view
                  self.qrcImageView.image = [NSImage imageNamed:@"linked"];
        
              });
              
          }];
         
     }];
    
    return;
}

//display QRC code
-(void)displayQRC:(NSImage*)qrcImage
{
    //set image
    self.qrcImageView.image = qrcImage;
    
    //show
    self.qrcImageView.hidden = NO;
    
    return;
}

//automatically called when 'enter' is hit
// save values that were entered in text field
-(void)controlTextDidEndEditing:(NSNotification *)notification
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
    
    //execute path?
    else if([notification object] == self.executePath)
    {
        //set
        preferences[PREF_EXECUTION_PATH] = self.executePath.stringValue;
    }
    
    //send to daemon
    // will update preferences
    [daemonComms updatePreferences:preferences];
    
    return;
}

//the 'controlTextDidEndEditing' notification might not fire
// so always capture/save the all values from text fields here...
-(void)windowWillClose:(NSNotification *)notification
{
    //preferences
    NSMutableDictionary* preferences = nil;
    
    //load preferences from disk
    preferences = [NSMutableDictionary dictionaryWithContentsOfFile:PREFS_FILE];
    
    //save execute path
    preferences[PREF_EXECUTION_PATH] = self.executePath.stringValue;
    
    //send to daemon
    // will update preferences
    [daemonComms updatePreferences:preferences];
 
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
            #ifndef NDEBUG
            logMsg(LOG_DEBUG, @"no updates available");
            #endif
            
            //set lable
            self.updateLabel.stringValue = @"no new versions";
            
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
            
            //set label
            //self.updateLabel.stringValue = [NSString stringWithFormat:@"a new version (%@) is available", newVersion];
            
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
