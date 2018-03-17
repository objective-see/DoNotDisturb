//
//  file: AppDelegate.h
//  project: DnD (login item)
//  description: app delegate for login item (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

#import "DaemonComms.h"
#import "StatusBarMenu.h"
#import "UpdateWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTouchBarProvider, NSTouchBarDelegate>

/* PROPERTIES */

//status bar menu
@property (weak) IBOutlet NSMenu *statusMenu;

//status bar menu controller
@property(nonatomic, retain)StatusBarMenu* statusBarMenuController;

//touch bar
@property(nonatomic, retain)NSTouchBar* touchBar;

//update window controller
@property(nonatomic, retain)UpdateWindowController* updateWindowController;

//daemon comms
@property(nonatomic, retain)DaemonComms* daemonComms;

//observer
@property(nonatomic, retain)NSObject* appObserver;

/* METHODS */

//init/show touch bar
-(void)initTouchBar;

@end

