//
//  Monitor.h
//  launchDaemon
//
//  Created by Patrick Wardle on 2/13/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "USBMonitor.h"
#import "ProcListener.h"
#import "DownloadMonitor.h"
#import "UserAuthMonitor.h"
#import "ThunderboltMonitor.h"

#import <Foundation/Foundation.h>

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

/* METHODS */

//start all monitoring
// processes, auth events, hardware insertions, etc
-(BOOL)start:(NSUInteger)timeout;

//stop all monitoring
-(void)stop;

@end
