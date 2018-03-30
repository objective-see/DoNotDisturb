//
//  FrameworkInterface.m
//  launchDaemon
//
//  Created by Patrick Wardle on 3/1/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Preferences.h"
#import "FrameworkInterface.h"

//global prefs obj
extern Preferences* preferences;

@implementation FrameworkInterface

@synthesize identity;

//initialize an identity for DnD comms
// generates client id, etc. and then creates identity
-(BOOL)initIdentity:(BOOL)full
{
    //flag
    BOOL initialized = NO;
    
    //path to digita CA
    NSString* digitaCAPath = nil;
    
    //path to csr
    NSString* csrPath = nil;
    
    //path to aws CA
    NSString* awsCAPath = nil;
    
    //client ID
    NSString* clientID = nil;
    
    //error
    NSError *error = nil;
    
    //csr identity
    DNDIdentity *csrIdentity = nil;
    
    //csr client
    DNDClientCsr *csrClient = nil;
    
    //current preferences
    NSDictionary* currentPrefs = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"initializing DnD identity");
    
    //get all current prefs
    currentPrefs = [preferences get:nil];
    
    //init digita CA path
    digitaCAPath = [[NSBundle mainBundle] pathForResource:@"rootCA" ofType:@"pem"];
    if(nil == digitaCAPath)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to locate Digita's CA path");
        
        //bail
        goto bail;
    }
    
    //init csr path
    csrPath = [[NSBundle mainBundle] pathForResource:@"deviceCSRRequest" ofType:@"p12"];
    if(nil == csrPath)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to locate CSR path");
        
        //bail
        goto bail;
    }
    
    //init AWS CA path
    awsCAPath = [[NSBundle mainBundle] pathForResource:@"awsRootCA" ofType:@"pem"];
    if(nil == awsCAPath)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to locate AWS CA path");
        
        //bail
        goto bail;
    }
    
    //try load client id
    clientID = currentPrefs[PREF_CLIENT_ID];
    
    //already have client id
    // go ahead and try to init identity here
    if(nil != clientID)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"using existing client id: %@", clientID]);
        
        //init
        identity = [[DNDIdentity alloc] init:clientID caPath:digitaCAPath error:&error];
    }
    
    //when not doing full init
    // if we don't have an identify here, bail
    if( (YES != full) &&
        (self.identity == nil) )
    {
        //err msg
        logMsg(LOG_ERR, @"failed to init *existing* DnD identity (full init: false)");
        
        //bail
        goto bail;
    }

    //no client id
    // or (still) need to create identity
    if( (nil == clientID) ||
        (nil == self.identity) )
    {
        //generate
        clientID = [[[NSUUID UUID] UUIDString] lowercaseString];
    
        //alloc init csr identity
        csrIdentity = [[DNDIdentity alloc] init:[[NSUUID UUID] UUIDString] p12Path:csrPath passphrase:CSR_PASSPHRASE caPath:awsCAPath error:&error];
        if( (nil == csrIdentity) ||
            (nil != error) )
        {
            //err msg
            logMsg(LOG_ERR, @"failed to get/create CSR identity");
            
            //bail
            goto bail;
        }
        
        //alloc/init csr client
        csrClient = [[DNDClientCsr alloc] initWithDndIdentity:csrIdentity sendCA:false background:true];
        if(nil == csrClient)
        {
            //err msg
            logMsg(LOG_ERR, @"failed to get/create CSR client");
            
            //bail
            goto bail;
        }
        
        //get (or create) dnd identity
        identity = [csrClient getOrCreateIdentity:clientID caPath:digitaCAPath];
        if(nil == self.identity)
        {
            //err msg
            logMsg(LOG_ERR, @"failed to get/create DND identity");
            
            //bail
            goto bail;
        }
        
        //save client ID
        // also used as indicator that identity was generated
        if(nil == currentPrefs[PREF_CLIENT_ID])
        {
            //save
            [preferences update:@{PREF_CLIENT_ID:clientID}];
        }
    }

    //happy
    initialized = YES;
    
bail:
    
    //don't need this anymore
    if(nil != csrIdentity)
    {
        //delete
        if(YES != [csrIdentity deleteIdentityWithDeleteAssociatedCA:YES])
        {
            //err msg
            logMsg(LOG_ERR, @"failed to delete CSR identity");
        }
        //deleted ok
        else
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"deleted CSR identity");
        }
        
        //unset
        csrIdentity = nil;
    }

    return initialized;
}

@end
