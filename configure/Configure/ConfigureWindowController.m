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
@synthesize friendsView;

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
    //set title
    self.window.title = [NSString stringWithFormat:@"Do Not Disturb (v. %@)", getAppVersion()];
    
    //init status msg
    self.statusMsg.stringValue = @"evil maids: stay out! 🙅‍♀️🚪";
    
    //app already installed?
    // enable 'uninstall' button
    // change install button to say 'upgrade'
    if(YES == isInstalled)
    {
        //enable 'uninstall'
        self.uninstallButton.enabled = YES;
        
        //set to 'upgrade'
        self.installButton.title = ACTION_UPGRADE;
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
    
    //not in dark mode?
    // make window white
    if(YES != [[[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"] isEqualToString:@"Dark"])
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }

    return;
}

//button handler for uninstall/install
-(IBAction)buttonHandler:(id)sender
{
    //frame
    NSRect frame = {0};
    
    //action
    NSInteger action = 0;
    
    //grab action
    action = ((NSButton*)sender).tag;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"handling action click: %@ (tag: %ld)", ((NSButton*)sender).title, (long)action]);
    
    //handle various actions
    switch(action)
    {
        //close
        case ACTION_CLOSE_FLAG:
            [self.window close];
            break;
            
        //install/uninstall
        case ACTION_INSTALL_FLAG:
        case ACTION_UNINSTALL_FLAG:
        {
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
            
            break;
        }
        
        //next
        // show 'friends' view
        case ACTION_NEXT_FLAG:
        {
            //unset window title
            self.window.title = @"";
            
            //get main window's frame
            frame = self.window.contentView.frame;
            
            //set origin to 0/0
            frame.origin = CGPointZero;
            
            //increase y offset
            frame.origin.y += 5;
            
            //reduce height
            frame.size.height -= 5;
            
            //pre-req
            [self.friendsView setWantsLayer:YES];
            
            //update overlay to take up entire window
            self.friendsView.frame = frame;
            
            //set overlay's view color to white
            self.friendsView.layer.backgroundColor = [NSColor whiteColor].CGColor;
            
            //nap for UI purposes
            [NSThread sleepForTimeInterval:0.10f];
            
            //add to main window
            [self.window.contentView addSubview:self.friendsView];
            
            //show
            self.friendsView.hidden = NO;
        }
        
        default:
            break;
    }
    
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
    
    }
    //failure
    else
    {
        //set result msg
        resultMsg = [NSMutableString stringWithFormat:@"Error: %@ failed", action];
        
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
    
    //set button to 'next'
    self.installButton.title = ACTION_NEXT;
    
    //set tag to next
    self.installButton.tag = ACTION_NEXT_FLAG;
    
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
