//
//  WelcomeWindowController.m
//  mainApp
//
//  Created by Patrick Wardle on 1/25/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
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
    if ([self.window respondsToSelector:@selector(titlebarAppearsTransparent)])
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
            
            break;
        }
            
        //app info
        case VIEW_APP_INFO:
        {
            //remove prev. subview
            [[[self.window.contentView subviews] lastObject] removeFromSuperview];
            
            //set view
            [self.window.contentView addSubview:self.appInfo];
            
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
            
        //qrc
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
    [qrcObj generateQRC:qrcSize reply:^(NSImage* qrcImage)
     {
         //nap to allow 'generating' msg to show up
         [NSThread sleepForTimeInterval:0.5f];
         
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
                 self.activityMessage.stringValue = @"Error generating QRC";
                 
             });
             
             return;
         }
         
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
              //switch to final view
              // on main thread since it's UI-related
              dispatch_sync(dispatch_get_main_queue(), ^{
                  
                  //remove prev. subview
                  [[[self.window.contentView subviews] lastObject] removeFromSuperview];
                  
                  //set view
                  [self.window.contentView addSubview:self.linkedView];
                  
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


/*

//switch (content) view
-(void)switchView:(NSUInteger)view parameters:(NSDictionary*)parameters
{
    switch(view)
    {
        //show 0st view
        case SYNC_VIEW_ZERO:
            
            //init sync view controller
            syncViewController = [[SyncViewController_Zero alloc] initWithNibName:@"SyncViewController_Zero" bundle:nil];
            
            break;
            
        //show 1st view
        case SYNC_VIEW_ONE:
            
            //init sync view controller
            syncViewController = [[SyncViewController_One alloc] initWithNibName:@"SyncViewController_One" bundle:nil];
            
            break;
            
        //show 2nd view
        case SYNC_VIEW_TWO:
            
            //init sync view controller
            syncViewController = [[SyncViewController_Two alloc] initWithNibName:@"SyncViewController_Two" bundle:nil];
        
            break;
            
        //show 3rd view
        case SYNC_VIEW_THREE:
            
            //init sync view controller
            syncViewController = [[SyncViewController_Three alloc] initWithNibName:@"SyncViewController_Three" bundle:nil];
            
            break;
            
        default:
            break;
    }
    
    //set params?
    // also make sure obj has 'parameters' property
    if( (nil != parameters) &&
        (nil != class_getProperty([self.syncViewController class], "parameters")) )
    {
        //set
        [self.syncViewController setValue:parameters forKey:@"parameters"];
    }

    //set it as content view
    self.window.contentView = [self.syncViewController view];
    
    return;
}
 
*/

@end
