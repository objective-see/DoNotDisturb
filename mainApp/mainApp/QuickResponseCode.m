//
//  QuickResponseCode.m
//  mainApp
//
//  Created by Patrick Wardle on 1/25/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import "Logging.h"
#import "DaemonComms.h"
#import "QuickResponseCode.h"

#import <Cocoa/Cocoa.h>
#import <CoreImage/CoreImage.h>

@implementation QuickResponseCode

@synthesize daemonComms;

//init
// create XPC connection & set remote obj interface
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //init daemon comms
        // will connect, etc.
        daemonComms = [[DaemonComms alloc] init];
    }
    
    return self;
}

//generate a QRC code
// gets QRC string from image, then generates image
-(void)generateQRC:(float)size reply:(void (^)(NSImage* qrc))reply
{
    //make request to daemon
    // give me a QRC code y0!
    [daemonComms qrcRequest:^(NSData* qrcData)
    {
        //qrc image
        NSImage* qrcImage = nil;
    
        //generate qrc image
        if(0 != qrcData.length)
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got qrc from daemon (size: %lu)", (unsigned long)qrcData.length]);
            
            //generate QRC image
            qrcImage = [self generateImage:qrcData size:size];
        }
        
        //didn't get anything from the daemon/framework :(
        else
        {
            //err msg
            logMsg(LOG_ERR, @"failed to generated QRC data");
        }
         
        //call back
        reply(qrcImage);
        
     }];
    
    return;
}

//generate qrc image
-(NSImage*)generateImage:(NSData*)data size:(float)size
{
    //qrc image
    NSImage* qrcImage = nil;
    
    //filter
    CIFilter *filter = NULL;
    
    //output image
    CIImage *outputImage = NULL;
    
    //transformed image
    CIImage *transformedImage = NULL;
    
    //image rep
    NSCIImageRep* imageRep = nil;
    
    //extent
    CGRect extent = {0};
    
    //scale
    CGFloat scale = 0.0f;
    
    //transform
    CGAffineTransform transform = {0};
    
    //init filter
    filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    if(nil == filter)
    {
        //bail
        goto bail;
    }
    
    //set data
    [filter setValue:data forKey:@"inputMessage"];
    
    //set correction level
    [filter setValue:@"L" forKey:@"inputCorrectionLevel"];
    
    //grab output image
    outputImage = filter.outputImage;
    
    //init extent
    extent = outputImage.extent;
    
    //init scale
    scale = MIN(size/extent.size.width, size/extent.size.height);
    
    //init transform
    transform = CGAffineTransformMakeScale(scale, scale);
    
    //apply transform
    transformedImage = [outputImage imageByApplyingTransform:transform];
    
    //generate image representation
    imageRep = [NSCIImageRep imageRepWithCIImage:transformedImage];
    
    //init image
    qrcImage = [[NSImage alloc] initWithSize:imageRep.size];
    
    //add representation
    [qrcImage addRepresentation:imageRep];
    
bail:
    
    return qrcImage;
}

@end
