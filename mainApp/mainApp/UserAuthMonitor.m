//
//  userAuthMonitor.m
//  mainApp
//
//  Created by Patrick Wardle on 1/29/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "UserAuthMonitor.h"
#import <SystemConfiguration/SystemConfiguration.h>

//callback proc for login notifications
// if it's a new user, then save that into object
static void loginNotification(SCDynamicStoreRef store, CFArrayRef changedKeys, void * info)
{
    #pragma unused(changedKeys)
    
    //console user
    NSString* consoleUser = nil;
    
    //instance of class
    UserAuthMonitor* userAuthMonitor = nil;
    
    //extract obj pointer
    userAuthMonitor = (__bridge UserAuthMonitor*)info;
    
    //grab console user
    consoleUser = currentConsoleUser(store);
    if(nil == consoleUser)
    {
        //bail
        goto bail;
    }
    
    //same same?
    // apple says we can get multiple notifications
    if(YES == [consoleUser isEqualToString:userAuthMonitor.consoleUser])
    {
        //bail
        goto bail;
    }
    
    //determine if was touchID event
    userAuthMonitor.wasTouchID = [userAuthMonitor wasTouchIDEvent];
    
    //new console user
    // indicates new login
    userAuthMonitor.lastEvent = [NSDate date];
    
    //save user
    userAuthMonitor.consoleUser = consoleUser;
    
bail:
    
    return;
}

@implementation UserAuthMonitor

@synthesize lastEvent;
@synthesize wasTouchID;

//thread function
// setup login / lockscreen monitoring
// based on: https://developer.apple.com/library/content/qa/qa1133/_index.html
-(void)monitor
{
    //store
    SCDynamicStoreRef store = NULL;
    
    //context
    SCDynamicStoreContext context = {0, NULL, NULL, NULL, NULL};
    
    //array of keys to watch
    CFArrayRef keys = NULL;
    
    //key to watch
    CFStringRef key = NULL;
    
    //run loop source
    CFRunLoopSourceRef runloopSrc = NULL;
    
    //first, register for screen unlock events
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(screenUnlocked) name:@"com.apple.screenIsUnlocked" object:nil];
    
    //'save' object pointer
    // allows code to access obj in callback
    context.info = (__bridge void*)self;
    
    //create store
    store = SCDynamicStoreCreate(NULL, CFSTR("com.apple.dts.ConsoleUser"), loginNotification, &context);
    if(NULL == store)
    {
        //bail
        goto bail;
    }
    
    //create key
    // console user
    key = SCDynamicStoreKeyCreateConsoleUser(NULL);
    if(NULL == key)
    {
        //bail
        goto bail;
    }
    
    //create array of keys
    keys = CFArrayCreate(NULL, (const void **) &key, 1, &kCFTypeArrayCallBacks);
    if(NULL == keys)
    {
        //bail
        goto bail;
    }
    
    //set notification based on keys
    if(true != SCDynamicStoreSetNotificationKeys(store, keys, NULL))
    {
        //bail
        goto bail;
    }
    
    //create runloop source
    runloopSrc = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
    if(NULL == runloopSrc)
    {
        //bail
        goto bail;
    }
    
    //add to runloop
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runloopSrc, kCFRunLoopDefaultMode);

    //loop
    CFRunLoopRun();
    
bail:
    
    //cleanup runloop
    if(NULL != runloopSrc)
    {
        //invalidat
        CFRunLoopSourceInvalidate(runloopSrc);
        
        //release
        CFRelease(runloopSrc);
    }
    
    //release keys
    if(NULL != keys)
    {
        //release
        CFRelease(keys);
    }
    
    //release key
    if(NULL != key)
    {
        //release
        CFRelease(key);
    }
    
    //release store
    if(NULL != store)
    {
        //release
        CFRelease(store);
    }
    
    return;
}

//callback for screen unlock events
-(void)screenUnlocked
{
    //determine if was touchID event
    self.wasTouchID = [self wasTouchIDEvent];
    
    //set last event
    self.lastEvent = [NSDate date];
    
    return;
}

//determine if event was triggered by touchID
// basically dump OS log and look for touch ID event
// TODO: test w/ failed touch ID event
-(BOOL)wasTouchIDEvent
{
    //result
    BOOL touchIDEvent = NO;
    
    //log output
    NSDictionary* output = nil;
    
    //data formatter
    NSDateFormatter *dateFormatter = nil;
    
    //start time
    NSString* startTime = nil;
    
    //init
    dateFormatter = [[NSDateFormatter alloc] init];
    
    //set format
    [dateFormatter setDateFormat:@"YYYY-MM-DD HH:MM:SS"];
    
    //init start time w/ 5 seconds ago
    startTime =  [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:-5.0f]];
    
    //grab log output
    output = execTask(LOG, @[@"show", @"-start", startTime, @"--predicate", @"'subsystem == \"com.apple.LocalAuthentication\" && category == \"MechanismTouchId\" && eventMessage CONTAINS \"matchedWithResult:\"'"], YES);
    
    //touch ID event?
    if(NSNotFound == ([output[STDOUT] rangeOfString:@"matchedWithResult:"].location))
    {
        //bail
        goto bail;
    }
    
    //happy
    touchIDEvent = YES;
    
bail:
    
    return touchIDEvent;
}

@end
