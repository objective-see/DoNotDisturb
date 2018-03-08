//
//  Monitor.h
//  
//
//  Created by user on 12/9/17.
//

#import <Foundation/Foundation.h>

@interface ThunderboltMonitor : NSObject

/* PROPERTIES */

//notification port
@property(nonatomic) IONotificationPortRef notificationPort;

//callback for tb devices
void tbDeviceAppeared(void *refCon, io_iterator_t iterator);

//run loop source
@property(nonatomic)CFRunLoopSourceRef runLoopSource;


/* METHODS */

//start
-(BOOL)start;

//stop
-(void)stop;

//process new tb insertion
// get info about device and log
-(void)handleNewDevice:(io_iterator_t)iterator;

@end
