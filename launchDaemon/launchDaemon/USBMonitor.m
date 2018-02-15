//
//  Monitor.m
//  
//
//  Created by user on 12/9/17.
//

#import <IOKit/usb/IOUSBLib.h>

#import "Consts.h"
#import "Logging.h"
#import "USBMonitor.h"

@implementation USBMonitor

@synthesize runLoopSource;
@synthesize notificationPort;

//callback for USB devices
void usbDeviceAppeared(void *refCon, io_iterator_t iterator)
{
    //TODO: get name?
    
    //dbg msg & log
    logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"monitor event: usb device inserted"]);
    
    //TODO: if not, need, clean up code below too
    // log or do something with this event
    //Monitor *monitor = (__bridge Monitor *)refCon;
    
    return;
}

//start USB monitoring
-(BOOL)start
{
    //status
    BOOL initialized = NO;
    
    //status
    kern_return_t status = kIOReturnError;

    //iterator
    io_iterator_t iterator = 0;
    
    //create notification port
    self.notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
    
    //get run loop source
    self.runLoopSource = IONotificationPortGetRunLoopSource(self.notificationPort);
    
    //add source
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopDefaultMode);
    
    //add notification
    // pass in 'self' so can access obj-c methods in callbacks
    status = IOServiceAddMatchingNotification(self.notificationPort, kIOMatchedNotification, IOServiceMatching(kIOUSBDeviceClassName), usbDeviceAppeared,(__bridge void *)self, &iterator);
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

//stop
// invalidate runloop src and notification port
-(void)stop
{
    //invalidate runloop src
    if(nil != self.runLoopSource)
    {
        //invalidate
        CFRunLoopSourceInvalidate(self.runLoopSource);
        
        //unset
        self.runLoopSource = nil;
    }
 
    //destroy notification port
    if(nil != self.notificationPort)
    {
        //destroy
        IONotificationPortDestroy(self.notificationPort);
        
        //unset
        self.notificationPort = nil;
    }

    return;
}

//init notification handler for auth events
// user auth monitor will broadcast such events!
-(void)initAuthMonitoring
{
    //register listener for notification events
    // on event; just log to the log file for now...
    [[NSNotificationCenter defaultCenter] addObserverForName:AUTH_NOTIFICATION object:nil queue:[NSOperationQueue mainQueue]
    usingBlock:^(NSNotification *notification)
    {
        //dbg msg & log
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"monitor event: user authentication %@", notification.userInfo[AUTH_NOTIFICATION]]);
        
    }];
    
    return;
}
@end
