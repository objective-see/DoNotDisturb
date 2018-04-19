//
//  file: Preferences.h
//  project: DND (launch daemon)
//  description: store/retrieve user preferences (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

@interface Preferences : NSObject

/* PROPERTIES */

//preferences
@property(nonatomic, retain)NSMutableDictionary* preferences;

/* METHODS */

//get all prefs
// or a specific one...
-(NSDictionary*)get:(NSString*)preference;

//set
// directly override value
-(void)set:(NSString*)key value:(id)value;

//update prefs
// saves and handles logic for specific prefs
-(BOOL)update:(NSDictionary*)updates;

//ping server for registered devices
// then update preferences with this list...
-(void)updateRegisteredDevices;

@end
