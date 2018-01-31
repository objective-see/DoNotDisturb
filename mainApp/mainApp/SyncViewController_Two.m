//
//  SyncViewController_One.m
//  mainApp
//
//  Created by Patrick Wardle on 1/23/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "AppDelegate.h"
#import "DaemonComms.h"
#import "QuickResponseCode.h"
#import "SyncViewController_Two.h"

#import <CoreImage/CoreImage.h>

@interface SyncViewController_Two ()

@end

@implementation SyncViewController_Two

-(void)viewDidLoad {
    
    //qrc object
    QuickResponseCode* qrcObj = nil;
    
    //daemon comms obj
    __block DaemonComms* daemonComms = nil;
    
    //size
    CGSize qrcSize = {0};
    
    //super
    [super viewDidLoad];
    
    //alloc qrc
    qrcObj = [[QuickResponseCode alloc] init];

    //show spinnner
    [self.activityIndicator startAnimation:nil];
    
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
            [NSThread sleepForTimeInterval:3.0f];
            
            //switch to final view
            // on main thread since it's UI-related
            dispatch_sync(dispatch_get_main_queue(), ^{
                
                //switch view
                [((AppDelegate*)[[NSApplication sharedApplication] delegate]).linkWindowController switchView:SYNC_VIEW_THREE parameters:registrationInfo];
                
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
    self.activityMsg.hidden = YES;
    
    //set image
    self.qrcImageView.image = qrcImage;
    
    //show
    self.qrcImageView.hidden = NO;
    
    return;
}
@end
