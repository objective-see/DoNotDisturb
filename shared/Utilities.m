//
//  file: utilities.m
//  project: DoNotDisturb (shared)
//  description: various helper/utility functions
//
//  created by Patrick Wardle
//  copyright (c) 2026 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"

#import <dlfcn.h>
#import <signal.h>
#import <unistd.h>
#import <libproc.h>
#import <sys/stat.h>
#import <bsm/libbsm.h>
#import <sys/sysctl.h>
#import <Carbon/Carbon.h>
#import <Security/Security.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import <IOKit/IOKitLib.h>
#import <IOKit/pwr_mgt/IOPM.h>
#import <CommonCrypto/CommonDigest.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <SystemConfiguration/SystemConfiguration.h>


#ifndef DAEMON_BUILD
#import "AppDelegate.h"
#endif

@import OSLog;

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//get app's version
// extracted from Info.plist
NSString* getAppVersion(void)
{
    //read and return 'CFBundleVersion' from bundle
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
}

//check if we're running on a laptop
BOOL isLaptop(void)
{
    BOOL laptop = NO;
    
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPMrootDomain"));
    if(!service) {
        return NO;
    }
    
    CFTypeRef clamshell = IORegistryEntryCreateCFProperty(service, CFSTR("AppleClamshellState"), kCFAllocatorDefault, 0);
    if(clamshell) {
        
        //property exists: we're on a laptop
        laptop = YES;
        CFRelease(clamshell);
    }
    
    IOObjectRelease(service);
    
    return laptop;
}

//get state of lid
int getLidState(void)
{
    //state
    int state = stateUnavailable;
    
    //registry entry for power management
    io_registry_entry_t powerManagmentRE = MACH_PORT_NULL;
    
    //reference to 'kAppleClamshellStateKey' property
    CFBooleanRef clamshellState = NULL;
    
    //get registry entry for power management root domain
    powerManagmentRE = IORegistryEntryFromPath(kIOMasterPortDefault, kIOPowerPlane ":/IOPowerConnection/IOPMrootDomain");
    if(MACH_PORT_NULL == powerManagmentRE)
    {
        //err msg
        os_log_error(logHandle, "failed to look up the registry entry for 'IOPMrootDomain'");
        
        //error
        goto bail;
    }
    
    //get reference to state of 'kAppleClamshellStateKey'
    clamshellState = (CFBooleanRef)IORegistryEntryCreateCFProperty(powerManagmentRE, CFSTR(kAppleClamshellStateKey), kCFAllocatorDefault, 0);
    if(NULL == clamshellState)
    {
        //err msg
        os_log_error(logHandle, "failed to get property for 'kAppleClamshellStateKey'");
        
        //error
        goto bail;
    }
    
    //get state
    state = (LidState)CFBooleanGetValue(clamshellState);
    
bail:
    
    //release
    if(NULL != clamshellState)
    {
        //release
        CFRelease(clamshellState);
        
        //unset
        clamshellState = NULL;
    }
    
    //release
    if(MACH_PORT_NULL != powerManagmentRE)
    {
        //release
        IOObjectRelease(powerManagmentRE);
        
        //unset
        powerManagmentRE = MACH_PORT_NULL;
    }
    
    return state;
}

