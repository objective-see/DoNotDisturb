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

#import <Foundation/Foundation.h>

@interface Monitor : NSObject

/* PROPERTIES */

//observer for user auths events
@property(nonatomic, retain)id userAuthObserver;

//process listener obj
@property(nonatomic, retain)ProcessMonitor* processMonitor;

//usb monitor
@property(nonatomic, retain)USBMonitor* usbMonitor;

//download monitor
@property(nonatomic, retain)DownloadMonitor* downloadMonitor;

//user auth events monitor
@property(nonatomic, retain)UserAuthMonitor* userAuthMonitor;

/* METHODS */

//start all monitoring
// processes, auth events, hardware insertions, etc
-(BOOL)start:(NSUInteger)timeout;

//stop all monitoring
-(void)stop;

@end
