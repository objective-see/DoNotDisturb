//
//  file: XPC.h
//  project: DND (shared)
//  description: xpc protocols, ivars, etc,
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#ifndef XPC_h
#define XPC_h

//protocol
// methods that deamon exports
@protocol XPC_DAEMON



@end

//protocol
// methods that user exports
@protocol XPC_USER

- (void) updateProgress: (double) currentProgress;
- (void) finished;

@end

@interface XPCListener : NSObject<NSXPCListenerDelegate>

/* PROPERTIES */

//XPC listener
@property(retain, nonatomic)NSXPCListener* listener;

/* METHODS */

//setup XPC listener
-(BOOL)initListener;

//automatically invoked when new client (attempts) to connect
-(BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection;

@end

#endif /* XPC_h */
