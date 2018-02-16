//
//  file: DaemonComms.h
//  project: DnD (shared)
//  description: talk to daemon (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Foundation;

#import "UserCommsInterface.h"

@interface DaemonComms : NSObject

//remote deamon proxy object
@property(nonatomic, retain) id <UserProtocol> daemon;

//xpc connection
@property (atomic, strong, readwrite) NSXPCConnection* xpcServiceConnection;

//ask daemon for QRC info
// name, uuid, key, key size, etc...
-(void)qrcRequest:(void (^)(NSString* qrcInfo))reply;

//wait for phone to complete registration
// calls into framework that comms w/ server to wait for phone
-(void)recvRegistrationACK:(void (^)(NSDictionary* registrationInfo))reply;

//update (save) preferences
-(void)updatePreferences:(NSDictionary*)preferences;

//ask for alert
-(void)alertRequest:(void (^)(NSDictionary* alert))reply;

//send alert response back to the daemon
// for now, it's just an 'ack' that it was recieved/shown
-(void)alertResponse;

//ask (and then block) for an alert dismiss
-(void)alertDismiss:(void (^)(NSDictionary* alert))reply;

//close/cleanup connection
-(void)close;

@end
