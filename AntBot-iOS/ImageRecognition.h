//
//  ImageRecognition.h
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import <AVFoundation/AVFoundation.h>
#import "Conversions.h"
#import "FinderPattern.h"
#import "ThresholdRange.h"

#import <Decoder.h>
#import <QRCodeReader.h>
#import "TwoDDecoderResult.h"

typedef NS_ENUM(NSInteger, ImageRecognitionTarget) {
    ImageRecognitionTargetTag,
    ImageRecognitionTargetNeighbors,
    ImageRecognitionTargetNest
};

@interface NSObject(ImageRecognitionDelegate)
    -(void) didReceiveAlignInfo:(NSValue*)info;
    -(void) didReadQRCode:(int)qrCode;
@end

@interface ImageRecognition: NSObject <AVCaptureVideoDataOutputSampleBufferDelegate, DecoderDelegate> {
    Conversions *converter;
    IplImage *imgGray;
    IplImage *imgGrayBGRA;
    IplImage *maskIpl;
    
    Decoder *qrDecoder;
    int qrCode;
    
    AVCaptureVideoDataOutput *videoDataOutput;
    AVCaptureVideoPreviewLayer *previewLayer;
    dispatch_queue_t videoDataOutputQueue;
    AVCaptureSession *session;
}

- (UIImage*)getImgThresholdUI;

- (NSMutableArray*)findColorCentroidIn:(CMSampleBufferRef)buffer usingThreshold:(int)threshold;
- (NSMutableArray*)locateQRFinderPatternsIn:(CMSampleBufferRef)buffer;

- (void)startWithTarget:(ImageRecognitionTarget)target;
- (void)stop;

@property id delegate;
@property (nonatomic) ImageRecognitionTarget target;
@property UIView* view;

@end