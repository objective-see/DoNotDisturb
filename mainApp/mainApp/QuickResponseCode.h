//
//  file: QuickResponseCode.h
//  project: DND (main app)
//  description: QR Code logic (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;
@import Foundation;

#import "DaemonComms.h"

@interface QuickResponseCode : NSObject

/* PROPERTIES */

//daemon comms obj
@property(nonatomic, retain)DaemonComms* daemonComms;


/* METHODS */

//generate a QRC code
// gets QRC string from image, then generates image
-(void)generateQRC:(float)size reply:(void (^)(NSImage* qrc))reply;

@end
