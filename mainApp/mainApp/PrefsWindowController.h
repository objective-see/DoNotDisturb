//
//  file: PrefsWindowController.h
//  project: DND (main app)
//  description: preferences window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;

#import "UpdateWindowController.h"

/* CONSTS */

//general view
#define TOOLBAR_GENERAL 0

//action view
#define TOOLBAR_TRIGGERS 1

//action view
#define TOOLBAR_ACTION 2

//link view
#define TOOLBAR_LINK 3

//update view
#define TOOLBAR_UPDATE 4

//tool bar id for 'general'
#define TOOLBAR_GENERAL_ID @"general"

//passive mode button
#define BUTTON_PASSIVE_MODE 1

//no icon mode button
#define BUTTON_NO_ICON_MODE 2

//auth mode button
#define BUTTON_AUTH_MODE 3

//remote tasking
#define BUTTON_TASKING_MODE 4


//lid open trigger
#define BUTTON_LID_TRIGGER 5

//usb device trigger
#define BUTTON_DEVICE_TRIGGER 6

//power events trigger
#define BUTTON_POWER_TRIGGER 7


//execute action button
#define BUTTON_EXECUTE_ACTION 8

//monitor button
#define BUTTON_MONITOR_ACTION 9

//snap picture button
#define BUTTON_PHOTO_ACTION 10

//no updates button
#define BUTTON_NO_UPDATES_MODE 11

@interface PrefsWindowController : NSWindowController <NSTextFieldDelegate, NSToolbarDelegate>

/* PROPERTIES */

//daemon comms object
@property (retain, nonatomic)DaemonComms* daemonComms;

//preferences
@property(nonatomic, retain)NSDictionary* preferences;

//toolbar
@property (weak) IBOutlet NSToolbar *toolbar;

//general prefs view
@property (weak) IBOutlet NSView *generalView;

//triggers view
@property (strong) IBOutlet NSView *triggersView;

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
