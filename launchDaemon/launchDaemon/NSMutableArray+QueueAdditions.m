//
//  file: NSMutableArray+QueueAdditions.m
//  project: DND (launch daemon)
//  description: queue implementation via NSMutableArray
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//
//  note: based on https://github.com/esromneb/ios-queue-object/blob/master/NSMutableArray%2BQueueAdditions.m

#import "NSMutableArray+QueueAdditions.h"

@implementation NSMutableArray (QueueAdditions)

//add object to end of queue
-(void)enqueue:(id)item
{
    //sync
    @synchronized(self)
    {
        //add object
        [self addObject:item];
    }
    
    return;
}

//grab first item
// and then remove it from queue
-(id)dequeue
{
    //object
    id queueObject = nil;
    
    //sync
    @synchronized(self)
    {
        //extract first item
        queueObject = [self firstObject];
            
        //delete it from queue
        [self removeObjectAtIndex:0];
        
    }//sync
    
    return queueObject;
}

//grab first item
// but don't remove it from queue
-(id)peek
{
    return [self firstObject];
}

//determine if queue is empty
-(BOOL)isEmpty
{
    //empty?
    return (0 == self.count);
}

@end
