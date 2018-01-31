//
//  file: HelperInterface.m
//  project: (open-source) installer
//  description: interface for app installer comms
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "HelperInterface.h"

#import <signal.h>

//script name
#define CONF_SCRIPT @"configure.sh"

//SIGTERM handler
void sigTerm(int signum);

//signing auth
#define SIGNING_AUTH @"Developer ID Application: Objective-See, LLC (VBG97UB4TA)"

//SIGTERM handler, that's delivered as we're being unloaded
// a) remove plist
// b) remove binary
void sigTerm(int signum)
{
    #pragma unused(signum)
    
    //flag
    BOOL noErrors = YES;
    
    //plist
    NSString* helperPlist = nil;
    
    //binary
    NSString* helperBinary = nil;
    
    //error
    NSError* error = nil;
    
    //dbg msg
    #ifndef NDEBUG
    syslog(LOG_NOTICE, "XPC: got SIGTERM, deleting plist & self");
    #endif
    
    //init path to plist
    helperPlist = [@"/Library/LaunchDaemons" stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", HELPER_ID]];
    
    //delete plist
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:helperPlist error:&error])
    {
        //err msg
        syslog(LOG_ERR, "ERROR: failed to delete %s (%s)", helperPlist.UTF8String, error.description.UTF8String);
        
        //set error
        noErrors = NO;
    }
    
    //init path to binary
    helperBinary = [@"/Library/PrivilegedHelperTools" stringByAppendingPathComponent:HELPER_ID];
    
    //delete self
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:helperBinary error:&error])
    {
        //err msg
        syslog(LOG_ERR, "ERROR: failed to delete %s (%s)", helperBinary.UTF8String, error.description.UTF8String);
        
        //set error
        noErrors = NO;
    }
    
    //no errors?
    //display dbg msg
    #ifndef NDEBUG
    if(YES == noErrors)
    {
        //dbg msg
        syslog(LOG_NOTICE, "removed %s and %s", helperPlist.UTF8String, helperBinary.UTF8String);
    }
    #endif
    
    return;
}

@implementation HelperInterface

//install
// do install logic and return result
-(void)install:(NSString*)app reply:(void (^)(NSNumber*))reply;
{
    //results
    NSNumber* result = nil;
    
    //dbg msg
    #ifndef NDEBUG
    syslog(LOG_NOTICE, "XPC-request: install (%s)", app.UTF8String);
    #endif
    
    //configure
    // pass in 'install' flag
    result = [NSNumber numberWithInt:[self configure:app arguements:@[@"-install"]]];
    
    //reply to client
    reply(result);

    return;
}

//uninstall
// do uninstall logic and return result
-(void)uninstall:(NSString*)app reply:(void (^)(NSNumber*))reply;
{
    //results
    NSNumber* result = nil;
    
    //dbg msg
    #ifndef NDEBUG
    syslog(LOG_NOTICE, "XPC-request: uninstall");
    #endif
    
    //configure
    // pass in 'uninstall' flag
    result = [NSNumber numberWithInt:[self configure:app arguements:@[@"-uninstall"]]];
    
    //reply to client
    reply(result);
    
    return;
}

//configure
// install or uninstall
-(int)configure:(NSString*)app arguements:(NSArray*)args
{
    //result
    int result = -1;
    
    //valdiated (copy) of app
    NSString* validatedApp = nil;
    
    //validate app
    validatedApp = [self validateApp:app];
    if(nil == validatedApp)
    {
        //err msg
        syslog(LOG_ERR, "failed to validate %s", app.UTF8String);
        
        //bail
        goto bail;
    }
    
    //dbg msg
    syslog(LOG_NOTICE, "validated app: %s", validatedApp.UTF8String);
    
    //exec script
    result = [self execScript:validatedApp arguments:args];
    if(noErr != result)
    {
        //err msg
        syslog(LOG_ERR, "failed to execute config script %s (%d)", CONF_SCRIPT.UTF8String, result);
        
        //bail
        goto bail;
    }
    
    //happy
    result = 0;
    
bail:
    
    //always try to remove validated app
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:validatedApp error:nil])
    {
        //err msg
        syslog(LOG_ERR, "failed to remove validated app %s", validatedApp.UTF8String);
        
        //set err
        result = -1;
    }
    
    return result;
}

