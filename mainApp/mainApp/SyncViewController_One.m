//
//  SyncViewController_One.m
//  mainApp
//
//  Created by Patrick Wardle on 1/23/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "AppDelegate.h"
#import "SyncViewController_One.h"

@interface SyncViewController_One ()

@end

@implementation SyncViewController_One


-(void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

//button handler
// call into app delegate to show next view
- (IBAction)next:(id)sender
{
    //call into app delegate to show next view
    [((AppDelegate*)[[NSApplication sharedApplication] delegate]).linkWindowController switchView:SYNC_VIEW_TWO parameters:nil];
    
    return;
}

@end
