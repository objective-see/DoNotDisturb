//
//  AboutWindowController.h
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/15/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AboutWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//version label/string
@property (weak, atomic) IBOutlet NSTextField *versionLabel;

//patrons
@property (unsafe_unretained, atomic) IBOutlet NSTextView *patrons;

//'support us' button
@property (weak, atomic) IBOutlet NSButton *supportUs;


@end
