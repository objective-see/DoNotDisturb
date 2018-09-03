//
//  file: XPCDaemonProtocol.h
//  project: DND (shared)
//  description: methods exported by the daemon
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

@protocol XPCDaemonProtocol

//process qrc request from client
-(void)qrcRequest:(void (^)(NSData *))reply;

//wait for phone to complete registration
// calls into framework that comms w/ server to wait for phone
-(void)recvRegistrationACK:(void (^)(NSDictionary* registrationInfo))reply;

//get preferences
-(void)getPreferences:(NSString*)preference reply:(void (^)(NSDictionary* preferences))reply;

//update preferences
-(void)updatePreferences:(NSDictionary*)preferences;

@end

