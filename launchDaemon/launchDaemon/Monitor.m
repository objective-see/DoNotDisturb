//
//  Monitor.m
//  
//
//  Created by user on 12/9/17.
//

#import <IOKit/usb/IOUSBLib.h>

#import "Logging.h"
#import "Monitor.h"

@implementation Monitor

//callback for USB devices
void usbDeviceAppeared(void *refCon, io_iterator_t iterator)
{
    //dbg msg
    logMsg(LOG_DEBUG, @"usb device detected");
    
    //TODO:
    // log or do something with this event
    //Monitor *monitor = (__bridge Monitor *)refCon;
    
    return;
}

//initialize USB monitoring
-(BOOL)initUSBMonitoring
{
    //status
    BOOL initialized = NO;
    
    //status
    kern_return_t status = kIOReturnError;
    
    //notification port
    IONotificationPortRef notificationPort = 0;
    
    //run loop source
    CFRunLoopSourceRef runLoopSource = 0;
    
    //iterator
    io_iterator_t iterator = 0;
    
    //create notification port
    notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
    
    //get run loop source
    runLoopSource = IONotificationPortGetRunLoopSource(notificationPort);
    
    //add source
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopDefaultMode);
    
    //add notification
    // pass in 'self' so can access obj-c methods in callbacks
    status = IOServiceAddMatchingNotification(notificationPort, kIOMatchedNotification, IOServiceMatching(kIOUSBDeviceClassName), usbDeviceAppeared,(__bridge void *)self, &iterator);
    if(kIOReturnSuccess != status)
    {
        //err
        logMsg(LOG_ERR, [NSString stringWithFormat:@"IOServiceAddMatchingNotification() failed with %d", status]);
        
        //bail
        goto bail;
    }
    
    //drain iterator
    while(IOIteratorNext(iterator)) {};
    
    //happy
    initialized = YES;
    
bail:
    
    return initialized;
}

@end
