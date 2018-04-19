//
//  file: StatusBarPopoverController.h
//  project: DND (login item)
//  description: controller for status bar popover
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "AppDelegate.h"
#import "StatusBarPopoverController.h"

@implementation StatusBarPopoverController

//'close' button handler
// simply close popover
-(IBAction)interactionHandler:(NSControl *)sender
{
    //close
    [[[self view] window] close];
    
    return;
}

@end
