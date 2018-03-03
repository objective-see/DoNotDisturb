//
//  file: PrefsWindowController.h
//  project: DnD (main app)
//  description: preferences window controller (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "UpdateWindowController.h"

/* CONSTS */

//general view
#define TOOLBAR_GENERAL 101

//action view
#define TOOLBAR_ACTION 102

//link view
#define TOOLBAR_LINK 103

//update view
#define TOOLBAR_UPDATE 104

//tool bar id for 'general'
#define TOOLBAR_GENERAL_ID @"general"

@interface PrefsWindowController : NSWindowController <NSTextFieldDelegate>

/* PROPERTIES */

//daemon comms object
@property (retain, nonatomic)DaemonComms* daemonComms;

//preferences
@property(nonatomic, retain)NSDictionary* preferences;

//toolbar
@property (weak) IBOutlet NSToolbar *toolbar;

//general prefs view
@property (weak) IBOutlet NSView *generalView;

//passive mode button
@property (weak) IBOutlet NSButton *passiveMode;

//icon-less (headless) mode button
@property (weak) IBOutlet NSButton *headlessMode;

//touchID mode button
@property (weak) IBOutlet NSButton *touchIDMode;

//label for touch ID
@property (weak) IBOutlet NSTextField *touchIDLabel;

//action view
@property (weak) IBOutlet NSView *actionView;

//execute action button
@property (weak) IBOutlet NSButton *executeAction;

//execute path
@property (weak) IBOutlet NSTextField *executePath;

//monitor button
@property (weak) IBOutlet NSButton *monitorAction;

/* LINK VIEW */

//link toolbar item
@property (weak) IBOutlet NSToolbarItem *linkToolbarItem;

//link view
@property (strong) IBOutlet NSView *linkView;

//spinner
@property (weak) IBOutlet NSProgressIndicator *activityIndicator;

//activity msg
@property (weak) IBOutlet NSTextField *activityMessage;

//qrc panel
@property (strong) IBOutlet NSPanel *qrcPanel;

//qrc image view
@property (weak) IBOutlet NSImageView *qrcImageView;

/* UNLINK VIEW */

//unlink view
@property (strong) IBOutlet NSView *unlinkView;

//button to unlink
@property (weak) IBOutlet NSButton *unlinkButton;

//host (computer) name
@property (weak) IBOutlet NSTextField *hostName;

//device (phone?) name
@property (weak) IBOutlet NSTextField *deviceName;

//spinner
@property (weak) IBOutlet NSProgressIndicator *unregisterIndicator;


/* UPDATE VIEW */

//update view
@property (weak) IBOutlet NSView *updateView;

//update mode
@property (weak) IBOutlet NSButton *updateMode;

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
