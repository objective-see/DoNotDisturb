//
//  file: AppDelegate.h
//  project: DnD (main app)
//  description: application delegate (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "DaemonComms.h"
#import "LinkWindowController.h"
#import "AboutWindowController.h"
#import "PrefsWindowController.h"
#import "UpdateWindowController.h"
#import "3rdParty/HyperlinkTextField.h"

@interface AppDelegate : NSApplication <NSApplicationDelegate>

/* PROPERTIES */

//link view controller
@property(nonatomic, retain)LinkWindowController* linkWindowController;

//about window controller
@property(nonatomic, retain)AboutWindowController* aboutWindowController;

//preferences window controller
@property(nonatomic, retain)PrefsWindowController* prefsWindowController;

/* METHODS */

//start the (helper) login item
-(BOOL)startLoginItem:(BOOL)shouldRestart;

@end

