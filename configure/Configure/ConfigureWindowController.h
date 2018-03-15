//
//  ConfigureWindowController.h
//  Do Not Disturb
//
//  Created by Patrick Wardle on 7/7/2016.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ConfigureWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */
@property (weak, nonatomic) IBOutlet NSTextField *statusMsg;
@property (weak, nonatomic) IBOutlet NSButton *installButton;
@property (weak, nonatomic) IBOutlet NSButton *moreInfoButton;
@property (weak, nonatomic) IBOutlet NSButton *uninstallButton;
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
