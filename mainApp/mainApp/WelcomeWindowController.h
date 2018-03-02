//
//  WelcomeWindowController.h
//  mainApp
//
//  Created by Patrick Wardle on 1/25/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <objc/message.h>

@interface WelcomeWindowController : NSWindowController

/* PROPERTIES */

//welcome view
@property (strong) IBOutlet NSView *welcomeView;

//app info view
@property (strong) IBOutlet NSView *appInfo;

//config view
@property (strong) IBOutlet NSView *qrcView;

//activity indicator
@property (weak) IBOutlet NSProgressIndicator *activityIndicator;

//activity msg
@property (weak) IBOutlet NSTextField *activityMessage;

//qrc image view
@property (weak) IBOutlet NSImageView *qrcImageView;

//linked view
@property (strong) IBOutlet NSView *linkedView;

//welcome view controller
@property(nonatomic, retain)NSViewController* welcomeViewController;

/* METHODS */

@end
