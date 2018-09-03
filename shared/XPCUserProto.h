//
//  file: XPCUserProtocol
//  project: DND (shared)
//  description: protocol for talking to the user (header)
//
//  created by Patrick Wardle
//  copyright (c) 2018 Objective-See. All rights reserved.
//

@import Foundation;

@protocol XPCUserProtocol

//show an alert
// returns with rep
-(void)alertShow:(NSDictionary*)alert;

//dismiss alert(s)
-(void)alertDismiss;

//take a picture
-(void)captureImage:(void (^)(NSData *))reply;

@end

