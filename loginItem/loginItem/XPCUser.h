//
//  file: UserComms.h
//  project: DND (launch daemon)
//  description: interface for user componets (header)
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
