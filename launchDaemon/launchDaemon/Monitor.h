//
//  Monitor.h
//  
//
//  Created by user on 12/9/17.
//

#import <Foundation/Foundation.h>

@interface Monitor : NSObject

/* METHODS */

//initialize USB monitoring
-(BOOL)initUSBMonitoring;

//callback for USB devices
void usbDeviceAppeared(void *refCon, io_iterator_t iterator);

@end
