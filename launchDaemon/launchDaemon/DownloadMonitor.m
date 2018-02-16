//
//  DownloadMonitor.m
//  launchDaemon
//
//  Created by Patrick Wardle on 2/15/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Logging.h"
#import "DownloadMonitor.h"

@implementation DownloadMonitor

@synthesize query;

//start monitoring
// note: will only detect files downloaded from apps such as browsers (that have 'kMDItemWhereFroms' key set)
-(void)start
{
    //has to be run on the main thread!
    dispatch_async(dispatch_get_main_queue(), ^{
    
    //alloc/init query
    query = [[NSMetadataQuery alloc] init];
    
    //add observer
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDownloadEvent:) name:NSMetadataQueryDidUpdateNotification object:query];
        
    //set delegate
    self.query.delegate = self;
        
    //set predicate
    self.query.predicate = [NSPredicate predicateWithFormat:@"%K like '*'", @"kMDItemWhereFroms"];
        
    //start
    [query startQuery];
        
    });
    
    return;
}

//stop monitoring
- (void)stop
{
    //stop
    [self.query stopQuery];
    
    //unset delegate
    [self.query setDelegate:nil];
    
    //unset
    self.query = nil;
    
    return;
}

//callback for downloaded files
// process each, and log path, etc
-(void)handleDownloadEvent:(NSNotification *)notification
{
    //metadata items
    NSArray* items = nil;
    
    //file path
    NSString* path = nil;
    
    //extract metadata items
    items = notification.userInfo[@"kMDQueryUpdateAddedItems"];
    if(0 == items.count)
    {
        //bail
        goto bail;
    }
    
    //process each
    // extract and log path
    for(NSMetadataItem* item in items)
    {
        //extract path
        path = [item valueForAttribute:(NSString *)kMDItemPath];
        if(0 != path.length)
        {
            //dbg msg and log
            logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"monitor event: downloaded file: %@", path]);
            
        }
    }
    
bail:
    
    return;
}


@end
