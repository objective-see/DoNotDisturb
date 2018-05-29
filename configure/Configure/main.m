//
//  file: main.m
//  project: DND (config)
//  description: main interface/entry point for config app
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Cocoa;

#import "Consts.h"
#import "Logging.h"
#import "utilities.h"
#import "Configure.h"

//cmdline interface
// install or uninstall
BOOL cmdlineInterface(int action);

//main interface
int main(int argc, char *argv[])
{
    //status
    int status = -1;
    
    //cmdline install?
    if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:CMDLINE_FLAG_INSTALL])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"performing commandline install");
        
        //install
        if(YES != cmdlineInterface(ACTION_INSTALL_FLAG))
        {
            //err msg
            printf("\nDND ERROR: install failed\n\n");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        printf("DND: install ok!\n");
        
        //happy
        status = 0;
    }
    
    //cmdline uninstall?
    else if(YES == [[[NSProcessInfo processInfo] arguments] containsObject:CMDLINE_FLAG_UNINSTALL])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"performing commandline uninstall");
        
        //install
        if(YES != cmdlineInterface(ACTION_UNINSTALL_FLAG))
        {
            //err msg
            printf("\nDND ERROR: uninstall failed\n\n");
            
            //bail
            goto bail;
        }
        
        //dbg msg
        printf("DND: uninstall ok!\n");
        
        //happy
        status = 0;
    }
    
    //default run mode
    // just kick off main app logic
    else
    {
        //app main
        status = NSApplicationMain(argc,  (const char **) argv);
    }
    
bail:
    
    return status;
}

//cmdline interface
// install or uninstall
BOOL cmdlineInterface(int action)
{
    //flag
    BOOL wasConfigured = NO;
    
    //configure obj
    Configure* configure = nil;
    
    //alloc/init
    configure = [[Configure alloc] init];
    
    //first check root
    if(0 != geteuid())
    {
        //err msg
        printf("\nDND ERROR: cmdline interface actions require root!\n\n");
        
        //bail
        goto bail;
    }
    
    //configure
    wasConfigured = [configure configure:action];
    if(YES != wasConfigured)
    {
        //bail
        goto bail;
    }
    
    //happy
    wasConfigured = YES;
    
bail:
    
    //cleanup
    if(nil != configure)
    {
        //cleanup
        [configure removeHelper];
    }
    
    return wasConfigured;
}