//given an app binary
// try get app's bundle
NSBundle* getAppBundle(NSString* binaryPath)
{
    //bundle
    NSBundle* appBundle = nil;
    
    //app path
    NSString* appPath = nil;
    
    //build app path
    // assuming path is <blah.app>/Contents/MacOS/<blah>
    appPath = [[[binaryPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    if(YES != [appPath hasSuffix:@".app"])
    {
        //bail
        goto bail;
    }
    
    //try to load app's bundle
    appBundle = [NSBundle bundleWithPath:appPath];
    if(nil == appBundle)
    {
        //bail
        goto bail;
    }
    
    //sanity check
    // binary paths match?
    if(YES != [appBundle.executablePath isEqualToString:binaryPath])
    {
        //unset
        appBundle = nil;
        goto bail;
    }
    
bail:
    
    return appBundle;
}

//get binary name (maybe via bundle name)
NSString* getBinaryName(NSString* path)
{
    return [getAppBundle(path) infoDictionary][@"CFBundleName"] ?: [path lastPathComponent];
}

//get path to (main) app of a login item
// login item is in app bundle, so parse up to get main app
NSString* getMainAppPath(void)
{
    //path components
    NSArray *pathComponents = nil;
    
    //path to config (main) app
    NSString* mainApp = nil;
    
    //get path components
    // then build full path to main app
    pathComponents = [[[NSBundle mainBundle] bundlePath] pathComponents];
    if(pathComponents.count > 4)
    {
        //init path to full (main) app
        mainApp = [NSString pathWithComponents:[pathComponents subarrayWithRange:NSMakeRange(0, pathComponents.count - 4)]];
    }
    
    //when (still) nil
    // use default path
    if(nil == mainApp)
    {
        //default
        mainApp = [@"/Applications" stringByAppendingPathComponent:APP_NAME];
    }
    
    return mainApp;
}

//give path to app
// get full path to its binary
NSString* getBundleExecutable(NSString* appPath)
{
    //binary path
    NSString* binaryPath = nil;
    
    //app bundle
    NSBundle* appBundle = nil;
    
    //load app bundle
    appBundle = [NSBundle bundleWithPath:appPath];
    if(nil == appBundle)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to load app bundle for %{public}@", appPath);
        
        //bail
        goto bail;
    }
    
    //extract executable
    binaryPath = [appBundle.executablePath stringByResolvingSymlinksInPath];
    
bail:
    
    return binaryPath;
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

//get (true) parent
NSDictionary* getRealParent(pid_t pid)
{
    //process info
    NSDictionary* processInfo = nil;
    
    //process serial number
    ProcessSerialNumber psn = {0, kNoProcess};
    
    //(parent) process serial number
    ProcessSerialNumber ppsn = {0, kNoProcess};
    
    //get process serial number from pid
    if(noErr != GetProcessForPID(pid, &psn))
    {
        //err
        goto bail;
    }
    
    //get process (carbon) info
    processInfo = CFBridgingRelease(ProcessInformationCopyDictionary(&psn, (UInt32)kProcessDictionaryIncludeAllInformationMask));
    if(nil == processInfo)
    {
        //err
        goto bail;
    }
    
    //extract/convert parent ppsn
    ppsn.lowLongOfPSN =  [processInfo[@"ParentPSN"] longLongValue] & 0x00000000FFFFFFFFLL;
    ppsn.highLongOfPSN = ([processInfo[@"ParentPSN"] longLongValue] >> 32) & 0x00000000FFFFFFFFLL;
    
    //get parent process (carbon) info
    processInfo = CFBridgingRelease(ProcessInformationCopyDictionary(&ppsn, (UInt32)kProcessDictionaryIncludeAllInformationMask));
    if(nil == processInfo)
    {
        //err
        goto bail;
    }
    
bail:
    
    return processInfo;
}

#pragma GCC diagnostic pop



//check if something is nil
// if so, return a default ('unknown') value
NSString* valueForStringItem(NSString* item)
{
    return (nil != item) ? item : @"unknown";
}

//verify that an app bundle is valid
// signed & with (our) signing auth / identifier
OSStatus verifyApp(NSString* path, NSString* signingAuth)
{
    //status
    OSStatus status = !noErr;
    
    //signing req string
    NSString *requirement = nil;
    
    //code
    SecStaticCodeRef staticCode = NULL;
    
    //signing reqs
    SecRequirementRef requirementRef = NULL;
    
    //init signing req string
    requirement = [NSString stringWithFormat:@"anchor apple generic and identifier \"%@\" and certificate leaf [subject.CN] = \"%@\" and info [CFBundleShortVersionString] >= \"2.1.0\"", INSTALLER_ID, signingAuth];
    
    //create static code
    status = SecStaticCodeCreateWithPath((__bridge CFURLRef)([NSURL fileURLWithPath:path]), kSecCSDefaultFlags, &staticCode);
    if(noErr != status)
    {
        //err msg
        os_log_error(logHandle, "ERROR: 'SecStaticCodeCreateWithPath' failed with %d/%#x", status, status);
        goto bail;
    }
    
    //create req string
    status = SecRequirementCreateWithString((__bridge CFStringRef _Nonnull)(requirement), kSecCSDefaultFlags, &requirementRef);
    if( (noErr != status) ||
       (requirementRef == NULL) )
    {
        //err msg
        os_log_error(logHandle, "ERROR: 'SecRequirementCreateWithString' failed with %d/%#x", status, status);
        goto bail;
    }
    
    //check if file is signed w/ apple dev id by checking if it conforms to req string
    status = SecStaticCodeCheckValidity(staticCode, kSecCSDefaultFlags, requirementRef);
    if(noErr != status)
    {
        os_log_error(logHandle, "ERROR: 'SecStaticCodeCheckValidity failed with %d/%#x", status, status);
        goto bail;
    }
    
    //happy
    status = noErr;
    
bail:
    
    //free req reference
    if(NULL != requirementRef)
    {
        //free
        CFRelease(requirementRef);
        requirementRef = NULL;
    }
    
    //free static code
    if(NULL != staticCode)
    {
        //free
        CFRelease(staticCode);
        staticCode = NULL;
    }
    
    return status;
}


//get process name
// either via app bundle, or path
NSString* getProcessName(NSString* path)
{
    //process name
    NSString* processName = nil;
    
    //app bundle
    NSBundle* appBundle = nil;
    
    //try find an app bundle
    appBundle = findAppBundle(path);
    if(nil != appBundle)
    {
        //grab name from app's bundle
        processName = [appBundle infoDictionary][@"CFBundleName"];
    }
    
    //still nil?
    // ->just grab from path
    if(nil == processName)
    {
        //from path
        processName = [path lastPathComponent];
    }
    
    return processName;
}

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* path)
{
    //app's bundle
    NSBundle* appBundle = nil;
    
    //standarized path
    NSString* standardedPath = nil;
    
    //app's path
    NSString* appPath = nil;
    
    //standardize path
    standardedPath = [[path stringByStandardizingPath] stringByResolvingSymlinksInPath];
    
    //first just try full path
    appPath = standardedPath;
    
    //try to find the app's bundle
    do
    {
        //try to load app's bundle
        appBundle = [NSBundle bundleWithPath:appPath];
        
        //was an app passed in?
        if(YES == [appBundle.bundlePath isEqualToString:standardedPath])
        {
            //all done
            break;
        }
        
        //check for match
        // binary path's match
        if( (nil != appBundle) &&
            (YES == [appBundle.executablePath isEqualToString:standardedPath]))
        {
            //all done
            break;
        }
        
        //unset
        appBundle = nil;
        
        //remove last part
        // will try this next
        appPath = [appPath stringByDeletingLastPathComponent];
        
    //scan until we get to root
    // of course, loop will exit if app info dictionary is found/loaded
    } while( (nil != appPath) &&
             (YES != [appPath isEqualToString:@"/"]) &&
             (YES != [appPath isEqualToString:@""]) );
    
    return appBundle;
}

//set dir's|file's group/owner
BOOL setFileOwner(NSString* path, NSNumber* groupID, NSNumber* ownerID, BOOL recursive)
{
    //ret var
    BOOL bSetOwner = NO;
    
    //owner dictionary
    NSDictionary* fileOwner = nil;
    
    //sub paths
    NSArray* subPaths = nil;
    
    //full path
    // ->for recursive
    NSString* fullPath = nil;
    
    //init permissions dictionary
    fileOwner = @{NSFileGroupOwnerAccountID:groupID, NSFileOwnerAccountID:ownerID};
    
    //set group/owner
    if(YES != [[NSFileManager defaultManager] setAttributes:fileOwner ofItemAtPath:path error:NULL])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to set ownership for %{public}@ (%{public}@)", path, fileOwner);
        goto bail;
    }
    
    //dbg msg
    os_log_debug(logHandle, "set ownership for %{public}@ (%{public}@)", path, fileOwner);
    
    //do it recursively
    if(YES == recursive)
    {
        //sanity check
        // ->make sure root starts with '/'
        if(YES != [path hasSuffix:@"/"])
        {
            //add '/'
            path = [NSString stringWithFormat:@"%@/", path];
        }
        
        //get all subpaths
        subPaths = [[NSFileManager defaultManager] subpathsAtPath:path];
        for(NSString *subPath in subPaths)
        {
            //init full path
            fullPath = [path stringByAppendingString:subPath];
            
            //set group/owner
            if(YES != [[NSFileManager defaultManager] setAttributes:fileOwner ofItemAtPath:fullPath error:NULL])
            {
                //err msg
                os_log_error(logHandle, "ERROR: failed to set ownership for %{public}@ (%{public}@)", fullPath, fileOwner);
                goto bail;
            }
        }
    }
    
    //no errors
    bSetOwner = YES;
    
//bail
bail:
    
    return bSetOwner;
}

//set permissions for file
BOOL setFilePermissions(NSString* file, int permissions, BOOL recursive)
{
    //ret var
    BOOL bSetPermissions = NO;
    
    //file permissions
    NSDictionary* filePermissions = nil;
    
    //root directory
    NSURL* root = nil;
    
    //directory enumerator
    NSDirectoryEnumerator* enumerator = nil;
    
    //error
    NSError* error = nil;
    
    //init dictionary
    filePermissions = @{NSFilePosixPermissions: [NSNumber numberWithInt:permissions]};
    
    //apply file permissions recursively
    if(YES == recursive)
    {
        //init root
        root = [NSURL fileURLWithPath:file];
        
        //init enumerator
        enumerator = [[NSFileManager defaultManager] enumeratorAtURL:root includingPropertiesForKeys:[NSArray arrayWithObject:NSURLIsDirectoryKey] options:0 errorHandler:nil];
    
        //set file permissions on each
        for(NSURL* currentFile in enumerator)
        {
            //set permissions
            if(YES != [[NSFileManager defaultManager] setAttributes:filePermissions ofItemAtPath:currentFile.path error:&error])
            {
                //err msg
                os_log_error(logHandle, "ERROR: failed to set permissions for %{public}@ (%{public}@), %{public}@", currentFile.path, filePermissions, error);
                goto bail;
            }
        }
    }
    
    //always set permissions on passed in file (or top-level directory)
    // note: recursive enumerator skips root directory, so execute this always
    if(YES != [[NSFileManager defaultManager] setAttributes:filePermissions ofItemAtPath:file error:NULL])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to set permissions for %{public}@ (%{public}@)", file, filePermissions);
        goto bail;
    }
    
    //happy
    bSetPermissions = YES;
    
bail:
    
    return bSetPermissions;
}

