//
//  file: Update.h
//  project: DND (shared)
//  description: checks for new versions of DND (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//


#ifndef Update_h
#define Update_h

@import Foundation;

@interface Update : NSObject


//check for an update
// will invoke app delegate method to update UI when check completes
-(void)checkForUpdate:(void (^)(NSUInteger result, NSString* latestVersion))completionHandler;

@end


#endif /* Update_h */
