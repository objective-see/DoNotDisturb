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

//run loop source
@property(nonatomic)CFRunLoopSourceRef runLoopSource;


/* METHODS */

//start
-(BOOL)start;

//stop
-(void)stop;

//callback for USB devices
void usbDeviceAppeared(void *refCon, io_iterator_t iterator);

@end
