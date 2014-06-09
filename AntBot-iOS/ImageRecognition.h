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

NS_ENUM(NSInteger, ImageRecognitionTarget) {
    ImageRecognitionQRCode,
    ImageRecognitionNest
};

@interface ImageRecognition: NSObject <AVCaptureVideoDataOutputSampleBufferDelegate, DecoderDelegate> {
    Conversions *converter;
    IplImage *imgGray;
    IplImage *imgGrayBGRA;
    IplImage *maskIpl;
    
    Decoder *qrDecoder;
    
    AVCaptureVideoDataOutput *videoDataOutput;
    AVCaptureVideoPreviewLayer *previewLayer;
    dispatch_queue_t videoDataOutputQueue;
    AVCaptureSession *session;
    
    NSString* target;
    UIView* view;
}

- (id)initResolutionTo:(int)vertical by:(int)horizontal target:(NSString*)target view:(UIView*)view;

- (UIImage*)getImgThresholdUI;

- (NSMutableArray*)findColorCentroidIn:(CMSampleBufferRef)buffer usingThreshold:(int)threshold;
- (NSMutableArray*)locateQRFinderPatternsIn:(CMSampleBufferRef)buffer;

- (void)setupAVCaptureAt:(AVCaptureDevicePosition)position;
- (void)teardownAVCapture;

@property id delegate;

@end