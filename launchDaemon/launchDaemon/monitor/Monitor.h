//
//  file: Monitor.h
//  project: DND (launch daemon)
//  description: monitor all things (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "USBMonitor.h"
#import "ProcListener.h"
#import "VolumeMonitor.h"
#import "DownloadMonitor.h"
#import "UserAuthMonitor.h"
#import "ThunderboltMonitor.h"

@import Foundation;

@interface Monitor : NSObject

/* PROPERTIES */

//dimiss flag
@property BOOL wasDismissed;

//observer for user auths events
@property(nonatomic, retain)id userAuthObserver;

//observer for dimisss events
@property(nonatomic, retain)id dimisssObserver;

//process listener obj
@property(nonatomic, retain)ProcessMonitor* processMonitor;

//usb monitor
@property(nonatomic, retain)USBMonitor* usbMonitor;

//download monitor
@property(nonatomic, retain)DownloadMonitor* downloadMonitor;

//user auth events monitor
@property(nonatomic, retain)UserAuthMonitor* userAuthMonitor;

//thunderbolt monitor
@property(nonatomic, retain)ThunderboltMonitor* thunberboltMonitor;

//(mounted) volume monitor
@property(nonatomic, retain)VolumeMonitor* volumeMonitor;

/* METHODS */

//start all monitoring
// processes, auth events, hardware insertions, etc
-(BOOL)start:(NSUInteger)timeout;

//stop all monitoring
-(void)stop;

@end
