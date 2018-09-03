//
//  file: WelcomeWindowController.h
//  project: DND (main app)
//  description: 'welcome' window logic/controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;

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

//host name
@property (weak) IBOutlet NSTextField *hostName;

//(registered) device name
@property (weak) IBOutlet NSTextField *deviceName;

//welcome view controller
@property(nonatomic, retain)NSViewController* welcomeViewController;

/* METHODS */

@end