//get process's path
NSString* getProcessPath(pid_t pid)
{
    //task path
    NSString* processPath = nil;
    
    //buffer for process path
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE] = {0};
    
    //status
    int status = -1;
    
    //'management info base' array
    int mib[3] = {0};
    
    //system's size for max args
    unsigned long systemMaxArgs = 0;
    
    //process's args
    char* taskArgs = NULL;
    
    //# of args
    int numberOfArgs = 0;
    
    //size of buffers, etc
    size_t size = 0;
    
    //reset buffer
    memset(pathBuffer, 0x0, PROC_PIDPATHINFO_MAXSIZE);
    
    //first attempt to get path via 'proc_pidpath()'
    status = proc_pidpath(pid, pathBuffer, sizeof(pathBuffer));
    if(0 != status)
    {
        //init task's name
        processPath = [NSString stringWithUTF8String:pathBuffer];
    }
    //otherwise
    // try via task's args ('KERN_PROCARGS2')
    else
    {
        //init mib
        // ->want system's size for max args
        mib[0] = CTL_KERN;
        mib[1] = KERN_ARGMAX;
        
        //set size
        size = sizeof(systemMaxArgs);
        
        //get system's size for max args
        if(-1 == sysctl(mib, 2, &systemMaxArgs, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //alloc space for args
        taskArgs = malloc(systemMaxArgs);
        if(NULL == taskArgs)
        {
            //bail
            goto bail;
        }
        
        //init mib
        // ->want process args
        mib[0] = CTL_KERN;
        mib[1] = KERN_PROCARGS2;
        mib[2] = pid;
        
        //set size
        size = (size_t)systemMaxArgs;
        
        //get process's args
        if(-1 == sysctl(mib, 3, taskArgs, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //sanity check
        // ensure buffer is somewhat sane
        if(size <= sizeof(int))
        {
            //bail
            goto bail;
        }
        
        //extract number of args
        memcpy(&numberOfArgs, taskArgs, sizeof(numberOfArgs));
        
        //extract task's name
        // follows # of args (int) and is NULL-terminated
        processPath = [NSString stringWithUTF8String:taskArgs + sizeof(int)];
    }
    
bail:
    
    //free process args
    if(NULL != taskArgs)
    {
        //free
        free(taskArgs);
        
        //reset
        taskArgs = NULL;
    }
    
    return processPath;
}

//given a process path and user
// return array of all matching pids
NSMutableArray* getProcessIDs(NSString* processPath, int userID)
{
    //status
    int status = -1;
    
    //process IDs
    NSMutableArray* processIDs = nil;
    
    //# of procs
    int numberOfProcesses = 0;
        
    //array of pids
    pid_t* pids = NULL;
    
    //process info struct
    struct kinfo_proc procInfo;
    
    //size of struct
    size_t procInfoSize = sizeof(procInfo);
    
    //mib
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, -1};
    
    //clear buffer
    memset(&procInfo, 0x0, procInfoSize);
    
    //get # of procs
    numberOfProcesses = proc_listallpids(NULL, 0);
    if(-1 == numberOfProcesses)
    {
        //bail
        goto bail;
    }
    
    //alloc buffer for pids
    pids = calloc((unsigned long)numberOfProcesses, sizeof(pid_t));
    
    //alloc
    processIDs = [NSMutableArray array];
    
    //get list of pids
    status = proc_listallpids(pids, numberOfProcesses * (int)sizeof(pid_t));
    if(status < 0)
    {
        //bail
        goto bail;
    }
        
    //iterate over all pids
    // ->get name for each process
    for(int i = 0; i < (int)numberOfProcesses; i++)
    {
        //skip blank pids
        if(0 == pids[i])
        {
            //skip
            continue;
        }
        
        //skip if path doesn't match
        if(YES != [processPath isEqualToString:getProcessPath(pids[i])])
        {
            //next
            continue;
        }
        
        //need to also match on user?
        // caller can pass in -1 to skip this check
        if(-1 != userID)
        {
            //init mib
            mib[0x3] = pids[i];
            
            //make syscall to get proc info for user
            if( (0 != sysctl(mib, 0x4, &procInfo, &procInfoSize, NULL, 0)) ||
                (0 == procInfoSize) )
            {
                //skip
                continue;
            }

            //skip if user id doesn't match
            if(userID != (int)procInfo.kp_eproc.e_ucred.cr_uid)
            {
                //skip
                continue;
            }
        }
        
        //got match
        // add to list
        [processIDs addObject:[NSNumber numberWithInt:pids[i]]];
    }
    
bail:
        
    //free buffer
    if(NULL != pids)
    {
        //free
        free(pids);
        
        //reset
        pids = NULL;
    }
    
    return processIDs;
}

//enable/disable a menu
void toggleMenu(NSMenu* menu, BOOL shouldEnable)
{
    //disable autoenable
    menu.autoenablesItems = NO;
    
    //iterate over
    // set state of each item
    for(NSMenuItem* item in menu.itemArray)
    {
        //set state
        item.enabled = shouldEnable;
    }
    
    return;
}

//get icon for a process
NSImage* getIconForProcess(NSString* path)
{
    NSImage* icon = nil;

    //prefer the app's icon
    NSBundle *appBundle = findAppBundle(path);
    if(appBundle) {
        icon = [NSWorkspace.sharedWorkspace iconForFile:appBundle.bundlePath];
    }

    //otherwise, generic executable icon
    if(!icon) {
        if(@available(macOS 11.0, *)) {
            icon = [NSWorkspace.sharedWorkspace iconForContentType:UTTypeUnixExecutable];
        } else {
            icon = [NSWorkspace.sharedWorkspace iconForFileType:@"public.unix-executable"];
        }
    }

    [icon setSize:NSMakeSize(128, 128)];
    return icon;
}



//delete item from keychain
BOOL deleteFromKeychain(NSString* key) {
    
    //status
    OSStatus status = errSecSuccess;
    
    //query
    NSDictionary* query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: @"com.objective-see.donotdisturb.telegram",
        (__bridge id)kSecAttrAccount: key
    };
    
    //delete
    status = SecItemDelete((__bridge CFDictionaryRef)query);
    if(errSecSuccess != status)
    {
        //not found / not accessible is fine
        // just means user hasn't configured Telegram (or item is owned by another process)
        os_log_debug(logHandle, "deleteFromKeychain: %{public}@ (status: %d)", key, (int)status);
        return NO;
    }
    
    return YES;
}

//for login item enable/disable
// we use the launch services APIs, since replacements don't always work :(
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

//toggle login item
// either add (install) or remove (uninstall)
BOOL toggleLoginItem(NSURL* loginItem, int toggleFlag)
{
    //flag
    BOOL wasToggled = NO;
    
    //login item ref
    LSSharedFileListRef loginItemsRef = NULL;
    
    //login items
    CFArrayRef loginItems = NULL;
    
    //current login item
    CFURLRef currentLoginItem = NULL;
    
    //get reference to login items
    loginItemsRef = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if(!loginItemsRef) {
        os_log_error(logHandle, "ERROR: failed to get login items reference");
        goto bail;
    }
    
    //add (install)
    if(ACTION_INSTALL_FLAG == toggleFlag)
    {
        //dbg msg
        os_log_debug(logHandle, "adding login item %{public}@", loginItem);
        
        //add
        LSSharedFileListItemRef itemRef = LSSharedFileListInsertItemURL(loginItemsRef, kLSSharedFileListItemLast, NULL, NULL, (__bridge CFURLRef)(loginItem), NULL, NULL);
        
        //release item ref
        if(NULL != itemRef)
        {
            //dbg msg
            os_log_debug(logHandle, "added %{public}@/%{public}@", loginItem, itemRef);
            
            //release
            CFRelease(itemRef);
            
            //reset
            itemRef = NULL;
        }
        //failed
        else
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to add login item");
            goto bail;
        }
        
        //happy
        wasToggled = YES;
    }
    //remove (uninstall)
    else
    {
        //dbg msg
        os_log_debug(logHandle, "removing login item %{public}@", loginItem);
        
        //grab existing login items
        loginItems = LSSharedFileListCopySnapshot(loginItemsRef, nil);
        
        //iterate over all login items
        // look for self, then remove it
        for(id item in (__bridge NSArray *)loginItems)
        {
            //get current login item
            currentLoginItem = LSSharedFileListItemCopyResolvedURL((__bridge LSSharedFileListItemRef)item, 0, NULL);
            if(NULL == currentLoginItem)
            {
                //skip
                continue;
            }
            
            //current login item match self?
            if(YES == [(__bridge NSURL *)currentLoginItem isEqual:loginItem])
            {
                //remove
                if(noErr != LSSharedFileListItemRemove(loginItemsRef, (__bridge LSSharedFileListItemRef)item))
                {
                    //err msg
                    os_log_error(logHandle, "ERROR: failed to remove login item");
                    
                    //bail
                    goto bail;
                }
                
                //dbg msg
                os_log_debug(logHandle, "removed login item: %{public}@", loginItem);
                
                //happy
                wasToggled = YES;
                
                //all done
                goto bail;
            }
            
            //release
            CFRelease(currentLoginItem);
            
            //reset
            currentLoginItem = NULL;
            
        }//all login items
        
    }//remove/uninstall
    
bail:
    
    //release login items
    if(NULL != loginItems)
    {
        //release
        CFRelease(loginItems);
        
        //reset
        loginItems = NULL;
    }
    
    //release login ref
    if(NULL != loginItemsRef)
    {
        //release
        CFRelease(loginItemsRef);
        
        //reset
        loginItemsRef = NULL;
    }
    
    //release url
    if(NULL != currentLoginItem)
    {
        //release
        CFRelease(currentLoginItem);
        
        //reset
        currentLoginItem = NULL;
    }
    
    return wasToggled;
}

