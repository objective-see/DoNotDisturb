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

/* GLOBALS */

//lid obj
extern Lid* lid;

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

//get prefs
-(NSDictionary*)get
{
    return self.preferences;
}

//set
// directly override value
-(void)set:(NSString*)key value:(id)value
{
    //set
    self.preferences[key] = value;
    
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
                
                //dbg msg
                logMsg(LOG_DEBUG, @"disconnected client");
            }
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
