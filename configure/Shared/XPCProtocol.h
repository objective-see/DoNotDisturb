//
//  file: userCommsInterface.h
//  project: DND (shared)
//  description: protocol for talking to the daemon
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#ifndef userCommsInterface_h
#define userCommsInterface_h

@import Foundation;

@protocol XPCProtocol

//install
-(void)install:(NSString*)app reply:(void (^)(NSNumber*))reply;

//uninstall
-(void)uninstall:(NSString*)app full:(BOOL)full reply:(void (^)(NSNumber*))reply;

//remove (self)
-(void)remove;

@end

#endif