#pragma clang diagnostic pop


#ifndef DAEMON_BUILD

//show an alert
NSModalResponse showAlert(NSAlertStyle style, NSString* messageText, NSString* informativeText, NSArray* buttons)
{
    //alert
    NSAlert* alert = nil;
    
    //response
    NSModalResponse response = 0;
    
    //init alert
    alert = [[NSAlert alloc] init];
    
    //set style
    alert.alertStyle = style;
    
    //main text
    alert.messageText = messageText;
    
    //add details
    if(nil != informativeText)
    {
        alert.informativeText = informativeText;
    }
    
    //add buttons
    for(NSString* title in buttons)
    {
        [alert addButtonWithTitle:title];
    }
    
    //make first button, first responder
    alert.buttons[0].keyEquivalent = @"\r";
    
    //center
    [alert.window center];
    
    //foreground
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    
    //activate
    [NSApp activate];
    
    //show
    response = [alert runModal];
    
#ifdef APP_BUILD

    //(re)set activation policy
    [((AppDelegate*)NSApplication.sharedApplication.delegate) setActivationPolicy];

#endif
    
    return response;
}

#endif


//given a pid, get its parent (ppid)
pid_t getParentID(int pid)
{
    //parent id
    pid_t parentID = -1;
    
    //kinfo_proc struct
    struct kinfo_proc processStruct;
    
    //size
    size_t procBufferSize = sizeof(processStruct);
    
    //mib
    const u_int mibLength = 4;
    
    //syscall result
    int sysctlResult = -1;
    
    //init mib
    int mib[mibLength] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, pid};
    
    //clear buffer
    memset(&processStruct, 0x0, procBufferSize);
    
    //make syscall
    sysctlResult = sysctl(mib, mibLength, &processStruct, &procBufferSize, NULL, 0);
    
    //check if got ppid
    if( (noErr == sysctlResult) &&
        (0 != procBufferSize) )
    {
        //save ppid
        parentID = processStruct.kp_eproc.e_ppid;
    }
    
    return parentID;
}


