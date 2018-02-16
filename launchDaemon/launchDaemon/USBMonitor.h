//
//  Monitor.h
//  
//
//  Created by user on 12/9/17.
//

#import <Foundation/Foundation.h>

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
