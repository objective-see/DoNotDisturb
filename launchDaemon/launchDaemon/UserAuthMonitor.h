//
//  userAuthMonitor.h
//  mainApp
//
//  Created by Patrick Wardle on 1/29/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "AuthEvent.h"

#import <Foundation/Foundation.h>

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

//lastest successful auth event obj
@property(nonatomic, retain) AuthEvent* authEvent;

/* METHODS */

//thread function
// setup login / lockscreen monitoring
-(BOOL)start;

//stop
-(void)stop;

@end