//start app
// note: executed with 'NSWorkspaceLaunchWithoutActivation'
BOOL startApplication(NSURL* path, NSUInteger launchOptions)
{
    //status var
    BOOL result = NO;
    
    //error
    NSError* error = nil;
    
    //dbg msg
    os_log_debug(logHandle, "starting application: %{public}@", path);
    
    //launch it
    if(nil == [[NSWorkspace sharedWorkspace] launchApplicationAtURL:path options:launchOptions configuration:@{} error:&error])
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to launch application: %{public}@/%{public}@", path, error);
        goto bail;
    }
    
    //happy
    result = YES;
    
bail:
    
    return result;
}

//exec a process with args
// if 'shouldWait' is set, wait and return stdout/in and termination status
NSMutableDictionary* execTask(NSString* binaryPath, NSArray* arguments, BOOL shouldWait, BOOL grabOutput)
{
    //task
    NSTask* task = nil;
    
    //output pipe for stdout
    NSPipe* stdOutPipe = nil;
    
    //output pipe for stderr
    NSPipe* stdErrPipe = nil;
    
    //read handle for stdout
    NSFileHandle* stdOutReadHandle = nil;
    
    //read handle for stderr
    NSFileHandle* stdErrReadHandle = nil;
    
    //results dictionary
    NSMutableDictionary* results = nil;
    
    //output for stdout
    NSMutableData *stdOutData = nil;
    
    //output for stderr
    NSMutableData *stdErrData = nil;
    
    //dbg msg
    os_log_debug(logHandle, "executing: %{public}@ with %{public}@", binaryPath, arguments);
    
    //init dictionary for results
    results = [NSMutableDictionary dictionary];
    
    //init task
    task = [[NSTask alloc] init];
    
    //sanity check
    // NSTask throws if path isn't found...
    if(YES != [NSFileManager.defaultManager fileExistsAtPath:binaryPath])
    {
        //bail
        goto bail;
    }
    
    //only setup pipes if wait flag is set
    if(YES == grabOutput)
    {
        //init stdout pipe
        stdOutPipe = [NSPipe pipe];
        
        //init stderr pipe
        stdErrPipe = [NSPipe pipe];
        
        //init stdout read handle
        stdOutReadHandle = [stdOutPipe fileHandleForReading];
        
        //init stderr read handle
        stdErrReadHandle = [stdErrPipe fileHandleForReading];
        
        //init stdout output buffer
        stdOutData = [NSMutableData data];
        
        //init stderr output buffer
        stdErrData = [NSMutableData data];
        
        //set task's stdout
        task.standardOutput = stdOutPipe;
        
        //set task's stderr
        task.standardError = stdErrPipe;
    }
    
    //set task's path
    task.launchPath = binaryPath;
    
    //set task's args
    if(nil != arguments)
    {
        //set
        task.arguments = arguments;
    }
    
    //dbg msg
    os_log_debug(logHandle, "execing task, %{public}@ (arguments: %{public}@)", task.launchPath, task.arguments);
    
    //wrap task launch
    @try
    {
        //launch
        [task launch];
    }
    @catch(NSException *exception)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to launch task (%{public}@)", exception);
        
        //bail
        goto bail;
    }
    
    //no need to wait
    // can just bail w/ no output
    if( (YES != shouldWait) &&
        (YES != grabOutput) )
    {
        //bail
        goto bail;
    }
    
    //wait
    // ...but no output
    else if( (YES == shouldWait) &&
             (YES != grabOutput) )
    {
        //wait
        [task waitUntilExit];
        
        //add exit code
        results[EXIT_CODE] = [NSNumber numberWithInteger:task.terminationStatus];
        
        //bail
        goto bail;
    }
    
    //grab output?
    // even if wait not set, still will wait!
    else
    {
        //read in stdout/stderr
        while(YES == [task isRunning])
        {
            //accumulate stdout
            [stdOutData appendData:[stdOutReadHandle readDataToEndOfFile]];
            
            //accumulate stderr
            [stdErrData appendData:[stdErrReadHandle readDataToEndOfFile]];
        }
        
        //grab any leftover stdout
        [stdOutData appendData:[stdOutReadHandle readDataToEndOfFile]];
        
        //grab any leftover stderr
        [stdErrData appendData:[stdErrReadHandle readDataToEndOfFile]];
        
        //add stdout
        if(0 != stdOutData.length)
        {
            //add
            results[STDOUT] = stdOutData;
        }
        
        //add stderr
        if(0 != stdErrData.length)
        {
            //add
            results[STDERR] = stdErrData;
        }
        
        //add exit code
        results[EXIT_CODE] = [NSNumber numberWithInteger:task.terminationStatus];
    }

