//
//  file: Update.h
//  project: DnD (shared)
//  description: checks for new versions of DnD (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


#ifndef Update_h
#define Update_h

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>


@interface Update : NSObject


//check for an update
// will invoke app delegate method to update UI when check completes
-(void)checkForUpdate:(void (^)(NSUInteger result, NSString* latestVersion))completionHandler;

@end


#endif /* Update_h */
