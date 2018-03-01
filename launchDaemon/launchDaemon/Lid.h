//
//  Lid.h
//  launchDaemon
//
//  Created by user on 11/25/17.
//  Copyright © 2017 Objective-See. All rights reserved.
//

#import <dnd/dnd-Swift.h>

#import <IOKit/IOKitLib.h>
#import <IOKit/pwr_mgt/IOPM.h>
#import <Foundation/Foundation.h>



//enum of lid states
typedef NS_ENUM(int, LidState) {
    stateUnavailable = -1,
    stateOpen = 0,
    stateClosed = 1
};

/* FUNCTIONS */

//check if user auth'd
// a) within last 5 seconds
// b) via biometrics (touchID)
BOOL authViaTouchID(void);

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

/* METHODS */

//get state
-(int)getState;

//register for notifications
-(BOOL)register4Notifications;

//proces lid open event
-(void)processEvent;

@end
