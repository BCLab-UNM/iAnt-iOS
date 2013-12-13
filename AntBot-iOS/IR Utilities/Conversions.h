//
//  Conversions.h
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import <AVFoundation/AVFoundation.h>

@interface Conversions : NSObject

@property UIImage *imgThresholdUI;
@property IplImage *imgIpl;
@property NSMutableData *imgData;

+ (UIImage*)rotateUIImage:(UIImage*)image customRadians:(float)radians;
- (void)createIplImageFromCMSampleBuffer:(CMSampleBufferRef)buffer;
+ (UIImage*)createUIImageFromCMSampleBuffer:(CMSampleBufferRef)buffer;
- (void)createUIImageFromIplImage:(IplImage *)image;
- (IplImage*)createIplImageFromUIImage:(UIImage*)image;

@end
