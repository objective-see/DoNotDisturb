//
//  Configure.m
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Configure.h"
#import "Utilities.h"

#import <Foundation/Foundation.h>
#import <Security/Authorization.h>
#import <ServiceManagement/ServiceManagement.h>

@implementation Configure

@synthesize gotHelp;
@synthesize xpcComms;

//invokes appropriate install || uninstall logic
-(BOOL)configure:(NSInteger)parameter
{
    //return var
    BOOL wasConfigured = NO;
    
    //get help
    if(YES != [self initHelper])
    {
        //err msg
        syslog(LOG_ERR, "ERROR: failed to init helper tool");
        
        //bail
        goto bail;
    }
    
    //install extension
    if(ACTION_INSTALL_FLAG == parameter)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"installing...");
        
        //already installed?
        // perform partial uninstall
        if(YES == [self isInstalled])
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"already installed, so uninstalling (partially)...");
            
            //uninstall
            // but do partial
            if(YES != [self uninstall:UNINSTALL_PARTIAL])
            {
                //bail
                goto bail;
            }
            
            //dbg msg
            logMsg(LOG_DEBUG, @"uninstalled");
        }
        
        //install
        if(YES != [self install])
        {
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"installed!");
        
    }
    //uninstall extension
    else if(ACTION_UNINSTALL_FLAG == parameter)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"uninstalling...");
        
        //uninstall
        // do full to remove all
        if(YES != [self uninstall:UNINSTALL_FULL])
        {
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"uninstalled!");
    }

    //no errors
    wasConfigured = YES;
    
bail:
    
    return wasConfigured;
}

//determine if installed
// simply checks if extension binary exists
-(BOOL)isInstalled
{
    //flag
    BOOL installed = NO;
    
    //launch daemon
    NSString* launchDaemon = nil;
    
    //launch daemon plist
    NSString* launchDaemonPlist = nil;
    
    //app path
    NSString* appPath = nil;
    
    //init path to launch daemon
    launchDaemon = [INSTALL_DIRECTORY stringByAppendingPathComponent:LAUNCH_DAEMON_BINARY];
    
    //init path to launch daemon plist
    launchDaemonPlist = [@"/Library/LaunchDaemons" stringByAppendingPathComponent:LAUNCH_DAEMON_PLIST];
    
    //init path to app
    appPath = [@"/Applications" stringByAppendingPathComponent:APP_NAME];
    
    //check for installed components
    installed = ( (YES == [[NSFileManager defaultManager] fileExistsAtPath:appPath]) ||
                  (YES == [[NSFileManager defaultManager] fileExistsAtPath:launchDaemon]) ||
                  (YES == [[NSFileManager defaultManager] fileExistsAtPath:launchDaemonPlist]) );
    
    return installed;
}

//init helper tool
// install and establish XPC connection
-(BOOL)initHelper
{
    //bail if we're already G2G
    if(YES == self.gotHelp)
    {
        //all set
        goto bail;
    }
    
    //install
    if(YES != [self blessHelper])
    {
        //err msg
        syslog(LOG_ERR, "ERROR: failed to install helper tool");
        
        //bail
        goto bail;
    }
    
    //init XPC comms
    xpcComms = [[HelperComms alloc] init];
    if(nil == xpcComms)
    {
        //err msg
        syslog(LOG_ERR, "ERROR: failed to connect to helper tool");
        
        //bail
        goto bail;
    }
    
    //happy
    self.gotHelp = YES;
    
bail:
    
    return self.gotHelp;
}

//install helper tool
// sets 'wasBlessed' iVar
-(BOOL)blessHelper
{
    //flag
    BOOL wasBlessed = NO;
    
    //auth ref
    AuthorizationRef authRef = NULL;
    
    //error
    CFErrorRef error = NULL;
    
    //auth item
    AuthorizationItem authItem = {};
    
    //auth rights
    AuthorizationRights authRights = {};
    
    //auth flags
    AuthorizationFlags authFlags = 0;
    
    //create auth
    if(errAuthorizationSuccess != AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authRef))
    {
        //err msg
        syslog(LOG_ERR, "ERROR: failed to create authorization");
        
        //bail
        goto bail;
    }
    
    //init auth item
    memset(&authItem, 0x0, sizeof(authItem));
    
    //set name
    authItem.name = kSMRightBlessPrivilegedHelper;
    
    //set auth count
    authRights.count = 1;
    
    //set auth items
    authRights.items = &authItem;
    
    //init flags
    authFlags =  kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    
    //get auth rights
    if(errAuthorizationSuccess != AuthorizationCopyRights(authRef, &authRights, kAuthorizationEmptyEnvironment, authFlags, NULL))
    {
        //err msg
        syslog(LOG_ERR, "ERROR: failed to copy authorization rights");
        
        //bail
        goto bail;
    }
    
    //bless
    if(YES != (BOOL)SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)(INSTALLER_HELPER_ID), authRef, &error))
    {
        //err msg
        syslog(LOG_ERR, "ERROR: failed to bless job (%s)", ((__bridge NSError*)error).description.UTF8String);
        
        //bail
        goto bail;
    }
    
    //happy
    wasBlessed = YES;
    
bail:
    
    //free auth ref
    if(NULL != authRef)
    {
        //free
        AuthorizationFree(authRef, kAuthorizationFlagDefaults);
        
        //unset
        authRef = NULL;
    }
    
    //free error
    if(NULL != error)
    {
        //release
        CFRelease(error);
        
        //unset
        error = NULL;
    }
    
    return wasBlessed;
}

//remove helper (daemon)
-(void)removeHelper
{
    //if needed
    // tell helper to remove itself
    if(YES == self.gotHelp)
    {
        //dbg msg
        syslog(LOG_NOTICE, "invoking XPC method: remove");
        
        //remove
        [self.xpcComms remove];
    }
    
    return;
}

//install
-(BOOL)install
{
    //return/status var
    __block BOOL wasInstalled = NO;
    
    //wait semaphore
    dispatch_semaphore_t semaphore = 0;
    
    //init sema
    semaphore = dispatch_semaphore_create(0);
    
    //define block
    void (^block)(NSNumber *) = ^(NSNumber *result)
    {
        //callback from XPC will be a bg thread
        // so since we're updating UI, invoke on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //signal sema
            dispatch_semaphore_signal(semaphore);
            
            //save result
            wasInstalled = (BOOL)(result.intValue == 0);
            
        });
    };
    
    //install
    [xpcComms install:block];
    
    //wait for install to be completed by XPC
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    return wasInstalled;
}

//uninstall
-(BOOL)uninstall:(BOOL)full
{
    //return/status var
    __block BOOL wasUninstalled = NO;
    
    //wait semaphore
    dispatch_semaphore_t semaphore = 0;
    
    //init sema
    semaphore = dispatch_semaphore_create(0);
    
    //define block
    void (^block)(NSNumber *) = ^(NSNumber *result)
    {
        //callback from XPC will be a bg thread
        // so since we're updating UI, invoke on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            
            //signal sema
            dispatch_semaphore_signal(semaphore);
            
            //save result
            wasUninstalled = (BOOL)(result.intValue == 0);
            
        });
    };
    
    //install
    [xpcComms uninstall:full reply:block];
    
    //wait for install to be completed by XPC
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    return wasUninstalled;
}

@end
