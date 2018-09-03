//
//  Camera.h
//  loginItem
//
//  Created by Patrick Wardle on 9/1/18.
//  Copyright © 2018 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface Camera : NSObject

/* PROPERTIES */

//av session
@property(nonatomic, retain)AVCaptureSession* session;

/* METHODS */

//capture an image from the webcam
-(NSData*)captureImage;



@end

