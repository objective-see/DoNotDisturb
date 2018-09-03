//
//  file: XPCDaemon.h
//  project: DND (launch daemon)
//  description: interface for user XPC methods (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;
#import <dnd/dnd-Swift.h>

#import "XPCDaemonProto.h"


@interface XPCDaemon : NSObject <XPCDaemonProtocol, DNDClientMacDelegate>
{
    
}

/* PROPERTIES */

//registration info from server
@property(nonatomic,retain)NSDictionary *registrationInfo;

//registration wait semaphore
@property dispatch_semaphore_t registrationSema;

/* METHODS */

@end
