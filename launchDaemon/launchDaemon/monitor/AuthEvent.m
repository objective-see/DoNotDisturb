//
//  AuthEvent.m
//  launchDaemon
//
//  Created by Patrick Wardle on 2/7/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "AuthEvent.h"

@implementation AuthEvent

//for pretty print
-(NSString *)description
{
    //description
    NSString *description = nil;
    
    //init
    description = [NSString stringWithFormat:@"user auth event \n uid: %d / pid: %d / text: %@ / ret: %d\n", self.uid, self.pid, self.text, self.result];
    
    return description;
}

@end
