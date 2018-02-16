//
//  DownloadMonitor.h
//  launchDaemon
//
//  Created by Patrick Wardle on 2/15/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

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
