//
//  file: StatusBarMenu.h
//  project: DND (login item)
//  description: menu handler for status bar icon (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;

#import "DaemonComms.h"

@interface StatusBarMenu : NSObject <NSPopoverDelegate>
{

}

//status item
@property (nonatomic, strong, readwrite) NSStatusItem *statusItem;

//popover
@property (retain, nonatomic)NSPopover *popover;

//daemom comms object
@property (nonatomic, retain)DaemonComms* daemonComms;

//disabled flag
@property BOOL isDisabled;

/* METHODS */

//init
-(id)init:(NSMenu*)menu firstTime:(BOOL)firstTime;

@end
