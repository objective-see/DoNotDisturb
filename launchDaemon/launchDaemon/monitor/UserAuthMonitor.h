//
//  file: UserAuthEvent.h
//  project: DND (launch daemon)
//  description: user authentication event monitor (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "AuthEvent.h"

@import Foundation;

/* DEFINES */

//audit pipe
#define AUDIT_PIPE "/dev/auditpipe"

//audit class for login/logout
#define AUDIT_CLASS_LO 0x00001000

//audit class for authen/author
#define AUDIT_CLASS_AA 0x00002000

//auth user
// see: /etc/security/audit_event
#define AUE_auth_user 45023

@interface UserAuthMonitor : NSObject

/* PROPERTIES */

//flag to stop
@property(nonatomic)BOOL shouldStop;

/* METHODS */

//thread function
// setup login / lockscreen monitoring
-(BOOL)start;

//stop
-(void)stop;

@end
