//
//  Monitor.h
//  launchDaemon
//
//  Created by Patrick Wardle on 2/13/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Monitor : NSObject

//start all monitoring
// processes, auth events, hardware insertions, etc
-(BOOL)start:(NSUInteger)timeout;

@end
