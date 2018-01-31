//
//  LinkWindowController.m
//  mainApp
//
//  Created by Patrick Wardle on 1/25/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "LinkWindowController.h"
#import "SyncViewController_One.h"
#import "SyncViewController_Two.h"
#import "SyncViewController_Three.h"

@interface LinkWindowController ()

@end

@implementation LinkWindowController

@synthesize syncViewController;

- (void)windowDidLoad {
    
    //super
    [super windowDidLoad];
    
    //center
    [self.window center];
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];
    
    //when supported
    // indicate title bar is transparent (too)
    if ([self.window respondsToSelector:@selector(titlebarAppearsTransparent)])
    {
        //set transparency
        self.window.titlebarAppearsTransparent = YES;
    }
    
    //show first view
    [self switchView:SYNC_VIEW_ONE parameters:nil];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}


//switch (content) view
-(void)switchView:(NSUInteger)view parameters:(NSDictionary*)parameters
{
    switch(view)
    {
        //show 1st view
        case SYNC_VIEW_ONE:
            
            //init sync view controller
            syncViewController = [[SyncViewController_One alloc] initWithNibName:@"SyncViewController_One" bundle:nil];
            
            break;
            
        //show 2nd view
        case SYNC_VIEW_TWO:
            
            //init sync view controller
            syncViewController = [[SyncViewController_Two alloc] initWithNibName:@"SyncViewController_Two" bundle:nil];
        
            break;
            
        //show 3rd view
        case SYNC_VIEW_THREE:
            
            //init sync view controller
            syncViewController = [[SyncViewController_Three alloc] initWithNibName:@"SyncViewController_Three" bundle:nil];
            
            break;
            
        default:
            break;
    }
    
    //set params?
    // also make sure obj has 'parameters' property
    if( (nil != parameters) &&
        (nil != class_getProperty([self.syncViewController class], "parameters")) )
    {
        //set
        [self.syncViewController setValue:parameters forKey:@"parameters"];
    }

    //set it as content view
    self.window.contentView = [self.syncViewController view];
    
    return;
}

@end