bail:
    
    //dbg msg
    os_log_debug(logHandle, "task completed with %{public}@", results);
    
    return results;
}


//loads a framework
// note: assumes it is in 'Framework' dir
NSBundle* loadFramework(NSString* name)
{
    //handle
    NSBundle* framework = nil;
    
    //framework path
    NSString* path = nil;
    
    //init path
    path = [NSString stringWithFormat:@"%@/../Frameworks/%@", [NSProcessInfo.processInfo.arguments[0] stringByDeletingLastPathComponent], name];
    
    //standardize path
    path = [path stringByStandardizingPath];
    
    //init framework (bundle)
    framework = [NSBundle bundleWithPath:path];
    if(NULL == framework)
    {
        //bail
        goto bail;
    }
    
    //load framework
    if(YES != [framework loadAndReturnError:nil])
    {
        //bail
        goto bail;
    }
    
bail:
    
    return framework;
}

//check if a file is restricted (SIP)
BOOL isFileRestricted(NSString* file)
{
    //flag
    BOOL restricted = NO;
    
    //info
    struct stat info = {0};
    
    //clear
    memset(&info, 0x0, sizeof(struct stat));
    
    //get file info
    if(0 == lstat(file.UTF8String, &info))
    {
        //check flags
        restricted = (BOOL)(info.st_flags & SF_RESTRICTED);
    }
    
    return restricted;
}

