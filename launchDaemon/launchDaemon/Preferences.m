//
//  file: Preferences.m
//  project: DND (launch daemon)
//  description: store/retrieve user preferences
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "Triggers.h"
#import "Preferences.h"
#import "FrameworkInterface.h"

/* GLOBALS */

//trigger obj
extern Triggers* triggers;

//DND framework interface obj
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
        // but only if there is at least one (local) device...
        if( (YES == [preference isEqualToString:PREF_REGISTERED_DEVICES]) &&
            (0 != [self.preferences[PREF_REGISTERED_DEVICES] count]) )
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
    // toggle the state of the daemon triggers too
    if(nil != updates[PREF_IS_DISABLED])
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"client toggling state: %@", updates[PREF_IS_DISABLED]]);
        
        //disable triggers
        if(YES == [updates[PREF_IS_DISABLED] boolValue])
        {
            //dbg msg
            // and log to file
            logMsg(LOG_DEBUG|LOG_TO_FILE, @"disabling...");
            
            //turn off all triggers
            [triggers toggle:ALL_TRIGGERS state:NSOffState];
            
            //dbg msg
            logMsg(LOG_DEBUG, @"disabled triggers");
            
            //cancel all dispatch blocks
            [triggers cancelDispatchBlocks];
            
            //dbg msg
            logMsg(LOG_DEBUG, @"cancelled all dispatch blocks (disconnecting any connected iOS client)");
            
            //finally broadcast dimiss to dismiss any alerts
            [[NSNotificationCenter defaultCenter] postNotificationName:DISMISS_NOTIFICATION object:nil userInfo:nil];
        }
        
        //enable triggers
        else
        {
            //dbg msg
            // and log to file
            logMsg(LOG_DEBUG|LOG_TO_FILE, @"enabling...");
            
            //turn off all triggers
            [triggers toggle:ALL_TRIGGERS state:NSOnState];
            
            //dbg msg
            logMsg(LOG_DEBUG, @"enabled (all) triggers");
        }
    }
    
    //toggle lid triggers
    if(nil != updates[PREF_LID_TRIGGER])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"toggling lid notifications");
        
        //enable lid trigger
        if(YES == [updates[PREF_LID_TRIGGER] boolValue])
        {
            //enable
            [triggers toggle:LID_TRIGGER state:NSOnState];
        }
        
        //disable lid trigger
        else
        {
            //disable
            [triggers toggle:LID_TRIGGER state:NSOffState];
        }
    }
    
    //toggle device triggers
    if(nil != updates[PREF_DEVICE_TRIGGER])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"toggling device notifications");
        
        //enable device trigger
        if(YES == [updates[PREF_DEVICE_TRIGGER] boolValue])
        {
            //enable
            [triggers toggle:DEVICE_TRIGGER state:NSOnState];
        }
        
        //disable device trigger
        else
        {
            //disable
            [triggers toggle:DEVICE_TRIGGER state:NSOffState];
        }
    }
    
    //toggle power triggers
    if(nil != updates[PREF_POWER_TRIGGER])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"toggling power notifications");
        
        //enable power trigger
        if(YES == [updates[PREF_POWER_TRIGGER] boolValue])
        {
            //enable
            [triggers toggle:POWER_TRIGGER state:NSOnState];
        }
        
        //disable power trigger
        else
        {
            //disable
            [triggers toggle:POWER_TRIGGER state:NSOffState];
        }
    }
    
    //sync prefs
    @synchronized(self.preferences)
    {
    
    //updating list of registered devices?
    // it's a dictionary so requires an extra merge
    if( (nil != updates[PREF_REGISTERED_DEVICES]) &&
        (nil != self.preferences[PREF_REGISTERED_DEVICES]) )
    {
        //merge
        [self.preferences[PREF_REGISTERED_DEVICES] addEntriesFromDictionary:updates[PREF_REGISTERED_DEVICES]];
    }
    
    //for all other prefs or for 1st device
    // just merge in new prefs into existing ones
    else
    {
        //merge
        [self.preferences addEntriesFromDictionary:updates];
    }
        
    }//sync
    
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
    //client
    DNDClientMac *client;
    
    //shadow
    MacShadow* macShadow = nil;
    
    //registered devices
    NSMutableDictionary* devices = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"updating registered devices");
    
    //alloc dictionary
    devices = [NSMutableDictionary dictionary];
    
    //aren't any registered devices?
    // just bail
    if(0 == [self.preferences[PREF_REGISTERED_DEVICES] count])
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
    client = [[DNDClientMac alloc] initWithDndIdentity:framework.identity sendCA:YES background:YES taskable:NO];
    if(nil == client)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to initialize client");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, @"asking server for list of registered endpoints...");
    
    //get shadow
    macShadow = [client getShadowSync];
    if(nil == macShadow)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to get mac shadow sync");
        
        //bail
        goto bail;
    }
    
    //sync prefs
    @synchronized(self.preferences)
    {
    
    //get list of registered devices from server
    // build (updated) list of devices id : device name mappings
    for(NSString* deviceID in macShadow.state.reported.endpoints)
    {
        //sanity check
        if(nil == self.preferences[PREF_REGISTERED_DEVICES][deviceID])
        {
            //skip
            continue;
        }
        
        //add current device name
        devices[deviceID] = self.preferences[PREF_REGISTERED_DEVICES][deviceID];
    }
        
    }//sync
    
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
