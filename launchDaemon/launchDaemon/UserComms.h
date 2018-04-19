//
//  file: UserComms.h
//  project: DND (launch daemon)
//  description: interface for user componets (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;
#import "UserCommsInterface.h"
#import <dnd/dnd-Swift.h>

@interface UserComms : NSObject <UserProtocol, DNDClientMacDelegate>
{
    
}

/* PROPERTIES */

//client status
@property NSInteger currentStatus;

//last alert
@property(nonatomic,retain)NSDictionary* dequeuedAlert;

//registration info from server
@property(nonatomic,retain)NSDictionary *registrationInfo;

//registration wait semaphore
@property dispatch_semaphore_t registrationSema;

/* METHODS */

@end
