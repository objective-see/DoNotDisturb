//
//  file: XPCUser.h
//  project: DND (login item)
//  description: user XPC methods (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;
#import <dnd/dnd-Swift.h>

#import "XPCUserProto.h"

@interface XPCUser : NSObject <XPCUserProtocol, NSUserNotificationCenterDelegate>
{
    
}

@end
