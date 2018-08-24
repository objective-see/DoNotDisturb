//
//  file: LidTrigger.h
//  project: DND (launch daemon)
//  description: monitor and alert logic for lid open events (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Utilities.h"

@import Foundation;

#import <IOKit/IOKitLib.h>
#import <IOKit/pwr_mgt/IOPM.h>


/* CLASS INTERFACE */

@interface LidTrigger : NSObject
{
    
}

/* PROPERTIES */

//lid state
@property LidState lidState;

//dispatch queue
@property dispatch_queue_t dispatchQ;

//notification port
@property IONotificationPortRef notificationPort;

//notification object
@property io_object_t notification;

/* METHODS */

//register for notifications
-(BOOL)toggle:(NSControlStateValue)state;

@end
