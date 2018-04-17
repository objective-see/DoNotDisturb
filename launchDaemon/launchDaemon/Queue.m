//
//  file: Queue.m
//  project: DND (launch daemon)
//  description: a queue implementation
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Queue.h"
#import "Consts.h"
#import "Logging.h"

@implementation Queue

@synthesize eventQueue;
@synthesize queueCondition;

//init
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //init queue
        eventQueue = [NSMutableArray array];
        
        //init empty condition
        queueCondition = [[NSCondition alloc] init];
    }
    
    return self;
}

//add an object to the queue
-(void)enqueue:(id)anObject
{
    //lock
    [self.queueCondition lock];
    
    //add to queue
    [self.eventQueue enqueue:anObject];
    
    //signal
    [self.queueCondition signal];
    
    //unlock
    [self.queueCondition unlock];
    
    return;
}

//wait until queue has item
// then pull if off, and return it
-(id)dequeue
{
    //queue item
    id item = nil;
    
    //lock
    [self.queueCondition lock];
    
    //wait while queue is empty
    while(YES == [self.eventQueue isEmpty])
    {
        //wait
        [self.queueCondition wait];
    }
    
    //get item off queue
    item = [self.eventQueue dequeue];
    
    //unlock
    [self.queueCondition unlock];
    
    return item;
}

//wait until queue has item
// and return it, w/o removing it
-(id)peek
{
    //queue item
    id item = nil;
    
    //lock
    [self.queueCondition lock];
    
    //wait while queue is empty
    while(YES == [self.eventQueue isEmpty])
    {
        //wait
        [self.queueCondition wait];
    }
    
    //get item off queue
    item = [self.eventQueue peek];
    
    //unlock
    [self.queueCondition unlock];
    
    return item;
}

@end
