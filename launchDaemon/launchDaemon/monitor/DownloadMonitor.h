//
//  file: DownloadMonitor.h
//  project: DND (launch daemon)
//  description: download file monitor (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

@interface DownloadMonitor : NSObject <NSMetadataQueryDelegate>

/* PROPERTIES */

//query
@property(nonatomic, retain)NSMetadataQuery* query;

/* METHODS */

//start monitoring
-(void)start;

//stop monitoring
-(void)stop;

@end
