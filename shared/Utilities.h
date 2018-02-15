//
//  file: Utilities.h
//  project: DnD (shared)
//  description: various helper/utility functions (header)
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#ifndef Utilities_h
#define Utilities_h

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

/* FUNCTIONS */

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion(void);

//get OS version
// note: this uses macOS 10.10+ methods
NSOperatingSystemVersion getOSVersion(void);

//get console user id
NSNumber* getConsoleUID(void);

//verify that an app bundle is
// a) signed
// b) signed with signing auth
OSStatus verifyApp(NSString* path, NSString* signingAuth);

//get process name
// ->either via app bundle, or path
NSString* getProcessName(NSString* path);

//given a pid
// get process's path
NSString* getProcessPath(pid_t pid);

//given a process path and user
// ->return array of all matching pids
NSMutableArray* getProcessIDs(NSString* processPath, int userID);

//wait until a window is non nil
// ->then make it modal
void makeModal(NSWindowController* windowController);

//check if an instance of an app is already running
BOOL isAppRunning(NSString* bundleID);

//set dir's|file's group/owner
BOOL setFileOwner(NSString* path, NSNumber* groupID, NSNumber* ownerID, BOOL recursive);

//exec a process with args
// if 'shouldWait' is set, wait and return stdout/in and termination status
NSMutableDictionary* execTask(NSString* binaryPath, NSArray* arguments, BOOL shouldWait);

//touchID capable?
BOOL hasTouchID(void);

//get current console user
NSString* currentConsoleUser(SCDynamicStoreRef store);

#endif
