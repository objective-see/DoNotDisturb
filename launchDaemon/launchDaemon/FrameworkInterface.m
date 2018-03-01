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
-(BOOL)initIdentity
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
    
    //init digita CA path
    digitaCAPath = [[NSBundle mainBundle] pathForResource:@"rootCA" ofType:@"pem"];
    if(nil == digitaCAPath)
    {
        //bail
        goto bail;
    }
    
    //init csr path
    csrPath = [[NSBundle mainBundle] pathForResource:@"deviceCSRRequest" ofType:@"p12"];
    if(nil == digitaCAPath)
    {
        //bail
        goto bail;
    }
    
    //init AWS CA path
    awsCAPath = [[NSBundle mainBundle] pathForResource:@"awsRootCA" ofType:@"pem"];
    if(nil == awsCAPath)
    {
        //bail
        goto bail;
    }
    
    //try load client id
    clientID = preferences.preferences[PREF_CLIENT_ID];
    if(nil == clientID)
    {
        //generate
        clientID = [[[NSUUID UUID] UUIDString] lowercaseString];
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"client id: %@", clientID]);
    
    //TODO: passphrase
    //alloc init csr identity
    csrIdentity = [[DNDIdentity alloc] init:clientID p12Path:csrPath passphrase:@"csr" caPath:awsCAPath error:&error];
    if( (nil == csrIdentity) ||
       (nil != error) )
    {
        //err msg
        logMsg(LOG_ERR, @"fail to get/create CSR identity");
        
        //bail
        goto bail;
    }
    
    //alloc/init csr client
    csrClient = [[DNDClientCsr alloc] initWithDndIdentity:csrIdentity sendCA:false background:true];
    if(nil == csrClient)
    {
        //err msg
        logMsg(LOG_ERR, @"fail to get/create CSR client");
        
        //bail
        goto bail;
    }
    
    //get (or create) dnd identity
    identity = [csrClient getOrCreateIdentity:clientID caPath:digitaCAPath];
    if(nil == self.identity)
    {
        //err msg
        logMsg(LOG_ERR, @"fail to get/create DND identity");
        
        //bail
        goto bail;
    }
    
    //save client ID
    // also used as indicator that identity was generated
    [preferences update:@{PREF_CLIENT_ID:clientID}];
    
    //happy
    initialized = YES;
    
bail:
    
    return initialized;
}

@end
