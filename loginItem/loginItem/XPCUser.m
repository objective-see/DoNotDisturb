//
//  file: XPCUser.m
//  project: DND (login item)
//  description: user XPC methods
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Camera.h"
#import "Consts.h"
#import "Logging.h"
#import "XPCUser.h"
#import "AppDelegate.h"

@implementation XPCUser

//show an alert
-(void)alertShow:(NSDictionary*)alert
{
    //notification
    NSUserNotification* notification = nil;
    
    //formatter
    NSDateFormatter* dateFormat = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request from daemon: alert show");
    
    //alloc notification
    notification = [[NSUserNotification alloc] init];
    
    //alloc formatter
    dateFormat = [[NSDateFormatter alloc] init];
    
    //set date format
    [dateFormat setDateFormat:@"MM/dd/yyyy HH:mm:ss"];
    
    //set other button title
    notification.otherButtonTitle = @"Dismiss";
    
    //remove action button
    notification.hasActionButton = NO;
    
    //set title
    notification.title = @"⚠️ Do Not Disturb Alert";
    
    //set subtitle
    notification.subtitle = [NSString stringWithFormat:@"Lid Opened: %@", [dateFormat stringFromDate:alert[ALERT_TIMESTAMP]]];
    
    //set delegate to self
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    
    //show alert on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        
        //deliver notification
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
        
        //init/show touch bar
        [((AppDelegate*)[[NSApplication sharedApplication] delegate]) initTouchBar];
       
    });
    
    return;
}

//dismiss alert(s)
-(void)alertDismiss
{
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request from daemon: alert dismiss");
    
    //dismiss alerts on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        
        //clear (all) notification(s)
        [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
        
        //set app delegate's touch bar to nil
        // will hide/unset the touch bar alert....
        ((AppDelegate*)[[NSApplication sharedApplication] delegate]).touchBar = nil;
        
    });
    
    return;
}

//XPC method
// capture an image from the webcam
-(void)captureImage:(void (^)(NSData *))reply
{
    //image data
    NSData* image = nil;
    
    //camera obj
    Camera* camera = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"XPC request from daemon: capture picture");
    
    //init camera
    camera = [[Camera alloc] init];
    
    //grab image
    image = [camera captureImage];

    //get current prefs
    reply(image);
    
    return;
}

//'NSUserNotificationCenterDelegate' delegate method
// tell system to always present (show) the alert to user
-(BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

@end
