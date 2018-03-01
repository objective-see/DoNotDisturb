//
//  FrameworkInterface.h
//  launchDaemon
//
//  Created by Patrick Wardle on 3/1/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <dnd/dnd-swift.h>
#import <Foundation/Foundation.h>

@interface FrameworkInterface : NSObject

/* METHODS */

//identity
@property(nonatomic, retain)DNDIdentity *identity;

//initialize an identity for DnD comms
// generates client id, etc. and then creates identity
-(BOOL)initIdentity;

@end
