//
//  SyncViewController_One.h
//  mainApp
//
//  Created by Patrick Wardle on 1/23/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SyncViewController_Three : NSViewController

//parameters
@property(nonatomic, retain)NSDictionary* parameters;

//linked phone #
@property (weak) IBOutlet NSTextField *phoneNumber;

//linked host name
@property (weak) IBOutlet NSTextField *hostName;

@end
