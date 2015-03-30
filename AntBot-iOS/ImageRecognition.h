//
//  ImageRecognition.h
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import <AVFoundation/AVFoundation.h>
#import "Conversions.h"

@interface NSObject(ImageRecognitionDelegate)
    -(void) didReceiveAlignInfo:(NSValue*)info;
@end

@interface ImageRecognition: NSObject <AVCaptureVideoDataOutputSampleBufferDelegate> {
    Conversions *converter;
    IplImage *imgGray;
    IplImage *imgGrayBGRA;
    IplImage *maskIpl;
    
    AVCaptureVideoDataOutput *videoDataOutput;
    AVCaptureVideoPreviewLayer *previewLayer;
    dispatch_queue_t videoDataOutputQueue;
    AVCaptureSession *session;
}

- (UIImage*)getImgThresholdUI;

- (BOOL)findColorCentroid:(CvRect&)centroid in:(CMSampleBufferRef)buffer usingThreshold:(int)threshold;

- (void)start;
- (void)stop;

@property id delegate;
@property UIView* view;

@property float nestDistance;

@end