//
//  file: AppDelegate.h
//  project: DnD (login item)
//  description: app delegate for login item (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

#import "StatusBarMenu.h"
#import "UpdateWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

/* PROPERTIES */

//status bar menu
@property (weak) IBOutlet NSMenu *statusMenu;

//status bar menu controller
@property(nonatomic, retain)StatusBarMenu* statusBarMenuController;

//update window controller
@property(nonatomic, retain)UpdateWindowController* updateWindowController;

@end

