//
//  LinkWindowController.h
//  mainApp
//
//  Created by Patrick Wardle on 1/25/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <objc/message.h>

@interface LinkWindowController : NSWindowController

//sync view controller
@property(nonatomic, retain)NSViewController* syncViewController;

/* METHODS */

//switch (content) view
-(void)switchView:(NSUInteger)view parameters:(NSDictionary*)parameters;


@end
