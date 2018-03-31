//
//  Preferences.m
//  launchDaemon
//
//  Created by Patrick Wardle on 2/22/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Lid.h"
#import "consts.h"
#import "logging.h"
#import "Preferences.h"
#import "FrameworkInterface.h"

/* GLOBALS */

//lid obj
extern Lid* lid;

//DnD framework interface obj
extern FrameworkInterface* framework;

@implementation Preferences

@synthesize preferences;

//init
// loads prefs
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //prefs exist?
        // load them from disk
        if(YES == [[NSFileManager defaultManager] fileExistsAtPath:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE]])
        {
            //load
            if(YES != [self load])
            {
                //err msg
                logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to loads preferences from %@", PREFS_FILE]);
                
                //unset
                self = nil;
                
                //bail
                goto bail;
            }
        }
        //no prefs (yet)
        // just initialze empty dictionary
        else
        {
            //init
            preferences = [NSMutableDictionary dictionary];
        }
    }
    
bail:
    
    
    return self;
}


//load prefs from disk
-(BOOL)load
{
    //flag
    BOOL loaded = NO;
    
    //load
    preferences = [NSMutableDictionary dictionaryWithContentsOfFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE]];
    if(nil == self.preferences)
    {
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"loaded preferences: %@", self.preferences]);
    
    //happy
    loaded = YES;
    
bail:
    
    return loaded;
}

//get all prefs
// or a specific one...
-(NSDictionary*)get:(NSString*)preference
{
    //current preferences
    NSDictionary* currentPrefs = nil;
    
    //none specified?
    // just will return all
    if(nil == preference)
    {
        //all
        currentPrefs = self.preferences;
    }
    //grab just the one user requested
    else
    {
        //registered devices?
        // first get most recent list from server
        if(YES == [preference isEqualToString:PREF_REGISTERED_DEVICES])
        {
            //get most recent list
            [self updateRegisteredDevices];
        }
        
        //now grab requested pref
        if(nil != self.preferences[preference])
        {
            //grab
            currentPrefs = @{preference:self.preferences[preference]};
        }
    }
    
    return currentPrefs;
}

//set & save
// directly override value
-(void)set:(NSString*)key value:(id)value
{
    //set
    self.preferences[key] = value;
    
    //save
    if(YES != [self save])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to save preferences");
        
        //bail
        goto bail;
    }
    
bail:
    
    return;
}

//update prefs
// handles logic for specific prefs & then saves
-(BOOL)update:(NSDictionary*)updates
{
    //flag
    BOOL updated = NO;

    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"updating preferences (%@)", updates]);
    
    //user setting state?
    // toggle the state of the daemon (lid) watcher too
    if(nil != updates[PREF_IS_DISABLED])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"client toggling state: %@", updates[PREF_IS_DISABLED]]);
        
        //disable?
        if(YES == [updates[PREF_IS_DISABLED] boolValue])
        {
            //dbg msg
            // and log to file
            logMsg(LOG_DEBUG|LOG_TO_FILE, @"disabling...");
            
            //unregister for lid notifications
            [lid unregister4Notifications];
            
            //dbg msg
            logMsg(LOG_DEBUG, @"unregistered for lid change notifications");
            
            //disconnect any client(s)
            if(nil != lid.client)
            {
                //disconnect
                [lid.client disconnect];
                
                //unset
                lid.client = nil;
                
                //dbg msg
                logMsg(LOG_DEBUG, @"disconnected client");
            }
            
            //finally broadcast dimiss to dismiss any alerts
            [[NSNotificationCenter defaultCenter] postNotificationName:DISMISS_NOTIFICATION object:nil userInfo:nil];
        }
        
        //enable?
        else
        {
            //dbg msg
            // and log to file
            logMsg(LOG_DEBUG|LOG_TO_FILE, @"enabling...");
            
            //register for lid notifications
            [lid register4Notifications];
            
            //dbg msg
            logMsg(LOG_DEBUG, @"registered for lid change notifications");
        }
    }
    
    //updating list of registered devices?
    // its a dictionary so requires an extra merge
    if( (nil != updates[PREF_REGISTERED_DEVICES]) &&
        (nil != self.preferences[PREF_REGISTERED_DEVICES]) )
    {
        //merge
        [self.preferences addEntriesFromDictionary:updates[PREF_REGISTERED_DEVICES]];
    }
    
    //for all other prefs or for 1st device
    // just merge in new prefs into existing ones
    else
    {
        //merge
        [self.preferences addEntriesFromDictionary:updates];
    }
    
    //save
    if(YES != [self save])
    {
        //err msg
        logMsg(LOG_ERR, @"failed to save preferences");
        
        //bail
        goto bail;
    }
    
    //happy
    updated = YES;
    
bail:
    
    return updated;
}

//ping server for registered devices
// then update preferences with this list...
-(void)updateRegisteredDevices
{
    //current devices
    NSDictionary* currentDevices = nil;
    
    //client
    DNDClientMac *client;
    
    //registered devices
    NSMutableDictionary* devices = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"updating registered devices");
    
    //alloc dictionary
    devices = [NSMutableDictionary dictionary];
    
    //get current devices
    // aren't any, just bail
    currentDevices = self.preferences[PREF_REGISTERED_DEVICES];
    if(0 == currentDevices.count)
    {
        //bail
        goto bail;
    }
    
    //sanity check
    // only happens w/ 0 registered devices
    // and since devices have to be registered via computer, server won't have more...
    if(nil == framework.identity)
    {
        //bail
        goto bail;
    }
    
    //init client
    client = [[DNDClientMac alloc] initWithDndIdentity:framework.identity sendCA:true background:true];
    if(nil == client)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to initialize client");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"asking server for list of registered endpoints");
    
    //get list of registered devices from server
    // build (updated) list of devices id : device name mappings
    for(NSString* deviceID in [client getShadowSync].state.reported.endpoints)
    {
        //add current device name
        devices[deviceID] = currentDevices[deviceID];
    }
    
    //no registered devices?
    // remove key from preferences
    if(0 == devices.count)
    {
        //unset
        [self set:PREF_REGISTERED_DEVICES value:nil];
    }
    //otherwise
    // update preferences with (current) registered devices
    else
    {
        //update
        [self set:PREF_REGISTERED_DEVICES value:devices];
    }
    
bail:
    
    return;
}

//save to disk
-(BOOL)save
{
    //save
    return [self.preferences writeToFile:[INSTALL_DIRECTORY stringByAppendingPathComponent:PREFS_FILE] atomically:YES];
}

//for pretty print
-(NSString *)description
{
    //prefs dictionary
    return self.preferences.description;
}

@end
