//
//  file: USBMonitor.h
//  project: DND (launch daemon)
//  description: USB device monitor (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;
#import <IOKit/usb/IOUSBLib.h>

@interface USBMonitor : NSObject

/* PROPERTIES */

//notification port
@property(nonatomic) IONotificationPortRef notificationPort;

//callback for USB devices
void usbDeviceAppeared(void *refCon, io_iterator_t iterator);

//run loop source
@property(nonatomic)CFRunLoopSourceRef runLoopSource;


/* METHODS */

//start
-(BOOL)start;

//stop
-(void)stop;

//process new USB insertion
// get info about device and log
-(void)handleNewDevice:(io_iterator_t)iterator;

@end
