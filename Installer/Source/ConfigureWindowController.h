//
//  file: ConfigureWindowController.h
//  project: DoNotDisturb (config)
//  description: install/uninstall window logic (header)
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//


@import Cocoa;

@interface ConfigureWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//config object
@property(nonatomic, retain) Configure* configureObj;

//uninstall button
@property (weak, nonatomic) IBOutlet NSButton *uninstallButton;

//install button
@property (weak, nonatomic) IBOutlet NSButton *installButton;

//status msg
@property (weak, nonatomic) IBOutlet NSTextField *statusMsg;

//more info button
@property (weak, nonatomic) IBOutlet NSButton *moreInfoButton;

//spinner
@property (weak, nonatomic) IBOutlet NSProgressIndicator *activityIndicator;

//INFO VIEW
@property (strong) IBOutlet NSView *infoView;
@property (weak) IBOutlet NSButton *infoViewNextButton;

//FDA VIEW
@property (strong) IBOutlet NSView *diskAccessView;
@property (weak, nonatomic) IBOutlet NSButton *diskAccessButton;
@property (weak, nonatomic) IBOutlet NSTextField *fdaMessage;
@property (weak, nonatomic) IBOutlet NSProgressIndicator *fdaActivityIndicator;

//CONFIGURE VIEW
@property (strong) IBOutlet NSView *configureView;

@property (weak) IBOutlet NSButton *passiveMode;
@property (weak) IBOutlet NSButton *appleWatchMode;
@property (weak) IBOutlet NSButton *touchIDMode;

//preferences
@property (nonatomic, retain)NSDictionary* preferences;

//SUPPORT VIEW
@property (strong, nonatomic) IBOutlet NSView *supportView;
@property (weak, nonatomic) IBOutlet NSButton *supportButton;

//observer for app activation
@property(nonatomic, retain)id appActivationObserver;

/* METHODS */

//install/uninstall button handler
-(IBAction)configureButtonHandler:(id)sender;

//(more) info button handler
-(IBAction)info:(id)sender;

//configure window/buttons
-(void)configure;

//display (show) window
-(void)display;

@end
