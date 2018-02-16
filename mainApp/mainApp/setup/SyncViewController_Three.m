//
//  SyncViewController_Three.m
//  mainApp
//
//  Created by Patrick Wardle on 1/23/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "AppDelegate.h"
#import "SyncViewController_Three.h"

@interface SyncViewController_Three ()

@end

@implementation SyncViewController_Three

@synthesize parameters;

-(void)viewDidLoad
{
    //super
    [super viewDidLoad];
    
    //set phone #
    self.phoneNumber.stringValue = self.parameters[KEY_PHONE_NUMBER];
    
    //set host name
    // TODO: pass this in from daemon?
    self.hostName.stringValue = [[NSHost currentHost] localizedName];
    
    return;
}

//button handler
// close app, as we're done
- (IBAction)next:(id)sender
{
    //bye!
    [NSApp terminate:nil];
    
    return;
}

@end
