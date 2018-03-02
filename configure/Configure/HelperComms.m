//
//  file: DaemonComms.m
//  project: lulu (shared)
//  description: talk to daemon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Foundation;

#import "Consts.h"
#import "AppDelegate.h"
#import "HelperComms.h"

@implementation HelperComms

@synthesize daemon;
@synthesize xpcServiceConnection;

//init
// create XPC connection & set remote obj interface
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc/init
        xpcServiceConnection = [[NSXPCConnection alloc] initWithMachServiceName:INSTALLER_HELPER_ID options:0];
        
        //set remote object interface
        self.xpcServiceConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
        
        //resume
        [self.xpcServiceConnection resume];
    }
    
    return self;
}

//install
// note: XPC is async, so return logic handled in callback block
-(void)install:(void (^)(NSNumber*))reply
{
    //dbg msg
    NSLog(@"installing");
    
    //install
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        NSLog(@"failed to execute 'install' method on helper tool (error: %@)", proxyError);
        
        //invoke block
        reply([NSNumber numberWithInt:-1]);
          
    }] install:[[NSBundle mainBundle] bundlePath] reply:^(NSNumber* result)
    {
        //invoke block
        reply(result);
    }];
    
    return;
}

//uninstall
// note: XPC is async, so return logic handled in callback block
-(void)uninstall:(void (^)(NSNumber*))reply
{
    //dbg msg
    NSLog(@"uninstalling");
    
    //uninstall
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
      {
          //err msg
          NSLog(@"failed to execute 'uninstall' method on helper tool (error: %@)", proxyError);
          
          //invoke block
          reply([NSNumber numberWithInt:-1]);
          
      }] uninstall:[[NSBundle mainBundle] bundlePath] reply:^(NSNumber* result)
     {
         //invoke block
         reply(result);
     }];
    
    return;
}

//remove
-(void)remove
{
    //dbg msg
    NSLog(@"removing");
    
    //remove
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
          //err msg
          NSLog(@"failed to execute 'remove' method on helper tool (error: %@)", proxyError);
          
    }] remove];
    
    return;
}

@end
