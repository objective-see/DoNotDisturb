//
//  file: UserCommsInterface.h
//  project: DnD (shared)
//  description: protocol for talking to the daemon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef UserCommsInterface_h
#define UserCommsInterface_h

@import Foundation;

@protocol UserProtocol

//process qrc request from client
-(void)qrcRequest:(void (^)(NSData *))reply;

//wait for phone to complete registration
// calls into framework that comms w/ server to wait for phone
-(void)recvRegistrationACK:(void (^)(NSDictionary* registrationInfo))reply;

//get preferences
-(void)getPreferences:(void (^)(NSDictionary* preferences))reply;

//update preferences
-(void)updatePreferences:(NSDictionary*)preferences;

//ask (and block) alert request from daemon
-(void)alertRequest:(void (^)(NSDictionary* alert))reply;

//process alert response from client
-(void)alertResponse;

//ask (and block) for alert dismiss msg from daemon
-(void)alertDismiss:(void (^)(NSDictionary* alert))reply;

@end

#endif
