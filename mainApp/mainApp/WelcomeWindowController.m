//
//  WelcomeWindowController.m
//  mainApp
//
//  Created by Patrick Wardle on 1/25/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "DaemonComms.h"
#import "QuickResponseCode.h"
#import "WelcomeWindowController.h"

#define VIEW_WELCOME 0
#define VIEW_APP_INFO 1
#define SKIP_LINKING 2
#define VIEW_QRC 3
#define VIEW_LINKED 4

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
            
            //and 'next' button first responder
            [self.window makeFirstResponder:[self.welcomeView viewWithTag:VIEW_APP_INFO]];
            
            break;
        }
            
        //app info
        case VIEW_APP_INFO:
        {
            //remove prev. subview
            [[[self.window.contentView subviews] lastObject] removeFromSuperview];
            
            //set view
            [self.window.contentView addSubview:self.appInfo];
            
            //and 'next' button first responder
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
                 self.activityMessage.stringValue = @"Error generating QR code";
                 
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
                 
                //and 'done' button first responder
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

@end
