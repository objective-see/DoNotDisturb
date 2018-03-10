//
//  file: HelperComms.h
//  project: lulu (shared)
//  description: talk to daemon (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Foundation;

#import "XPCProtocol.h"


@interface HelperComms : NSObject

//remote deamon proxy object
@property(nonatomic, retain) id <XPCProtocol> daemon;

//xpc connection
@property (atomic, strong, readwrite) NSXPCConnection* xpcServiceConnection;

/* METHODS */

//install
// takes flag to indicate full/partial
-(void)install:(void (^)(NSNumber*))reply;

//uninstall
// takes flag to indicate full/partial
-(void)uninstall:(BOOL)full reply:(void (^)(NSNumber*))reply;

//remove
-(void)remove;

@end
