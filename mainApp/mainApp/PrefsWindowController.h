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

//to select, need string ID
#define TOOLBAR_GENERAL_ID @"general"

@interface PrefsWindowController : NSWindowController <NSTextFieldDelegate>

/* PROPERTIES */

//daemon comms object
@property (retain, nonatomic)DaemonComms* daemonComms;

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

//email button
@property (weak) IBOutlet NSButton *emailAction;

//email address
@property (weak) IBOutlet NSTextField *emailAddress;

//execute action button
@property (weak) IBOutlet NSButton *executeAction;

//execute path
@property (weak) IBOutlet NSTextField *executePath;

//monitor button
@property (weak) IBOutlet NSButton *monitorAction;

//link view
@property (strong) IBOutlet NSView *linkView;

//qrc image view
@property (weak) IBOutlet NSImageView *qrcImageView;

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
