//
//  file: Queue.h
//  project: DND (launch daemon)
//  description: a queue implementation (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;
#import "NSMutableArray+QueueAdditions.h"

@interface Queue : NSObject
{
    
}

/* PROPERTIES */

//event queue
@property(retain, atomic)NSMutableArray* eventQueue;

//queue condition
@property (nonatomic, retain)NSCondition* queueCondition;


/* METHODS */

//add an object to the queue
-(void)enqueue:(id)anObject;

//wait until queue has item
// then pull if off, and return it
-(id)dequeue;

//wait until queue has item
// and return it, w/o removing it
-(id)peek;

@end
