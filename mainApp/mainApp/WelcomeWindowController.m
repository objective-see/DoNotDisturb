//
//  file: WelcomeWindowController.m
//  project: DND (main app)
//  description: 'welcome' window logic/controller
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "DaemonComms.h"
#import "QuickResponseCode.h"
#import "WelcomeWindowController.h"

#define VIEW_WELCOME 0
#define SELECT_TRIGGERS 1
#define VIEW_APP_INFO 2
#define SKIP_LINKING 3
#define VIEW_QRC 4
#define VIEW_LINKED 5

@implementation WelcomeWindowController

@synthesize welcomeViewController;

//window delegate method
// init ui stuff and show first view
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //center
    [self.window center];
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];
    
    //when supported
    // indicate title bar is transparent (too)
    if([self.window respondsToSelector:@selector(titlebarAppearsTransparent)])
    {
        //set transparency
        self.window.titlebarAppearsTransparent = YES;
    }
    
    //set title
    self.window.title = [NSString stringWithFormat:@"Do Not Disturb (v. %@)", getAppVersion()];
    
    //show first view
    [self buttonHandler:nil];

    return;
}

//button handler for all views
// show next view, sometimes, with view specific logic
-(IBAction)buttonHandler:(id)sender
{
    //set next view
    switch(((NSButton*)sender).tag)
    {
        //welcome
        case VIEW_WELCOME:
        {
            //remove prev. subview
            [[[self.window.contentView subviews] lastObject] removeFromSuperview];
            
            //set view
            [self.window.contentView addSubview:self.welcomeView];
            
            //make 'next' button first responder
            // calling this without a timeout sometimes fails :/
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                
                //set first responder
                [self.window makeFirstResponder:[self.welcomeView viewWithTag:SELECT_TRIGGERS]];
                
            });
            
            break;
        }
            
        //select triggers info
        case SELECT_TRIGGERS:
        {
            //remove prev. subview
            [[[self.window.contentView subviews] lastObject] removeFromSuperview];
            
            //no a laptop?
            // uncheck and disable laptop lid trigger
            if(stateUnavailable == getLidState())
            {
                //uncheck
                self.lidTrigger.state = NSOffState;
                
                //disable
                self.lidTrigger.enabled = NO;
            }
            
            //set view
            [self.window.contentView addSubview:self.triggerView];
            
            //make 'next' button first responder
            [self.window makeFirstResponder:[self.triggerView viewWithTag:VIEW_APP_INFO]];
            
            break;
        }
            
        //app info
        case VIEW_APP_INFO:
        {
            //save trigger prefs
            [self setTriggers];
            
            //dbg msg
            logMsg(LOG_DEBUG, @"saved triggers");
    
            //remove prev. subview
            [[[self.window.contentView subviews] lastObject] removeFromSuperview];
            
            //set view
            [self.window.contentView addSubview:self.appInfo];
            
            //make 'next' button first responder
            [self.window makeFirstResponder:[self.appInfo viewWithTag:VIEW_QRC]];
            
            break;
        }
        
        //skip
        case SKIP_LINKING:
        {
            //bye
            [NSApp terminate:self];
            
            break;
        }
            
        //qrc
        case VIEW_QRC:
        {
            //remove prev. subview
            [[[self.window.contentView subviews] lastObject] removeFromSuperview];
            
            //set view
            [self.window.contentView addSubview:self.qrcView];
            
            //generate/show
            [self generateQRC];
        
            break;
        }
            
        //linked view
        case VIEW_LINKED:
        {
            //exit
            [NSApp terminate:nil];
            
            break;
        }
    }
    
    return;
}

//get user's prefs for triggers
// then send them to daemon to save into prefs
-(void)setTriggers
{
    //daemon comms
    DaemonComms* daemonComms = nil;
    
    //alloc/init
    daemonComms = [[DaemonComms alloc] init];
    
    //dbg msg
    logMsg(LOG_DEBUG, @"setting trigger prefs");
    
    //send to daemon
    // will update preferences
    [daemonComms updatePreferences:@{PREF_LID_TRIGGER:[NSNumber numberWithInteger:self.lidTrigger.state],
                                     PREF_DEVICE_TRIGGER:[NSNumber numberWithInteger:self.deviceTrigger.state],
                                     PREF_POWER_TRIGGER:[NSNumber numberWithInteger:self.powerTrigger.state]}];
    
    return;
}

//generate a QRC
// calls into daemon and then displays
-(void)generateQRC
{
    //qrc object
    QuickResponseCode* qrcObj = nil;
    
    //daemon comms obj
    __block DaemonComms* daemonComms = nil;
    
    //size
    CGSize qrcSize = {0};
   
    //alloc qrc
    qrcObj = [[QuickResponseCode alloc] init];
    
    //show spinnner
    [self.activityIndicator startAnimation:nil];
    
    //grab size while still on main thread
    qrcSize = self.qrcImageView.frame.size;
    
    //generate QRC
    // block will be executed when method returns
    [qrcObj generateQRC:qrcSize.height reply:^(NSImage* qrcImage)
    {
        //sanity check
        if(nil == qrcImage)
        {
             //show error msg on main thread
             dispatch_async(dispatch_get_main_queue(), ^{
                 
                 //stop/hide spinner
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
        dispatch_sync(dispatch_get_main_queue(), ^{
             
             //display QRC
             [self displayQRC:qrcImage];
             
        });
        
        //dbg msg
        logMsg(LOG_DEBUG, @"displayed QRC...now waiting for user to scan, then server to register and ack");
         
        //init daemon comms
        // will connect, etc.
        daemonComms = [[DaemonComms alloc] init];
         
        //call into daemon/framework
        // this will block until phone linking/registration is complete
        [daemonComms recvRegistrationACK:^(NSDictionary* registrationInfo)
        {
             //dbg msg
             logMsg(LOG_DEBUG, [NSString stringWithFormat:@"received registration ack/info from server/daemon: %@", registrationInfo]);
             
             //switch to final view
             // on main thread since it's UI-related
             dispatch_sync(dispatch_get_main_queue(),
             ^{
                 //set computer (host) name
                 if(nil != registrationInfo[KEY_HOST_NAME])
                 {
                     //set
                    self.hostName.stringValue = registrationInfo[KEY_HOST_NAME];
                 }
                 
                 //set device name
                 if(nil != registrationInfo[KEY_DEVICE_NAME])
                 {
                     //set
                     self.deviceName.stringValue = registrationInfo[KEY_DEVICE_NAME];
                 }
                 
                 //remove prev. subview
                 [[[self.window.contentView subviews] lastObject] removeFromSuperview];

                 //set view
                 [self.window.contentView addSubview:self.linkedView];
                 
                 //make 'done' button first responder
                 [self.window makeFirstResponder:[self.linkedView viewWithTag:VIEW_LINKED]];
                 
             });
             
        }];
         
     }];
    
    return;
}

//display QRC code
-(void)displayQRC:(NSImage*)qrcImage
{
    //stop/hide spinner
    [self.activityIndicator stopAnimation:nil];
    
    //hide message
    self.activityMessage.hidden = YES;
    
    //set image
    self.qrcImageView.image = qrcImage;
    
    //show
    self.qrcImageView.hidden = NO;
    
    return;
}

//open link to app in browser
-(IBAction)downloadApp:(id)sender
{
    //open URL
    // invokes user's default browser
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:IOS_APP_URL]];
    
    return;
}

@end
