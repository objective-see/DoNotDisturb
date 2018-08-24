//
//  file: AppDelegate.m
//  project: DND (config)
//  description: application delegate
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Sentry;

#import "Consts.h"
#import "Logging.h"
#import "Configure.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "HelperComms.h"

#import <Security/Authorization.h>
#import <ServiceManagement/ServiceManagement.h>

@implementation AppDelegate

@synthesize gotHelp;
@synthesize xpcComms;
@synthesize statusMsg;
@synthesize configureObj;

@synthesize aboutWindowController;
@synthesize configureWindowController;

//main app interface
-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
    #pragma unused(notification)
    
    //init crash reporting client
    SentryClient.sharedClient = [[SentryClient alloc] initWithDsn:CRASH_REPORTING_URL didFailWithError:nil];
    
    //start crash handler
    [SentryClient.sharedClient startCrashHandlerWithError:nil];
    
    //alloc/init Config obj
    configureObj = [[Configure alloc] init];
    
    //show config window
    [self displayConfigureWindow:[self.configureObj isInstalled]];
    
    return;
}

//exit when last window is closed
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    #pragma unused(sender)
    
    return YES;
}

//app termination handler
// tell helper to remove itself
-(void)applicationWillTerminate:(NSNotification *)notification
{
    #pragma unused(notification)
    
    //tell Config object we're going away
    // allows it to (possibly) uninstall the helper tool
    [self.configureObj removeHelper];
    
    return;
}

//display configuration window w/ 'install' || 'uninstall' button
-(void)displayConfigureWindow:(BOOL)isInstalled
{
    //alloc/init
    configureWindowController = [[ConfigureWindowController alloc] initWithWindowNibName:@"ConfigureWindowController"];
    
    //display it
    // call this first to so that outlets are connected
    [self.configureWindowController display];
    
    //configure it
    [self.configureWindowController configure:isInstalled];
    
    return;
}


//menu handler for 'about'
-(IBAction)displayAboutWindow:(id)sender
{
    #pragma unused(sender)
    
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

@end
