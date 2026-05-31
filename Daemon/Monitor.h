//
//  Monitor.h
//  DoNotDisturb
//
//  Created by Patrick Wardle on 9/25/14.
//  Copyright (c) 2026 Objective-See. All rights reserved.
//

@import Foundation;

#import "XPCUserProto.h"
#import "XPCUserClient.h"

#import "Process.h"
#import "Telegram.h"
#import "utilities.h"
#import <bsm/libbsm.h>
#import <EndpointSecurity/EndpointSecurity.h>

@import OSLog;

@interface Monitor : NSObject
{
    //lid state
    LidState lidState;
    
    //dispatch queue
    dispatch_queue_t dispatchQ;
    
    //notification port
    IONotificationPortRef notificationPort;
    
    //notification object
    io_object_t notification;
    
    //monitoring active
    BOOL running;
    
    //persistent ES client for trusted auth monitoring
    es_client_t* esAuthClient;
}

/* PROPERTIES */

@property(nonatomic, retain)Telegram* telegram;
@property(nonatomic, retain)XPCUserClient* xpcUserClient;

//last trusted auth timestamp (set by persistent ES client)
@property(atomic, retain)NSDate* lastTrustedAuth;

/* METHODS */

-(void)stop;
-(BOOL)start;
-(BOOL)isExternalDisplayActive;
-(void)processEvent:(NSString*)timestamp;
-(BOOL)waitForTrustedAuth:(NSTimeInterval)timeout;

@end
