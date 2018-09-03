//
//  file: PrefsWindowController.h
//  project: DND (main app)
//  description: preferences window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;

#import "XPCDaemonClient.h"
#import "UpdateWindowController.h"

/* CONSTS */

//general view
#define TOOLBAR_GENERAL 0

//action view
#define TOOLBAR_ACTION 1

//link view
#define TOOLBAR_LINK 2

//update view
#define TOOLBAR_UPDATE 3

//tool bar id for 'general'
#define TOOLBAR_GENERAL_ID @"general"

//passive mode button
#define BUTTON_PASSIVE_MODE 1

//no icon mode button
#define BUTTON_NO_ICON_MODE 2

//touch id mode button
#define BUTTON_TOUCHID_MODE 3

//start mode button
#define BUTTON_START_MODE 4

//execute action button
#define BUTTON_EXECUTE_ACTION 5

//monitor button
#define BUTTON_MONITOR_ACTION 6

//no remote tasking button
#define BUTTON_NO_REMOTE_TASKING 7

//no updates button
#define BUTTON_NO_UPDATES_MODE 8

@interface PrefsWindowController : NSWindowController <NSTextFieldDelegate, NSToolbarDelegate>

/* PROPERTIES */

//daemon comms object
@property (retain, nonatomic)XPCDaemonClient* daemonComms;

//preferences
@property(nonatomic, retain)NSDictionary* preferences;

//toolbar
@property (weak) IBOutlet NSToolbar *toolbar;

//general prefs view
@property (weak) IBOutlet NSView *generalView;

//action view
@property (weak) IBOutlet NSView *actionView;

//execute path
@property (weak) IBOutlet NSTextField *executePath;

/* LINK VIEW */

//overlay view
@property (strong) IBOutlet NSView *overlayView;

//overlay spinner
@property (weak) IBOutlet NSProgressIndicator *overlayProgressIndicator;

//link toolbar item
@property (weak) IBOutlet NSToolbarItem *linkToolbarItem;

//link view
@property (strong) IBOutlet NSView *linkView;

//spinner
@property (weak) IBOutlet NSProgressIndicator *qrcProgressIndicator;

//activity msg
@property (weak) IBOutlet NSTextField *activityMessage;

//qrc panel
@property (strong) IBOutlet NSPanel *qrcPanel;

//qrc image view
@property (weak) IBOutlet NSImageView *qrcImageView;

/* LINKED (DEVICES) VIEW */

//linked view
@property (strong) IBOutlet NSView *linkedView;

//host (computer) name
@property (weak) IBOutlet NSTextField *hostName;

//device names
@property (unsafe_unretained) IBOutlet NSTextView *deviceNames;


/* UPDATE VIEW */

//update view
@property (weak) IBOutlet NSView *updateView;

//update button
@property (weak) IBOutlet NSButton *updateButton;

//update indicator (spinner)
@property (weak) IBOutlet NSProgressIndicator *updateIndicator;

//update label
@property (weak) IBOutlet NSTextField *updateLabel;

//update window controller
@property(nonatomic, retain)UpdateWindowController* updateWindowController;

/* METHODS */

//toolbar button handler
-(IBAction)toolbarButtonHandler:(id)sender;

//button handler for all preference buttons
-(IBAction)togglePreference:(id)sender;

@end
