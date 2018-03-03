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
            
            //save qrc info
            //self.qrcInfo = [[NSString alloc] initWithData:qrcData encoding:NSUTF8StringEncoding];
            
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

/*
//generate and scale a QRC image
// based on: https://stackoverflow.com/a/23531217
- (NSImage*)generateImage:(CGSize)size
{
    //qrc image
    NSImage* qrcImage = nil;
    
    //filter
    CIFilter *filter = NULL;
    
    //output image
    CIImage *outputImage = NULL;
    
    //extent
    CGRect extent = {0};
    
    //scale
    CGFloat scale = 0.0f;
    
    //gray space ref
    CGColorSpaceRef colorSpaceRef = NULL;
    
    //bitmap ref
    CGContextRef bitmapRef = NULL;
    
    //bitmap image
    CGImageRef bitmapImage = NULL;
    
    //scaled image
    CGImageRef scaledImage = NULL;
    
    //init filter
    filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    
    //set defaults
    [filter setDefaults];
    
    //set data
    [filter setValue:[self.qrcInfo dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];
    
    //grab output image
    outputImage = filter.outputImage;
    
    //calc extent
    extent = CGRectIntegral(outputImage.extent);
    
    //calc scale
    scale = MIN(size.width / CGRectGetWidth(extent), size.height / CGRectGetHeight(extent));
    
    //create color space
    colorSpaceRef = CGColorSpaceCreateDeviceGray();
    if(NULL == colorSpaceRef)
    {
        //bail
        goto bail;
    }
    
    //create bitmap context
    bitmapRef = CGBitmapContextCreate(nil, CGRectGetWidth(extent) * scale, CGRectGetHeight(extent) * scale, 8, 0, colorSpaceRef, (CGBitmapInfo)kCGImageAlphaNone);
    if(NULL == bitmapRef)
    {
        //bail
        goto bail;
    }
    
    //create bitmap image
    bitmapImage = [[CIContext contextWithCGContext:bitmapRef options:nil] createCGImage:outputImage fromRect:extent];
    if(NULL == bitmapImage)
    {
        //bail
        goto bail;
    }
    
    //set quality
    CGContextSetInterpolationQuality(bitmapRef, kCGInterpolationNone);
    
    //set scale
    CGContextScaleCTM(bitmapRef, scale, scale);
    
    //draw
    CGContextDrawImage(bitmapRef, extent, bitmapImage);
    
    //create scaled image from bitmap
    scaledImage = CGBitmapContextCreateImage(bitmapRef);
    if(NULL == scaledImage)
    {
        //bail
        goto bail;
    }
    
    //convert to NSImage
    qrcImage = [[NSImage alloc] initWithCGImage:scaledImage size:size];
    
bail:
    
    //release color space ref
    if(NULL != colorSpaceRef)
    {
        //release
        CGColorSpaceRelease(colorSpaceRef);
        
        //unset
        colorSpaceRef = NULL;
    }
    
    //release bitmap ref
    if(NULL != bitmapRef)
    {
        //release
        CGContextRelease(bitmapRef);
        
        //unset
        bitmapRef = NULL;
    }
    
    //release bitmap
    if(NULL != bitmapImage)
    {
        //release
        CGImageRelease(bitmapImage);
        
        //unset
        bitmapImage = NULL;
    }
    
    //release scaled image
    if(NULL != scaledImage)
    {
        //release
        CGImageRelease(scaledImage);
        
        //unset
        scaledImage = NULL;
    }

    return qrcImage;
}
*/

/*
func generateQRCode(size: CGFloat) -> NSImage? {
    //let data = self.data(using: String.Encoding.utf8, allowLossyConversion: false)
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("Q", forKey: "inputCorrectionLevel")
    if let output = filter.outputImage {
        let extent = output.extent
        let scale = min(size / extent.width, size / extent.height)
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let result = output.transformed(by: transform)
        let rep: NSCIImageRep = NSCIImageRep(ciImage: result)
        let nsImage: NSImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
    return nil
}
}
*/

- (NSImage*)generateImage:(NSData*)data size:(float)size
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
    
    //set defaults
    //[filter setDefaults];
    
    //set data
    [filter setValue:data forKey:@"inputMessage"];
    
    //set correction level
    [filter setValue:@"Q" forKey:@"inputCorrectionLevel"];
    
    //grab output image
    outputImage = filter.outputImage;
    
    //init extent
    extent = outputImage.extent;
    
    
    /*
     
     let scale = min(size / extent.width, size / extent.height)
     let transform = CGAffineTransform(scaleX: scale, y: scale)
     let result = output.transformed(by: transform)
     let rep: NSCIImageRep = NSCIImageRep(ciImage: result)
     let nsImage: NSImage = NSImage(size: rep.size)
     nsImage.addRepresentation(rep)
     
     */
    
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
