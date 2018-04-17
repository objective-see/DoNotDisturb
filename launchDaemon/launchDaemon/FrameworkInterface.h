//
//  file: FrameworkInterface.h
//  project: DND (launch daemon)
//  description: interface to Digita Security's (swift) framework (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import <dnd/dnd-swift.h>

@import Foundation;

@interface FrameworkInterface : NSObject

/* METHODS */

//identity
@property(nonatomic, retain)DNDIdentity *identity;

//initialize an identity for DND comms
// generates client id, etc. and then creates identity
-(BOOL)initIdentity:(BOOL)full;

@end