//in dark mode?
BOOL isDarkMode(void)
{
    return [[[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"] isEqualToString:@"Dark"];
}

//determine if path is translocated
// thanks: http://lapcatsoftware.com/articles/detect-app-translocation.html
BOOL isTranslocated(NSString* path)
{
    //token
    static dispatch_once_t onceToken = 0;
    
    //framework handle
    static void* handle = NULL;
    
    //fp to 'SecTranslocateIsTranslocatedURL'
    static Boolean (*SecTranslocateIsTranslocatedURL)(CFURLRef path, bool *isTranslocated, CFErrorRef * __nullable error) = NULL;
    
    //flag for call
    bool isTranslocated = false;
    
    //dbg msg
    os_log_debug(logHandle, "checking if %{public}@ is translocated", path);

    //load/open framework
    dispatch_once(&onceToken, ^{
        
        //open and resolve 'SecTranslocateIsTranslocatedURLFP'
        handle = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY);
        if(NULL != handle)
        {
            //resolve 'SecTranslocateIsTranslocatedURLFP'
            SecTranslocateIsTranslocatedURL = dlsym(handle, "SecTranslocateIsTranslocatedURL");
        }
        //err
        else
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to 'dlopen' the 'Security.framework'");
        }
        
    });
    
    //sanity check
    if(NULL == SecTranslocateIsTranslocatedURL)
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to resolve 'SecTranslocateIsTranslocatedURL'");
        
        //bail
        goto bail;
    }
    
    //call 'SecTranslocateIsTranslocatedURL'
    if(!SecTranslocateIsTranslocatedURL((__bridge CFURLRef)([NSURL fileURLWithPath:path]), &isTranslocated, NULL))
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to invoke 'SecTranslocateIsTranslocatedURL'");
        
        //bail
        goto bail;
    }
    
    //log msg
    os_log_debug(logHandle, "'SecTranslocateIsTranslocatedURL' succeeded, result: %x", isTranslocated);
    
bail:

    return isTranslocated;
}

//convert es_string_token_t to string
NSString* convertStringToken(const es_string_token_t* stringToken)
{
    //string
    NSString* string = nil;
    
    //sanity check(s)
    if( (NULL == stringToken) ||
        (NULL == stringToken->data) ||
        (stringToken->length <= 0) )
    {
        //bail
        goto bail;
    }
        
    //convert to data, then to string
    string = [[NSString alloc] initWithBytes:stringToken->data length:stringToken->length encoding:NSUTF8StringEncoding];
    
bail:
    
    return string;
}

#ifdef DAEMON_BUILD

//mach time to nanoseconds
// from: https://developer.apple.com/documentation/apple-silicon/addressing-architectural-differences-in-your-macos-code
uint64_t machTimeToNanoseconds(uint64_t machTime)
{
    uint64_t nanoseconds = 0;
    static mach_timebase_info_data_t sTimebase;
    if (sTimebase.denom == 0)
        (void)mach_timebase_info(&sTimebase);

    nanoseconds = ((machTime * sTimebase.numer) / sTimebase.denom);

    return nanoseconds;
}

//get items quarantine flags
// thanks: https://trac.webkit.org/changeset/281056/webkit
uint32_t getQuarantineFlags(NSString* path)
{
    //error
    int error = noErr;
    
    //flags
    uint32_t flags = QTN_NOT_QUARANTINED;
    
    //once token
    static dispatch_once_t onceToken = 0;
    
    //dylib handle
    static void* handle = NULL;
    
    //function pointers
    static qtn_file_t(*qtn_file_alloc_FP)(void) = NULL;
    static void (*qtn_file_free_FP)(qtn_file_t qf) = NULL;
    static uint32_t (*qtn_file_get_flags_FP)(qtn_file_t qf) = NULL;
    static int (*qtn_file_init_with_path_FP)(qtn_file_t qf, const char *path) = NULL;
    
    //quarantine file
    qtn_file_t quarantineFile = NULL;
    
    //dbg msg
    os_log_debug(logHandle, "checking if %{public}@ is quarantined", path);
    
    //sanity check(s)
    if(0 == path.length)
    {
        //err msg
        os_log_debug(logHandle, "invalid path");
        
        //bail
        goto bail;
    }

    //load/open framework
    dispatch_once(&onceToken, ^{
        
        //open quarantine dylib
        handle = dlopen("/usr/lib/system/libquarantine.dylib", RTLD_LAZY);
        if(NULL != handle)
        {
            //resolve function pointers
            qtn_file_free_FP = dlsym(handle, "_qtn_file_free");
            qtn_file_alloc_FP = dlsym(handle, "_qtn_file_alloc");
            qtn_file_get_flags_FP = dlsym(handle, "_qtn_file_get_flags");
            qtn_file_init_with_path_FP = dlsym(handle, "_qtn_file_init_with_path");
        }
        //err
        else
        {
            //err msg
            os_log_error(logHandle, "ERROR: failed to 'dlopen' the 'libquarantine.dylib'");
        }
        
    });
    
    //sanity check(s)
    if( (NULL == qtn_file_free_FP) ||
        (NULL == qtn_file_alloc_FP) ||
        (NULL == qtn_file_get_flags_FP) ||
        (NULL == qtn_file_init_with_path_FP) )
    {
        //err msg
        os_log_error(logHandle, "ERROR: failed to resolve 'libquarantine' function pointers");
        
        //bail
        goto bail;
    }
    
    //alloc file
    quarantineFile = qtn_file_alloc_FP();
    if(NULL == quarantineFile)
    {
        //bail
        goto bail;
    }
    
    //init file
    error = qtn_file_init_with_path_FP(quarantineFile, [NSURL fileURLWithPath:path].path.fileSystemRepresentation);
    if(ENOENT == error)
    {
        //bail
        goto bail;
    }
    
    //not quarantined?
    if(QTN_NOT_QUARANTINED == error)
    {
        //dbg msg
        os_log_debug(logHandle, "%{public}@ is *not* quarantined (QTN_NOT_QUARANTINED)", path);
        
        //bail
        goto bail;
    }
    
    //get flags
    flags = qtn_file_get_flags_FP(quarantineFile);
    
    //dbg msg
    os_log_debug(logHandle, "quarantine flags: %#x", flags);

bail:
    
    //cleanup
    if(NULL != quarantineFile)
    {
        //free
        qtn_file_free_FP(quarantineFile);
        quarantineFile = NULL;
    }

    return flags;
}

