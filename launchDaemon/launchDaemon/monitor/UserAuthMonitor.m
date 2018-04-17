//
//  file: UserAuthEvent.m
//  project: DND (launch daemon)
//  description: user authentication event monitor
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

//disable incomplete/umbrella warnings
// otherwise complains about 'audit_kevents.h'
#pragma clang diagnostic ignored "-Wincomplete-umbrella"

#import "Consts.h"
#import "Logging.h"
#import "AuthEvent.h"
#import "Utilities.h"
#import "UserAuthMonitor.h"

#import <unistd.h>
#import <libproc.h>
#import <pthread.h>
#import <bsm/audit.h>
#import <sys/ioctl.h>
#import <sys/types.h>
#import <bsm/libbsm.h>
#import <Cocoa/Cocoa.h>
#import <bsm/audit_kevents.h>
#import <security/audit/audit_ioctl.h>
#import <SystemConfiguration/SystemConfiguration.h>

@implementation UserAuthMonitor

@synthesize shouldStop;

//open/config/init audit pipe
-(FILE*)initAuditPipe
{
    //handle to audit pipe
    FILE* auditFile = NULL;
    
    //event mask
    // what event classes to watch for
    u_int eventClasses = AUDIT_CLASS_LO | AUDIT_CLASS_AA;
    
    //file descriptor for audit pipe
    int auditFileDescriptor = -1;
    
    //status var
    int status = -1;
    
    //preselect mode
    int mode = -1;
    
    //queue length
    int maxQueueLength = -1;
    
    //open audit pipe for reading
    auditFile = fopen(AUDIT_PIPE, "r");
    if(auditFile == NULL)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to open audit pipe %s", AUDIT_PIPE]);
        
        //bail
        goto bail;
    }
    
    //grab file descriptor
    auditFileDescriptor = fileno(auditFile);
    
    //init mode
    mode = AUDITPIPE_PRESELECT_MODE_LOCAL;
    
    //set preselect mode
    status = ioctl(auditFileDescriptor, AUDITPIPE_SET_PRESELECT_MODE, &mode);
    if(-1 == status)
    {
        //bail
        goto bail;
    }
    
    //grab max queue length
    status = ioctl(auditFileDescriptor, AUDITPIPE_GET_QLIMIT_MAX, &maxQueueLength);
    if(-1 == status)
    {
        //bail
        goto bail;
    }
    
    //set queue length to max
    status = ioctl(auditFileDescriptor, AUDITPIPE_SET_QLIMIT, &maxQueueLength);
    if(-1 == status)
    {
        //bail
        goto bail;
    }
    
    //set preselect flags
    // event classes we're interested in
    status = ioctl(auditFileDescriptor, AUDITPIPE_SET_PRESELECT_FLAGS, &eventClasses);
    if(-1 == status)
    {
        //bail
        goto bail;
    }
    
    //set non-attributable flags
    // event classes we're interested in
    status = ioctl(auditFileDescriptor, AUDITPIPE_SET_PRESELECT_NAFLAGS, &eventClasses);
    if(-1 == status)
    {
        //bail
        goto bail;
    }
    
    //happy
    status = noErr;
    
bail:
    
    //any errors
    // close pipe if opened
    if( (noErr != status) &&
        (NULL != auditFile) )
    {
        //close
        fclose(auditFile);
        
        //unset
        auditFile = NULL;
    }
    
    return auditFile;
}

//monitor audit events related to user auth
-(BOOL)start
{
    //flag
    BOOL monitoring = NO;
    
    //handle to audit pipe
    FILE* auditFile = NULL;
    
    //open/config audit pipe
    auditFile = [self initAuditPipe];
    if(NULL != auditFile)
    {
        //kick off monitoring
        // run in background since this never returns
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            //monitor
            [self monitor:auditFile];
            
        });
        
        //happy
        monitoring =  YES;
    }
    
    return monitoring;
}

