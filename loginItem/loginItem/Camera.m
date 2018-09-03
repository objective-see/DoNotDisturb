//
//  Camera.m
//  loginItem
//
//  Created by Patrick Wardle on 9/1/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Camera.h"
#import "Logging.h"



@implementation Camera

@synthesize session;

//configure
-(BOOL)configure
{
    //flag
    BOOL configured = NO;
    
    //device
    AVCaptureDevice* device = nil;
    
    //input
    AVCaptureInput* input = nil;
    
    //output
    AVCaptureStillImageOutput* output = nil;
    
    //find default camera
    device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if(nil == device)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to find camera for capture");
        
        //bail
        goto bail;
    }
    
    //init input from camera
    input = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    if(nil == input)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to find input from camera");
        
        //bail
        goto bail;
    }
    
    //init session
    self.session = [[AVCaptureSession alloc] init];

    //check if input can be added to session
    if(YES != [self.session canAddInput:input])
    {
        //err msg
        logMsg(LOG_ERR, @"cannot add input to session");
        
        //bail
        goto bail;
    }
    
    //add input
    [self.session addInput:input];
    
    //init output
    output = [[AVCaptureStillImageOutput alloc] init];
    
    //set output settings (jpeg)
    output.outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
    
    //check if output can be added to session
    if(YES != [self.session canAddOutput:output])
    {
        //err msg
        logMsg(LOG_ERR, @"cannot add output to session");
        
        //bail
        goto bail;
    }
    
    //add output
    [self.session addOutput:output];

    //happy
    configured = YES;

bail:
    
    return configured;
}

//capture an image from the webcam
-(NSData*)captureImage
{
    //image
    __block NSData* image = nil;
    
    //output
    __block AVCaptureStillImageOutput* output = nil;
    
    //wait semaphore
    dispatch_semaphore_t semaphore = 0;
    
    //init sema
    semaphore = dispatch_semaphore_create(0);
    
    //configure/init session
    if(YES == [self configure])
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"configured camera for capture");
        
        //start
        [self.session startRunning];
        
        //give session some time to start
        // could use KVO, etc, but this seems like a pain
        // see: https://stackoverflow.com/questions/27260697/avcapturedevice-adjustingexposure-is-false-but-captured-image-is-dark
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
            //grab output
            output = self.session.outputs.firstObject;
            
            //capture image
            [output captureStillImageAsynchronouslyFromConnection:[output connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error)
            {
                 //covert image
                 if( (nil == error) &&
                     (NULL != imageDataSampleBuffer))
                 {
                     //dbg msg
                     logMsg(LOG_DEBUG, @"captured image");
                     
                     //covert
                     image = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                 }
                 
                 //error
                 else
                 {
                     //err msg
                     logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to capture image (%@)", error]);
                 }
                
                 //(always) signal sema
                 dispatch_semaphore_signal(semaphore);
                 
             }];
            
        });
        
        //wait for install to be completed by XPC
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        //stop session
        if(YES == self.session.isRunning)
        {
            //stop
            [self.session stopRunning];
        }
    }
    
    //failed to init session
    else
    {
        //err msg
        logMsg(LOG_ERR, @"failed to initialize/configure camera capture session");
        
        //bail
        goto bail;
    }
    
bail:
    
    return image;
}

@end
