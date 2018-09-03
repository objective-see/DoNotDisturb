//
//  file: XPCListener.h
//  project: DND (launch daemon)
//  description: XPC listener for connections from user components (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

@interface XPCListener : NSObject <NSXPCListenerDelegate>
{
    
}

/* PROPERTIES */

//XPC listener
@property(nonatomic, retain)NSXPCListener* listener;

//connection
@property(weak)NSXPCConnection *connection;

/* METHODS */

//setup XPC listener
-(BOOL)initListener;

//automatically invoked
// allows NSXPCListener to configure/accept/resume a new incoming NSXPCConnection
// note: we only allow binaries signed by Objective-See to talk to this!
-(BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection;

@end
