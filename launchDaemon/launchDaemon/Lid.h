//
//  file: Lid.h
//  project: DND (launch daemon)
//  description: monitor and alert logic for lid open events (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Utilities.h"
#import <dnd/dnd-Swift.h>

@import Foundation;

#import <IOKit/IOKitLib.h>
#import <IOKit/pwr_mgt/IOPM.h>

/* FUNCTIONS */

//check if user auth'd
// a) within last 10 seconds
// b) via biometrics (touchID)
BOOL authViaTouchID(void);

/* CLASS INTERFACE */

@interface Lid : NSObject <DNDClientMacDelegate>
{
    //lid state
    LidState lidState;
    
    //dispatch queue
    dispatch_queue_t dispatchQ;
    
    //notification port
    IONotificationPortRef notificationPort;
    
    //notification object
    io_object_t notification;
    
}

/* PROPERTIES */

//client
@property(nonatomic, retain)DNDClientMac *client;

//dismiss dispatch group
@property(nonatomic, retain)dispatch_group_t dispatchGroup;

//dispatch group flag
@property BOOL dispatchGroupEmpty;

//dispatch blocks
@property(nonatomic, retain)NSMutableArray* dispatchBlocks;

//latest undeliveried alert
@property(nonatomic, retain)NSDate* undeliveredAlert;

/* METHODS */

//check if client should be init'd
-(BOOL)shouldInitClient;

//init dnd client
-(BOOL)clientInit;

//cancel all dipatch blocks
-(void)cancelDispatchBlocks;

//register for notifications
-(BOOL)register4Notifications;

//register for notifications
-(void)unregister4Notifications;

//proces lid open event
-(void)processEvent:(NSDate*)timestamp;

//execute action
-(int)executeAction:(NSString*)path user:(NSString*)user;

@end
