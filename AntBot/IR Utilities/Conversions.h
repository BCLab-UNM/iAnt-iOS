//
//  Conversions.h
//  AntBot
//
//  Created by Joshua Hecker on 8/29/12.
//
//

#import <AVFoundation/AVFoundation.h>

@interface Conversions : NSObject

@property UIImage *imgThresholdUI;
@property IplImage *imgIpl;
@property NSMutableData *imgData;

- (void)createIplImageFromCMSampleBuffer:(CMSampleBufferRef)buffer;
- (void)createUIImageFromIplImage:(IplImage *)image;
- (IplImage*)createIplImageFromUIImage:(UIImage*)image;

@end
