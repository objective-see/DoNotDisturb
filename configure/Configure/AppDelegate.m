
@import Sentry;

#import "Consts.h"
#import "Logging.h"
#import "Configure.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "HelperComms.h"

#import <syslog.h>
#import <Security/Authorization.h>
#import <ServiceManagement/ServiceManagement.h>

@implementation AppDelegate

@synthesize gotHelp;
@synthesize xpcComms;
@synthesize statusMsg;
@synthesize configureObj;

@synthesize aboutWindowController;
@synthesize errorWindowController;
@synthesize configureWindowController;

//main app interface
-(void)applicationDidFinishLaunching:(NSNotification *)notification
{
    #pragma unused(notification)
    
    //init crash reporting client
    SentryClient.sharedClient = [[SentryClient alloc] initWithDsn:CRASH_REPORTING_URL didFailWithError:nil];
    
    //start crash handler
    [SentryClient.sharedClient startCrashHandlerWithError:nil];
    
    //make sure system is supported (lid)
    // if not, will inform user via alert
    if(YES != [self isSupported])
    {
        //dbg msg
        logMsg(LOG_ERR, @"device doesn't appear to have a lid (i.e. is unsupported)");
        
        //exit
        [NSApp terminate:self];
    }
    
    //alloc/init Config obj
    configureObj = [[Configure alloc] init];
    
    //show config window
    [self displayConfigureWindow:[self.configureObj isInstalled]];
    
    return;
}

//check if there's a lid
// if not, alert to tell user
-(BOOL)isSupported
{
    //flag
    BOOL supported = NO;
    
    //alert
    NSAlert* alert =  nil;
    
    //no lid
    // can't support!
    if(stateUnavailable == getLidState())
    {
        //init alert
        alert = [[NSAlert alloc] init];
        
        //set main text
        alert.messageText = @"Unsupported Device";
        
        //set informative text
        alert.informativeText = [NSString stringWithFormat:@"'%@' does not appear to be a laptop", [[NSHost currentHost] localizedName]];
        
        //add button
        [alert addButtonWithTitle:@"Ok"];
        
        //set style
        alert.alertStyle = NSAlertStyleWarning;
        
        //show it
        [alert runModal];
        
        //bail
        goto bail;
    }
    
    //happy
    supported = YES;
    
bail:
    
    return supported;
    
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

//display error window
-(void)displayErrorWindow:(NSDictionary*)errorInfo
{
    //alloc error window
    errorWindowController = [[ErrorWindowController alloc] initWithWindowNibName:@"ErrorWindowController"];
    
    //main thread
    // just show UI alert, unless its fatal (then load URL)
    if(YES == [NSThread isMainThread])
    {
        //non-fatal errors
        // show error error popup
        if(YES != [errorInfo[KEY_ERROR_URL] isEqualToString:FATAL_ERROR_URL])
        {
            //display it
            // call this first to so that outlets are connected
            [self.errorWindowController display];
            
            //configure it
            [self.errorWindowController configure:errorInfo];
        }
        //fatal error
        // launch browser to go to fatal error page, then exit
        else
        {
            //launch browser
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:errorInfo[KEY_ERROR_URL]]];
            
            //then exit
            [NSApp terminate:self];
        }
    }
    //background thread
    // have to show error window on main thread
    else
    {
        //show alert
        // in main UI thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            
            //display it
            // call this first to so that outlets are connected
            [self.errorWindowController display];
            
            //configure it
            [self.errorWindowController configure:errorInfo];
            
        });
    }
    
    return;
}

//menu handler for 'about'
- (IBAction)displayAboutWindow:(id)sender
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
