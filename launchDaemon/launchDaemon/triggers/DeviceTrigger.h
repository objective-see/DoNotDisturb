//
//  file: DeviceTrigger.h
//  project: DND (launch daemon)
//  description: monitor and alert logic for device insertion events (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;
@import Foundation;

#import <IOKit/usb/IOUSBLib.h>

/* CLASS INTERFACE */

@interface DeviceTrigger : NSObject
{
    
}

/* PROPERTIES */

//notification port
@property(nonatomic)IONotificationPortRef notificationPort;

//callback for USB devices
void usbAppeared(void *refCon, io_iterator_t iterator);

//run loop source
@property(nonatomic)CFRunLoopSourceRef runLoopSource;


/* METHODS */

//register for notifications
-(BOOL)toggle:(NSControlStateValue)state;

//process new USB insertion
// get info about device and log
-(void)handleNewDevice:(io_iterator_t)iterator;


@end
