//
//  file: AuthEvent.h
//  project: DND (launch daemon)
//  description: user authentication event object (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

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
