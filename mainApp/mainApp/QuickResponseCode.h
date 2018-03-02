//
//  QuickResponseCode.h
//  mainApp
//
//  Created by Patrick Wardle on 1/25/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "DaemonComms.h"

#import <Foundation/Foundation.h>

@interface QuickResponseCode : NSObject

/* PROPERTIES */

//daemon comms obj
@property(nonatomic, retain)DaemonComms* daemonComms;

//qrc info (from daemon)
//@property(nonatomic, retain)NSData* qrcInfo;


/* METHODS */

//generate a QRC code
// gets QRC string from image, then generates image
-(void)generateQRC:(float)size reply:(void (^)(NSImage* qrc))reply;

@end
