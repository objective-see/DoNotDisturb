//
//  file: ConfigureWindowController.h
//  project: DND (config)
//  description: configure (install/uninstall) window (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;

@interface ConfigureWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//"friends of objective-see"
@property (strong, nonatomic) IBOutlet NSView *friendsView;

//status msg
@property (weak, nonatomic) IBOutlet NSTextField *statusMsg;

//install button
@property (weak, nonatomic) IBOutlet NSButton *installButton;

//more info button
@property (weak, nonatomic) IBOutlet NSButton *moreInfoButton;

//uninstall button
@property (weak, nonatomic) IBOutlet NSButton *uninstallButton;

//activity indicator (spinner)
@property (weak, nonatomic) IBOutlet NSProgressIndicator *activityIndicator;

/* METHODS */

//install/uninstall button handler
-(IBAction)buttonHandler:(id)sender;

//(more) info button handler
-(IBAction)info:(id)sender;

//configure window/buttons
// also brings to front
-(void)configure:(BOOL)isInstalled;

//display (show) window
-(void)display;

@end
