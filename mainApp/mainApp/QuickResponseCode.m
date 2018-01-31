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
-(void)generateQRC:(NSSize)size reply:(void (^)(NSImage* qrc))reply
{
    //make request to daemon
    // give me a QRC code y0!
    [daemonComms qrcRequest:^(NSString* qrcInfo)
     {
         //qrc image
         NSImage* qrcImage = nil;
         
         //dbg msg
         logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got qrc from daemon: %@", qrcInfo]);
         
         //save qrc info
         self.qrcInfo = qrcInfo;
         
         //generate QRC image
         qrcImage = [self generateImage:size];
         
         //call back
         reply(qrcImage);
         
     }];
    
    return;
}

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
    
    //create bitmap context
    bitmapRef = CGBitmapContextCreate(nil, CGRectGetWidth(extent) * scale, CGRectGetHeight(extent) * scale, 8, 0, CGColorSpaceCreateDeviceGray(), (CGBitmapInfo)kCGImageAlphaNone);
    
    //create bitmap image
    bitmapImage = [[CIContext contextWithCGContext:bitmapRef options:nil] createCGImage:outputImage fromRect:extent];
    
    //set quality
    CGContextSetInterpolationQuality(bitmapRef, kCGInterpolationNone);
    
    //set scale
    CGContextScaleCTM(bitmapRef, scale, scale);
    
    //draw
    CGContextDrawImage(bitmapRef, extent, bitmapImage);
    
    //create scaled image from bitmap
    scaledImage = CGBitmapContextCreateImage(bitmapRef);
    
    //convert to NSImage
    qrcImage = [[NSImage alloc] initWithCGImage:scaledImage size:size];
    
    //releale bitmap ref
    CGContextRelease(bitmapRef);
    
    //release bitmap
    CGImageRelease(bitmapImage);
    
    //release scaled image
    CGImageRelease(scaledImage);
    
    return qrcImage;
}

@end
