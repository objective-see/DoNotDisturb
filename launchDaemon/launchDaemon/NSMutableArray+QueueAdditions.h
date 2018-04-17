//
//  file: NSMutableArray+QueueAdditions.h
//  project: DND (launch daemon)
//  description: queue implementation via NSMutableArray (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//
//  note: based on https://github.com/esromneb/ios-queue-object/blob/master/NSMutableArray%2BQueueAdditions.m

@import Foundation;

@interface NSMutableArray (QueueAdditions)
{
    
}

/* METHODS */

//add object to end of queue
-(void)enqueue:(id)item;

//grab first item
// and then remove it from queue
-(id)dequeue;

//grab first item
// but don't remove it from queue
-(id)peek;

//determine if queue is empty
-(BOOL)isEmpty;

@end
