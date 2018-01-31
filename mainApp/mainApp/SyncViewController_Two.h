//
//  SyncViewController_One.h
//  mainApp
//
//  Created by Patrick Wardle on 1/23/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SyncViewController_Two : NSViewController

/* PROPERTIES */

//spinner
@property (weak) IBOutlet NSProgressIndicator *activityIndicator;

//activity msg
@property (weak) IBOutlet NSTextField *activityMsg;

//qrc image view
@property (weak) IBOutlet NSImageView *qrcImageView;

@end