//remove self
// since system install/launches us as root, client can't directly remove us
-(void)remove
{
    //sig action struct
    struct sigaction action;
    
    //helper plist
    NSString* helperPlist = nil;
    
    //dbg msg
    #ifdef NDEBUG
    syslog(LOG_NOTICE, "XPC-request: remove (self)");
    #endif
    
    //clear
    memset(&action, 0, sizeof(struct sigaction));
    
    //set signal handler
    action.sa_handler = sigTerm;
    
    //install signal handler
    sigaction(SIGTERM, &action, NULL);
    
    //init path to plist
    helperPlist = [@"/Library/LaunchDaemons" stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", HELPER_ID]];
    
    //unload
    execTask(@"/bin/launchctl", @[@"unload", helperPlist], YES);
    
    return;
}

//make copy of app and validate
-(NSString*)validateApp:(NSString*)app
{
    //copy of app
    NSString* appCopy = nil;
    
    //path to (now) validated app
    NSString* validatedApp = nil;
    
    //error
    NSError* error = nil;
    
    //dbg msg
    #ifndef NDEBUG
    syslog(LOG_NOTICE, "validating %s", app.UTF8String);
    #endif
    
    //init path to app copy
    // *root-owned* tmp directory
    appCopy = [NSTemporaryDirectory() stringByAppendingPathComponent:app.lastPathComponent];
    
    //copy app bundle to *root-owned*  directory
    if(YES != [[NSFileManager defaultManager] copyItemAtPath:app toPath:appCopy error:&error])
    {
        //err msg
        syslog(LOG_ERR, "failed to copy %s to %s (error: %s)", app.UTF8String, appCopy.UTF8String, error.description.UTF8String);
        
        //bail
        goto bail;
    }
    
    //TODO: chown
    
    //TODO: verify app
    
    //happy
    validatedApp = appCopy;
    
bail:
    
    return validatedApp;
}

//execute config script
-(int)execScript:(NSString*)validatedApp arguments:(NSArray*)arguments
{
    //result
    int result = -1;
    
    //results
    NSDictionary* results = nil;
    
    //script
    NSString* script = nil;
    
    //app bundle
    NSBundle* appBundle = nil;
    
    //file manager
    NSFileManager* fileManager = nil;
    
    //current working directory
    NSString* currentWorkingDir = nil;
    
    //init file manager
    fileManager = [NSFileManager defaultManager];

    //load app bundle
    appBundle = [NSBundle bundleWithPath:validatedApp];
    if(nil == appBundle)
    {
        //err msg
        syslog(LOG_ERR, "failed to load app bundle for %s", validatedApp.UTF8String);
        
        //bail
        goto bail;
    }
    
    //get path to config script
    script = [[appBundle resourcePath] stringByAppendingPathComponent:CONF_SCRIPT];
    if(nil == script)
    {
        //err msg
        syslog(LOG_ERR, "failed to find config script %s", CONF_SCRIPT.UTF8String);
        
        //bail
        goto bail;
    }
    
    //get current working directory
    currentWorkingDir = [fileManager currentDirectoryPath];
    
    //change working directory
    // set it to (validated) app path's resources
    [fileManager changeCurrentDirectoryPath:[NSString stringWithFormat:@"%@/Contents/Resources/", validatedApp]];
    
    //exec script
    results = execTask(script, arguments, YES);
    
    //grab result
    if(nil != results)
    {
        //grab
        result = [results[EXIT_CODE] intValue];
    }
    
    //(re)set current working directory
    [fileManager changeCurrentDirectoryPath:currentWorkingDir];

bail:
    
    return result;
}

@end
