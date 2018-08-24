//  file: Triggers.m
//  project: DND (launch daemon)
//  description: generic management of various triggers (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Utilities.h"
#import "LidTrigger.h"
#import "PowerTrigger.h"
#import "DeviceTrigger.h"
#import <dnd/dnd-Swift.h>

@import Foundation;

/* FUNCTIONS */

//check if user auth'd
// a) within last 10 seconds
// b) via biometrics (touchID)
BOOL authViaTouchID(void);

/* CLASS INTERFACE */

@interface Triggers : NSObject <DNDClientMacDelegate>
{
    
}

/* PROPERTIES */

//lid trigger obj
@property(nonatomic, retain)LidTrigger* lidTrigger;

//device(s) trigger obj
@property(nonatomic, retain)DeviceTrigger* deviceTrigger;

//power trigger obj
@property(nonatomic, retain)PowerTrigger* powerTrigger;


//client
@property(nonatomic, retain)DNDClientMac* client;

//dismiss dispatch group
@property(nonatomic, retain)dispatch_group_t dispatchGroup;

//dispatch group flag
@property BOOL dispatchGroupEmpty;

//dispatch blocks
@property(nonatomic, retain)NSMutableArray* dispatchBlocks;

//TODO: make dictionary w/ alert
//latest undeliveried alert
@property(nonatomic, retain)NSDate* undeliveredAlert;

/* METHODS */

//toggle trigger(s)
-(void)toggle:(NSUInteger)type state:(NSControlStateValue)state;

//check if client should be init'd
-(BOOL)shouldInitClient;

//init dnd client
-(BOOL)clientInit;

//cancel all dipatch blocks
-(void)cancelDispatchBlocks;

//process trigger event
-(void)processEvent:(NSUInteger)type info:(NSDictionary*)info;

//wait for dismiss
// note: handles multiple client via dispatch group
-(void)wait4Dismiss;

//execute action
-(int)executeAction:(NSString*)path user:(NSString*)user;

@end
