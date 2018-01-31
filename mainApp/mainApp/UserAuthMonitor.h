//
//  userAuthMonitor.h
//  mainApp
//
//  Created by Patrick Wardle on 1/29/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UserAuthMonitor : NSObject

/* PROPERTIES */

//time of last event
@property(nonatomic, retain)NSDate* lastEvent;

//flag for touchID events
@property BOOL wasTouchID;

//current console user
@property(nonatomic, retain)NSString* consoleUser;

/* METHODS */

//thread function
// setup login / lockscreen monitoring
-(void)monitor;

//determine if event was triggered by touchID
// basically dump OS log and look for touch ID event
-(BOOL)wasTouchIDEvent;

@end
