//
//  file: AlertMonitor.h
//  project: DND (login item)
//  description: monitor for alerts from daemon (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

@interface AlertMonitor : NSObject <NSUserNotificationCenterDelegate>

/* PROPERTIES */
@property(nonatomic, retain)NSDate* lastAlert;

/* METHODS */

//forever,
// wait for & display alerts
-(void)monitor;

//forever
// wait for dismiss XPC msg from dameon
// note: currently, will dismiss all alerts...
-(void)dismissAlerts;

@end
