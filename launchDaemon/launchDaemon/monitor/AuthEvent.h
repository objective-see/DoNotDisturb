//
//  AuthEvent.h
//  launchDaemon
//
//  Created by Patrick Wardle on 2/7/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AuthEvent : NSObject

/* PROPERTIES */

//type
// used by audit
@property u_int16_t type;

//process did auth
@property pid_t pid;

//uid
@property uid_t uid;

//text from audit event
@property(nonatomic, retain)NSString* text;

//auth result
@property(nonatomic) u_int32_t result;

//flag for touch ID events
@property(nonatomic) BOOL wasTouchID;

//timestamp
@property(nonatomic, retain)NSDate* timestamp;

@end
