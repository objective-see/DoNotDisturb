//
//  file: Power.m
//  project: DND (launch daemon)
//  description: monitor and alert logic for power events (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;
@import Foundation;

#import <IOKit/usb/IOUSBLib.h>

/* CLASS INTERFACE */

@interface PowerTrigger : NSObject
{
    
}

/* PROPERTIES */

//observer for screensaver off events
@property(nonatomic, retain)id screenSaverNotification;



/* METHODS */

//register for notifications
-(BOOL)toggle:(NSControlStateValue)state;


@end
