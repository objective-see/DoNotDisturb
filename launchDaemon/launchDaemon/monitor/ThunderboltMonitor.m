//
//  file: ThunderboltMonitor.m
//  project: DND (launch daemon)
//  description: thunderbolt device monitor
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import <IOKit/usb/IOUSBLib.h>

#import "Consts.h"
#import "Logging.h"
#import "ThunderboltMonitor.h"

@implementation ThunderboltMonitor

@synthesize runLoopSource;
@synthesize notificationPort;

//callback for USB devices
void tbDeviceAppeared(void *refCon, io_iterator_t iterator)
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"monitor event: usb device inserted"]);
    
    //process new device
    [(__bridge ThunderboltMonitor *)refCon handleNewDevice:iterator];

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
    status = IOServiceAddMatchingNotification(self.notificationPort, kIOMatchedNotification, IOServiceMatching("IOPCIDevice"), tbDeviceAppeared,(__bridge void *)self, &iterator);
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

//process new thunerbolt (PCI) insertion
// get info about device (name/properties) and log
-(void)handleNewDevice:(io_iterator_t)iterator
{
    //usb device
    io_service_t device;
    
    //device name
    io_name_t deviceName = {0};
    
    //device properties
    CFMutableDictionaryRef deviceProperties = NULL;
    
    //process
    while((device = IOIteratorNext(iterator)))
    {
        //log msg
        logMsg(LOG_TO_FILE, [NSString stringWithFormat:@"monitor event: pci device inserted"]);
        
        //get device name
        if(KERN_SUCCESS == IORegistryEntryGetName(device, deviceName))
        {
            //dbg msg & log
            logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"pci device name: %s", deviceName]);
        }
        
        //get device properties
        if( (kIOReturnSuccess == IORegistryEntryCreateCFProperties(device, &deviceProperties, kCFAllocatorDefault, kNilOptions)) &&
            (NULL != deviceProperties) )
        {
            //dbg msg & log
            logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"pci device properties: %@", deviceProperties]);
        }
        
        //release device props
        if(NULL != deviceProperties)
        {
            //release
            CFRelease(deviceProperties);
            
            //unset
            deviceProperties = NULL;
        }
        
        //release device
        IOObjectRelease(device);
        
        //unset
        device = 0;
    }
    
    return;
}

@end
