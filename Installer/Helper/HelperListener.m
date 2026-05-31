//
//  file: HelperListener.m
//  project: (open-source) installer
//  description: XPC listener for connections for user components
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

@import Foundation;

#import "consts.h"
#import "utilities.h"
#import "XPCProtocol.h"
#import "HelperListener.h"
#import "HelperInterface.h"

#import <bsm/libbsm.h>
#import <Security/AuthSession.h>
#import <EndpointSecurity/EndpointSecurity.h>

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//interface for 'extension' to NSXPCConnection
// allows us to access the 'private' auditToken iVar
@interface ExtendedNSXPCConnection : NSXPCConnection
{
    //private iVar
    audit_token_t auditToken;
}
//private iVar
@property audit_token_t auditToken;

@end

//implementation for 'extension' to NSXPCConnection
// ->allows us to access the 'private' auditToken iVar
@implementation ExtendedNSXPCConnection

//private iVar
@synthesize auditToken;

@end

@implementation HelperListener

@synthesize listener;

//init
// create XPC listener
-(id)init
{
    //init super
    self = [super init];
    if(nil != self)
    {
        //setup XPC listener
        if(YES != [self initListener])
        {
            //unset
            self =  nil;
            
            //bail
            goto bail;
        }
    }
    
bail:
    
    return self;
}

//setup XPC listener
-(BOOL)initListener
{
    //result
    BOOL result = NO;
    
    //requirement
    NSString* requirement = nil;
    
    //init listener
    listener = [[NSXPCListener alloc] initWithMachServiceName:CONFIG_HELPER_ID];
    if(!self.listener) {
        os_log_error(logHandle, "ERROR: failed to create mach service %{public}@", CONFIG_HELPER_ID);
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "created mach service %{public}@", CONFIG_HELPER_ID);
    
    //macOS 13+
    // set code signing requirement for clients via 'setConnectionCodeSigningRequirement'
    if(@available(macOS 13.0, *)) {
        
        //init requirement
        requirement = [NSString stringWithFormat:@"anchor apple generic and identifier \"%@\" and certificate leaf [subject.CN] = \"%@\" and info [CFBundleShortVersionString] >= \"2.1.0\"", INSTALLER_ID, SIGNING_AUTH];
        
        //set requirement
        [self.listener setConnectionCodeSigningRequirement:requirement];
        
        //dbg msg
        os_log_debug(logHandle, "set XPC requirement %{public}@", requirement);
        
    }
    
    //set delegate
    self.listener.delegate = self;
    
    //ready to accept connections
    [self.listener resume];
    
    //happy
    result = YES;
    
bail:
    
    return result;
}

#pragma mark -
#pragma mark NSXPCConnection method overrides

//automatically invoked
// allows NSXPCListener to configure/accept/resume a new incoming NSXPCConnection
// shoutout to writeup: https://blog.obdev.at/what-we-have-learned-from-a-vulnerability
-(BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    //flag
    BOOL shouldAccept = NO;
    
    //status
    OSStatus status = !errSecSuccess;
    
    //os version
    NSOperatingSystemVersion macOS13 = {13,0,0};
    
    //audit token
    audit_token_t auditToken = {0};
    
    //task ref
    SecTaskRef taskRef = 0;
    
    //code ref
    SecCodeRef codeRef = NULL;
    
    //code signing info
    CFDictionaryRef csInfo = NULL;
    
    //cs flags
    uint32_t csFlags = 0;
    
    //signing req string (main app)
    NSString* requirement = nil;
    
    //dbg msg
    os_log_debug(logHandle, "'%s' invoked", __PRETTY_FUNCTION__);
    
    //pre-macOS 13
    // have to manually check client, as 'setConnectionCodeSigningRequirement' is not supported
    if(YES != [NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:macOS13])
    {
        //extract audit token
        auditToken = ((ExtendedNSXPCConnection*)newConnection).auditToken;
        
        //dbg msg
        os_log_debug(logHandle, "received request to connect to XPC interface from: (%d)%{public}@", audit_token_to_pid(auditToken), getProcessPath(audit_token_to_pid(auditToken)));
        
        //obtain dynamic code ref
        status = SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef _Nullable)(@{(__bridge NSString *)kSecGuestAttributeAudit : [NSData dataWithBytes:&auditToken length:sizeof(audit_token_t)]}), kSecCSDefaultFlags, &codeRef);
        if(errSecSuccess != status) {
            goto bail;
        }
        
        //validate code
        status = SecCodeCheckValidity(codeRef, kSecCSDefaultFlags, NULL);
        if(errSecSuccess != status) {
            goto bail;
        }
        
        //get code signing info
        status = SecCodeCopySigningInformation(codeRef, kSecCSDynamicInformation, &csInfo);
        if(errSecSuccess != status) {
            goto bail;
        }
        
        //dbg msg
        os_log_debug(logHandle, "client's code signing info: %{public}@", csInfo);
        
        //extract flags
        csFlags = [((__bridge NSDictionary *)csInfo)[(__bridge NSString *)kSecCodeInfoStatus] unsignedIntValue];
        
        //gotta have hardened runtime
        if( !(csFlags & CS_VALID) ||
            !(csFlags & CS_RUNTIME) ) {
            goto bail;
        }
        
        //init signing req string
        requirement = [NSString stringWithFormat:@"anchor apple generic and identifier \"%@\" and certificate leaf [subject.CN] = \"%@\" and info [CFBundleShortVersionString] >= \"2.1.0\"", INSTALLER_ID, SIGNING_AUTH];
        
        //step 1: create task ref
        // uses NSXPCConnection's (private) 'auditToken' iVar
        taskRef = SecTaskCreateWithAuditToken(NULL, ((ExtendedNSXPCConnection*)newConnection).auditToken);
        if(NULL == taskRef) {
            goto bail;
        }
        
        //step 2: validate
        // check that client is signed with Objective-See's and it's DND's helper
        status = SecTaskValidateForRequirement(taskRef, (__bridge CFStringRef)(requirement));
        if(errSecSuccess != status) {
            os_log_error(logHandle, "SecTaskValidateForRequirement failed with %d", status);
            goto bail;
        }
        
        //dbg msg
        os_log_debug(logHandle, "client is trusted...");
    }
    
    //set the interface that the exported object implements
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XPCProtocol)];
    
    //set object exported by connection
    newConnection.exportedObject = [[HelperInterface alloc] init];
    
    //resume
    [newConnection resume];
    
    //dbg msg
    os_log_debug(logHandle, "allowing XPC connection from client (pid: %d)", audit_token_to_pid(auditToken));
    
    //happy
    shouldAccept = YES;
    
bail:
    
    //release task ref object
    if(NULL != taskRef)
    {
        //release
        CFRelease(taskRef);
        taskRef = NULL;
    }
    
    //free cs info
    if(NULL != csInfo)
    {
        //free
        CFRelease(csInfo);
        csInfo = NULL;
    }
    
    //free code ref
    if(NULL != codeRef)
    {
        //free
        CFRelease(codeRef);
        codeRef = NULL;
    }
    
    return shouldAccept;
}

@end
