//
//  file: XPCDaemonClient
//  project: DND (shared)
//  description: talk to the daemon, via XPC (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

#import "XPCDaemonProto.h"

@interface XPCDaemonClient : NSObject
{
    
}

/* PROPERTIES */

//remote deamon proxy object
@property(nonatomic, retain) id <XPCDaemonProtocol> daemon;

//xpc connection
@property (atomic, strong, readwrite) NSXPCConnection* xpcServiceConnection;

/* METHODS */

//ask daemon for QRC info
// name, uuid, key, key size, etc...
-(void)qrcRequest:(void (^)(NSData* qrcInfo))reply;

//wait for phone to complete registration
// calls into framework that comms w/ server to wait for phone
-(void)recvRegistrationACK:(void (^)(NSDictionary* registrationInfo))reply;

//get preferences
// note: synchronous
-(NSDictionary*)getPreferences:(NSString*)preference;

//update (save) preferences
-(void)updatePreferences:(NSDictionary*)preferences;

//close/cleanup connection
-(void)close;

@end
