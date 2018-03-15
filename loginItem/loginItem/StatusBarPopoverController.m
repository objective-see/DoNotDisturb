//
//  StatusBarPopoverController.m
//  Do Not Disturb
//
//  Created by Patrick Wardle on 12/19/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.

#import "AppDelegate.h"
#import "StatusBarPopoverController.h"

@implementation StatusBarPopoverController

//'close' button handler
// ->simply close popover
-(IBAction)interactionHandler:(NSControl *)sender
{
    //close
    [[[self view] window] close];
    
    return;
}

@end
