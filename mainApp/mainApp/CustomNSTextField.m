//
//  CustomNSButton.m
//  Do Not Disturb
//
//  Created by Patrick Wardle on 1/4/17.
//  Copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "CustomNSTextField.h"

@implementation CustomNSTextField

//check if a event appears to be simulated
// tl;dr pid isn't root or self, and 'kCGEventSourceStateID' isn't 0x1
-(BOOL)isSimulated:(NSEvent*)event
{
    //flag
    BOOL simulated = NO;
    
    //source state
    int64_t sourceState = 0;
    
    //source pid
    int64_t sourcePID = 0;
    
    //sanity check
    if(0 == event.CGEvent)
    {
        //bail
        goto bail;
    }
    
    //get source state
    sourceState = CGEventGetIntegerValueField(event.CGEvent, kCGEventSourceStateID);
    
    //get source pid
    sourcePID = CGEventGetIntegerValueField(event.CGEvent, kCGEventSourceUnixProcessID);
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"event source state: %lld / source pid: %lld", sourceState, sourcePID]);
    
    //allow root
    if(0 == sourcePID)
    {
        //bail
        goto bail;
    }
    
    //check event source and pid
    if( (1 != sourceState) &&
        (getpid() != sourcePID) )
    {
        //set flag
        simulated = YES;
    }
    
bail:
    
    return simulated;
}

//check mouse down events
//ignore simulated mouse down events
-(void)mouseDown:(NSEvent *)event
{
    //simulated?
    if(YES == [self isSimulated:event])
    {
        //err msg
        logMsg(LOG_ERR, @"ignoring simulated mouse down event");
        
        //bail
        goto bail;
        
    }
    
    //allow
    [super mouseDown:event];
    
bail:

    return;    
}

//check key down events
// ignore simulated key down events
-(void)keyDown:(NSEvent *)event
{
    //simulated?
    if(YES == [self isSimulated:event])
    {
        //err msg
        logMsg(LOG_ERR, @"ignoring simulated key down event");
        
        //bail
        goto bail;
        
    }

    //allow
    [super keyDown:event];
    
bail:
    
    return;
}

@end