//get a list of process
NSArray* enumerateProcesses(void) {
    size_t length = 0;
    int32_t count = 0;
    pid_t* pids = NULL;
    
    NSMutableArray* process = [NSMutableArray array];
    
    length = sizeof(count);
    if(0 != sysctlbyname("kern.maxproc", &count, &length, NULL, 0)) {
        goto bail;
    }

    pids = (pid_t *)calloc((unsigned long)count, sizeof(pid_t));
    if(!pids) {
        goto bail;
    }
    
    count = proc_listallpids(pids, count * (int)sizeof(pid_t));
    if(count <= 0) {
        goto bail;
    }
    
    for(int i = 0; i<count; i++)
    {
        NSData* auditToken = auditTokenFromPid(pids[i]);
        if(nil != auditToken)
        {
            [process addObject:auditToken];
        }
    }
    
bail:
    
    if(pids) {
        free(pids);
        pids = NULL;
    }
    
    return process;
}


//pid -> audit token
NSData* auditTokenFromPid(pid_t pid) {
    NSData* auditToken = nil;
    audit_token_t token = {0};
    task_name_t task = MACH_PORT_NULL;
    
    mach_msg_type_number_t info_size = TASK_AUDIT_TOKEN_COUNT;

    if(KERN_SUCCESS == task_name_for_pid(mach_task_self(), pid, &task)) {
        if(KERN_SUCCESS == task_info(task, TASK_AUDIT_TOKEN, (integer_t *)&token, &info_size)) {
            auditToken = [NSData dataWithBytes:&token length:sizeof(audit_token_t)];
        }
    }
    
    if(MACH_PORT_NULL != task) {
        mach_port_deallocate(mach_task_self(), task);
    }
    
    return auditToken;
}

//get current working directory of process
NSString* getCWD(pid_t pid) {
    
    struct proc_vnodepathinfo vinfo = {0};
    
    if(proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vinfo, sizeof(vinfo)) > 0) {
        NSString* cwd = [NSString stringWithUTF8String:vinfo.pvi_cdir.vip_path];
        if(cwd.length) {
            return [cwd stringByResolvingSymlinksInPath];
        }
    }
    
    return nil;
}

//extract scripts from process arguments
NSArray* getScripts(pid_t pid, NSMutableArray* args, NSString* cwd) {
    
    if(args.count < 2) {
        return nil;
    }
    
    if(!cwd) {
        cwd = getCWD(pid);
    }
    
    BOOL isDirectory = NO;
    NSMutableArray* scripts = [NSMutableArray array];
    
    for(NSUInteger i = 1; i < args.count; i++) {
        
        NSString* arg = args[i];
        
        //resolve relative paths against cwd
        NSString* fullPath = nil;
        if([arg hasPrefix:@"/"]) {
            fullPath = arg;
        } else if(cwd) {
            fullPath = [cwd stringByAppendingPathComponent:arg];
        } else {
            continue;
        }
        
        //resolve symlinks for consistent paths
        fullPath = [fullPath stringByResolvingSymlinksInPath];
        
        //must be an existing regular file
        if([NSFileManager.defaultManager fileExistsAtPath:fullPath isDirectory:&isDirectory] && !isDirectory) {
            [scripts addObject:fullPath];
        }
    }
    
    return scripts.count > 0 ? scripts : nil;
}

#endif

#ifndef DAEMON_BUILD

//check/request camera access
void requestCameraAccess(void)
{
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];

    //already granted
    if(authStatus == AVAuthorizationStatusAuthorized) return;
    
    //never asked — show system prompt
    if(authStatus == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            os_log_debug(logHandle, "user response for camera access: %d", granted);
        }];
        return;
    }
    
    //denied/restricted — just alert
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText     = @"Camera Access Denied";
    alert.informativeText = @"Enable camera access in System Settings → Privacy & Security → Camera, or disable \"Include Image in Alert\".";
    [alert addButtonWithTitle:@"Open System Settings"];
    [alert addButtonWithTitle:@"Close"];

    if([alert runModal] == NSAlertFirstButtonReturn)
    {
        [[NSWorkspace sharedWorkspace] openURL:
            [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"]];
    }
    
    return;
}

#endif
