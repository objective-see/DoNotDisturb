//  file: DeviceTrigger.m
//  project: DND (launch daemon)
//  description: monitor and alert logic for device insertion events
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Triggers.h"
#import "Utilities.h"
#import "Preferences.h"
#import "DeviceTrigger.h"

/* GLOBALS */

//triggers object
extern Triggers* triggers;

//preferences obj
extern Preferences* preferences;

@implementation DeviceTrigger

@synthesize runLoopSource;
@synthesize notificationPort;

//callback for USB devices
void usbAppeared(void *refCon, io_iterator_t iterator)
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"usb device inserted"]);
    
    //process new device
    [(__bridge DeviceTrigger *)refCon handleNewDevice:iterator];
    
    return;
}

//toggle lid notifications
-(BOOL)toggle:(NSControlStateValue)state
{
    //flag
    BOOL wasToggled = NO;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"toggling devices notifications: %lu", state]);
    
    //on?
    // enable
    if(NSOnState == state)
    {
        //enable
        wasToggled = [self enable];
    }
    //off
    // disable
    else
    {
        //disable
        [self disable];
        
        //manually set flag
        wasToggled = YES;
    }
    
    return wasToggled;
}

//start USB monitoring
-(BOOL)enable
{
    //status
    BOOL initialized = NO;
    
    //status
    kern_return_t status = kIOReturnError;
    
    //iterator
    io_iterator_t iterator = 0;
    
    //device
    io_service_t device = 0;
    
    //create notification port
    self.notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
    
    //get run loop source
    self.runLoopSource = IONotificationPortGetRunLoopSource(self.notificationPort);
    
    //add source
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopDefaultMode);
    
    //add notification
    // pass in 'self' so can access obj-c methods in callbacks
    status = IOServiceAddMatchingNotification(self.notificationPort, kIOMatchedNotification, IOServiceMatching(kIOUSBDeviceClassName), usbAppeared,(__bridge void *)self, &iterator);
    if(kIOReturnSuccess != status)
    {
        //err
        logMsg(LOG_ERR, [NSString stringWithFormat:@"IOServiceAddMatchingNotification() failed with %d", status]);
        
        //bail
        goto bail;
    }
    
    //process existing devices
    // also 'drains' interator...
    device = IOIteratorNext(iterator);
    while(0 != device)
    {
        //record device name/properties
        //[self logDeviceProperties:device];
        
        //release
        IOObjectRelease(device);
        
        //get next
        device = IOIteratorNext(iterator);
    }
    
    //happy
    initialized = YES;
    
bail:
    
    return initialized;
}

//stop
// invalidate runloop src and notification port
-(void)disable
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

//process new USB insertion
// get info about device and log
-(void)handleNewDevice:(io_iterator_t)iterator
{
    //usb device
    io_service_t device;
    
    //device name
    io_name_t deviceName = {0};
    
    //timestamp
    NSDate* timestamp = nil;
    
    //process
    while((device = IOIteratorNext(iterator)))
    {
        //reset
        bzero(deviceName, sizeof(io_name_t));
        
        //init timestamp
        timestamp = [NSDate date];
        
        //get device name
        if(KERN_SUCCESS != IORegistryEntryGetName(device, deviceName))
        {
            //err msg
            logMsg(LOG_ERR, @"failed to get usb device name");
            
            //set to unknown
            strncpy(deviceName, "<unknown>", sizeof(io_name_t)-1);
        }
        
        //dbg msg
        // log to file
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"[NEW EVENT] usb inserted: \"%s\"", deviceName]);
        
        //process event
        // report to user, server, execute actions, etc.
        [triggers processEvent:DEVICE_TRIGGER info:@{KEY_DEVICE_NAME:[NSString stringWithUTF8String:deviceName]}];
    
        //release device
        IOObjectRelease(device);
        
        //unset
        device = 0;
    }
    
    return;
}

//log name/properties of a device
-(void)logDeviceProperties:(io_service_t)device
{
    //device name
    io_name_t deviceName = {0};
    
    //device properties
    CFMutableDictionaryRef deviceProperties = NULL;
    
    //get device name
    if(KERN_SUCCESS == IORegistryEntryGetName(device, deviceName))
    {
        //dbg msg & log
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"usb device name: %s", deviceName]);
    }
    
    //get device properties
    if( (kIOReturnSuccess == IORegistryEntryCreateCFProperties(device, &deviceProperties, kCFAllocatorDefault, kNilOptions)) &&
       (NULL != deviceProperties) )
    {
        //dbg msg & log
        logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"usb device properties: %@", deviceProperties]);
    }
    
    //release device props
    if(NULL != deviceProperties)
    {
        //release
        CFRelease(deviceProperties);
        
        //unset
        deviceProperties = NULL;
    }
    
    return;
}

@end
