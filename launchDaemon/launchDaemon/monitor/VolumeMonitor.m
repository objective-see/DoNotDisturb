//
//  file: VolumeMonitor.h
//  project: DND (launch daemon)
//  description: mounted volume file monitor
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Logging.h"
#import "VolumeMonitor.h"

@implementation VolumeMonitor

//start monitoring
-(void)start
{
    //add observer
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector: @selector(volumeMounted:) name:NSWorkspaceDidMountNotification object:nil];
    
    return;
}

//stop monitoring
-(void)stop
{
    //remove observer
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWorkspaceDidMountNotification object:nil];
    
    return;
}

//callback
// log details of mounted volume
-(void)volumeMounted:(NSNotification*)notification
{
    //path
    NSString* path = nil;
    
    //get path
    path = [notification.userInfo[NSWorkspaceVolumeURLKey] path];
    
    //dbg msg and log
    logMsg(LOG_DEBUG|LOG_TO_FILE, [NSString stringWithFormat:@"monitor event: volume mounted: %@\n%@", path, notification.userInfo]);
    
    return;
}

@end
