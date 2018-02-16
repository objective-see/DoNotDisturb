//
//  SyncViewController_One.m
//  mainApp
//
//  Created by Patrick Wardle on 1/23/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "AppDelegate.h"
#import "SyncViewController_Zero.h"

@interface SyncViewController_Zero ()

@end

@implementation SyncViewController_Zero

//button handler
// call into app delegate to show next view
- (IBAction)next:(id)sender
{
    //call into app delegate to show next view
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).linkWindowController switchView:SYNC_VIEW_ONE parameters:nil];
    
    return;
}

@end
