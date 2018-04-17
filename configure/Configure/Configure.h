//
//  file: Configure.h
//  project: DND (config)
//  description: configure DND, install/uninstall (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "HelperComms.h"

@import Foundation;

@interface Configure : NSObject
{
    
}

/* PROPERTIES */

//helper installed & connected
@property(nonatomic) BOOL gotHelp;

//daemom comms object
@property(nonatomic, retain) HelperComms* xpcComms;

/* METHODS */

//determine if extension is installed
-(BOOL)isInstalled;

//invokes appropriate install || uninstall logic
-(BOOL)configure:(NSInteger)parameter;

//install
-(BOOL)install;

//uninstall
-(BOOL)uninstall:(BOOL)full;

//remove helper (daemon)
-(void)removeHelper;

@end