//read events of audit pipe
// process/save any auth events
-(void)monitor:(FILE*)auditFile
{
    //record buffer
    u_char* recordBuffer = NULL;
    
    //token struct
    tokenstr_t tokenStruct = {0};
    
    //total length of record
    int recordLength = -1;
    
    //amount of record left to process
    int recordBalance = -1;
    
    //amount currently processed
    int processedLength = -1;
    
    //auth event obj
    AuthEvent* authEvent = nil;
    
    //dbg msg
    logMsg(LOG_DEBUG, @"reading off audit pipe for user auth events");
    
    //forever
    // read/parse/process audit records
    while(YES)
    {
        @autoreleasepool
        {
            //first check termination flag/condition
            if(YES == self.shouldStop)
            {
                //bail
                goto bail;
            }
            
            //reset auth event
            authEvent = nil;
            
            //free prev buffer
            if(NULL != recordBuffer)
            {
                //free
                free(recordBuffer);
                
                //unset
                recordBuffer = NULL;
            }
            
            //read a single audit record
            // note: buffer is allocated by function, so must be freed when done
            recordLength = au_read_rec(auditFile, &recordBuffer);
            
            //sanity check
            if(-1 == recordLength)
            {
                //continue
                continue;
            }
            
            //init (remaining) balance to record's total length
            recordBalance = recordLength;
            
            //init processed length to start (zer0)
            processedLength = 0;
            
            //parse record
            // read all tokens/process
            while(0 != recordBalance)
            {
                //extract token
                // and sanity check
                if(-1  == au_fetch_tok(&tokenStruct, recordBuffer + processedLength, recordBalance))
                {
                    //error
                    // skip record
                    break;
                }
                
                //ignore records that are not related to process exec'ing/spawning
                // gotta wait till we hit/capture a AUT_HEADER* though, as this has the event type
                if( (nil != authEvent) &&
                    (YES != [self shouldProcessRecord:authEvent.type]) )
                {
                    //bail
                    // skips rest of record
                    break;
                }
                
                //process token(s)
                // create auth event object, etc
                switch(tokenStruct.id)
                {
                    //handle start of record
                    // grab event type, which allows us to ignore events not of interest
                    case AUT_HEADER32:
                    case AUT_HEADER32_EX:
                    case AUT_HEADER64:
                    case AUT_HEADER64_EX:
                    {
                        //create a new process
                        authEvent = [[AuthEvent alloc] init];
                        
                        //save type
                        authEvent.type = tokenStruct.tt.hdr32.e_type;
                        
                        break;
                    }
                        
                    //subject
                    case AUT_SUBJECT32:
                    case AUT_SUBJECT32_EX:
                    case AUT_SUBJECT64:
                    case AUT_SUBJECT64_EX:
                    {
                        //save pid
                        authEvent.pid = tokenStruct.tt.subj32.pid;
                        
                        //save uid
                        authEvent.uid = tokenStruct.tt.subj32.euid;
                        
                        
                        break;
                    }
                        
                    //text
                    // save text
                    case AUT_TEXT:
                    {
                        //save text
                        authEvent.text = [NSString stringWithUTF8String:tokenStruct.tt.text.text];
                        
                        break;
                    }
                        
                    //return
                    case AUT_RETURN:
                    {
                        //save return
                        authEvent.result = tokenStruct.tt.ret32.ret;
                        
                        break;
                    }
                        
                    //record trailer
                    // end/save, etc
                    case AUT_TRAILER:
                    {
                        //handle new process
                        if(nil != authEvent)
                        {
                            //handle
                            [self handleAuthEvent:authEvent];
                        }
                        
                        //unset
                        authEvent = nil;
                        
                        break;
                    }
                        
                        
                    default:
                        ;
                        
                }//process token
                
                //add length of current token
                processedLength += tokenStruct.len;
                
                //subtract lenght of current token
                recordBalance -= tokenStruct.len;
            }
            
        }//autorelease
        
    } //while(YES)
    
bail:
    
    //free buffer
    if(NULL != recordBuffer)
    {
        //free
        free(recordBuffer);
        
        //unset
        recordBuffer = NULL;
    }
    
    //close audit pipe
    if(NULL != auditFile)
    {
        //close
        fclose(auditFile);
        
        //unset
        auditFile = NULL;
    }
    
    return;
}

//stop
// simply set iVar, which will trigger auditing to cease
-(void)stop
{
    //set
    self.shouldStop = YES;
    
    return;
}

//check if event is one we care about
// for now, just anything associated with new processes/exits
-(BOOL)shouldProcessRecord:(u_int16_t)eventType
{
    //flag
    BOOL shouldProcess =  NO;
    
    //check
    if(eventType == AUE_auth_user)
    {
        //set flag
        shouldProcess = YES;
    }
    
    return shouldProcess;
}

//handle auth event
// a) complete event init
// b) broadcast event to all
-(void)handleAuthEvent:(AuthEvent*)event
{
    //set timestamp
    event.timestamp = [NSDate date];
    
    //set touch id flag
    event.wasTouchID = [event.text containsString:@"Touch ID authentication"];
    
    //broadcast event
    [[NSNotificationCenter defaultCenter] postNotificationName:AUTH_NOTIFICATION object:nil userInfo:@{AUTH_NOTIFICATION:event}];
    
    return;
}

@end
