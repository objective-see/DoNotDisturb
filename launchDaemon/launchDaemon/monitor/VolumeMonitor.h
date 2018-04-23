//
//  file: VolumeMonitor.h
//  project: DND (launch daemon)
//  description: mounted volumes monitor (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;
@import Foundation;

@interface VolumeMonitor : NSObject

/* PROPERTIES */

/* METHODS */

//start monitoring
-(void)start;

//stop monitoring
-(void)stop;

@end
