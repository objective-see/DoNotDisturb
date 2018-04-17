//
//  file: ConfigureWindowController.m
//  project: DND (config)
//  description: configure (install/uninstall) window
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Configure.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "ConfigureWindowController.h"

@implementation ConfigureWindowController

@synthesize statusMsg;
@synthesize moreInfoButton;

//automatically called when nib is loaded
// just center window
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    //when supported
    // indicate title bar is transparent (too)
    if([self.window respondsToSelector:@selector(titlebarAppearsTransparent)])
    {
        //set transparency
        self.window.titlebarAppearsTransparent = YES;
    }
    
    //make first responder
    // calling this without a timeout sometimes fails :/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        
        //set first responder
        [self.window makeFirstResponder:self.installButton];
        
    });

    return;
}

//configure window/buttons
// also brings window to front
-(void)configure:(BOOL)isInstalled
{
    //init status msg
    [self.statusMsg setStringValue:@"evil maids: stay out! 🙅‍♀️🚪"];
    
    //enable 'uninstall' button when app is installed already
    if(YES == isInstalled)
    {
        //enable
        self.uninstallButton.enabled = YES;
    }
    //otherwise disable
    else
    {
        //disable
        self.uninstallButton.enabled = NO;
    }
    
    //set delegate
    [self.window setDelegate:self];

    return;
}

//display (show) window
// center, make front, set bg to white, etc
-(void)display
{
    //center window
    [[self window] center];
    
    //show (now configured) windows
    [self showWindow:self];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];

    return;
}

//button handler for uninstall/install
-(IBAction)buttonHandler:(id)sender
{
    //action
    NSInteger action = 0;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"handling action click: %@", ((NSButton*)sender).title]);
    
    //grab tag
    action = ((NSButton*)sender).tag;
    
    //close?
    // close window to trigger exit logic
    if(action == ACTION_CLOSE_FLAG)
    {
        //close
        [self.window close];
    }

    //disable 'x' button
    // don't want user killing app during install/upgrade
    [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:NO];
    
    //clear status msg
    [self.statusMsg setStringValue:@""];
    
    //force redraw of status msg
    // sometime doesn't refresh (e.g. slow VM)
    [self.statusMsg setNeedsDisplay:YES];

    //invoke logic to install/uninstall
    // do in background so UI doesn't block
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        //install/uninstall
        [self lifeCycleEvent:action];
    });
   
    return;
}

//button handler for '?' button (on an error)
// load objective-see's documentation for error(s) in default browser
-(IBAction)info:(id)sender
{
    #pragma unused(sender)
    
    //url
    NSURL *helpURL = nil;
    
    //build help URL
    helpURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@#errors", PRODUCT_URL]];
    
    //open URL
    // invokes user's default browser
    [[NSWorkspace sharedWorkspace] openURL:helpURL];
    
    return;
}

//perform install | uninstall via Control obj
// invoked on background thread so that UI doesn't block
-(void)lifeCycleEvent:(NSInteger)event
{
    //status var
    BOOL status = NO;
    
    //begin event
    // updates ui on main thread
    dispatch_sync(dispatch_get_main_queue(),
    ^{
        //complete
        [self beginEvent:event];
    });
    
    //sleep
    // allow 'install' || 'uninstall' msg to show up
    [NSThread sleepForTimeInterval:0.5];
  
    //perform action (install | uninstall)
    // perform background actions
    if(YES == [((AppDelegate*)[[NSApplication sharedApplication] delegate]).configureObj configure:event])
    {
        //set flag
        status = YES;
    }
    
    //error occurred
    else
    {
        //set flag
        status = NO;
    }
    
    //complet event
    // updates ui on main thread
    dispatch_async(dispatch_get_main_queue(),
    ^{
        //complete
        [self completeEvent:status event:event];
    });
    
    return;
}

//begin event
// basically just update UI
-(void)beginEvent:(NSInteger)event
{
    //status msg frame
    CGRect statusMsgFrame = {{0,0}, {0,0}};
    
    //grab exiting frame
    statusMsgFrame = self.statusMsg.frame;
    
    //avoid activity indicator
    // shift frame shift delta
    statusMsgFrame.origin.x += FRAME_SHIFT;
    
    //update frame to align
    self.statusMsg.frame = statusMsgFrame;
    
    //align text left
    [self.statusMsg setAlignment:NSTextAlignmentLeft];
    
    //install msg
    if(ACTION_INSTALL_FLAG == event)
    {
        //update status msg
        [self.statusMsg setStringValue:@"Installing..."];
    }
    //uninstall msg
    else
    {
        //update status msg
        [self.statusMsg setStringValue:@"Uninstalling..."];
    }
    
    //disable action button
    self.uninstallButton.enabled = NO;
    
    //disable cancel button
    self.installButton.enabled = NO;
    
    //show spinner
    self.activityIndicator.hidden = NO;
    
    //start spinner
    [self.activityIndicator startAnimation:nil];
    
    return;
}

//complete event
// update UI after background event has finished
-(void)completeEvent:(BOOL)success event:(NSInteger)event
{
    //status msg frame
    CGRect statusMsgFrame = {{0,0}, {0,0}};
    
    //action
    NSString* action = nil;
    
    //result msg
    NSMutableString* resultMsg = nil;
    
    //msg font
    NSColor* resultMsgColor = nil;
    
    //generally want centered text
    [self.statusMsg setAlignment:NSTextAlignmentCenter];
    
    //set action msg for install
    if(ACTION_INSTALL_FLAG == event)
    {
        //set msg
        action = @"install";
    }
    //set action msg for uninstall
    else
    {
        //set msg
        action = @"uninstall";
    }
    
    //success
    if(YES == success)
    {
        //set result msg
        resultMsg = [NSMutableString stringWithFormat:@"Do Not Disturb %@ed!", action];
        
        //set font to black
        resultMsgColor = [NSColor blackColor];
    }
    //failure
    else
    {
        //set result msg
        resultMsg = [NSMutableString stringWithFormat:@"error: %@ failed", action];
        
        //set font to red
        resultMsgColor = [NSColor redColor];
        
        //show 'get more info' button
        self.moreInfoButton.hidden = NO;
    }
    
    //stop/hide spinner
    [self.activityIndicator stopAnimation:nil];
    
    //hide spinner
    self.activityIndicator.hidden = YES;
    
    //grab exiting frame
    statusMsgFrame = self.statusMsg.frame;
    
    //shift back since activity indicator is gone
    statusMsgFrame.origin.x -= FRAME_SHIFT;
    
    //update frame to align
    self.statusMsg.frame = statusMsgFrame;
    
    //set font to bold
    [self.statusMsg setFont:[NSFont fontWithName:@"Menlo-Bold" size:13]];
    
    //set msg color
    [self.statusMsg setTextColor:resultMsgColor];
    
    //set status msg
    [self.statusMsg setStringValue:resultMsg];
    
    //set button to close
    self.installButton.title = ACTION_CLOSE;
    
    //update it's tag
    // will allow button handler method to detect the close
    self.installButton.tag = -1;
    
    //enable
    self.installButton.enabled = YES;

    //...and highlighted
    [self.window makeFirstResponder:self.installButton];
   
    //ok to re-enable 'x' button
    [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:YES];
    
    //(re)make window window key
    [self.window makeKeyAndOrderFront:self];
    
    //(re)make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//automatically invoked when window is closing
// just exit application
-(void)windowWillClose:(NSNotification *)notification
{
    #pragma unused(notification)
    
    //exit
    [NSApp terminate:self];
    
    return;
}

@end
