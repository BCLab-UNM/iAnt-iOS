//
//  ImageRecognition.h
//  AntBot
//
//  Created by Joshua Hecker on 3/27/12.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import <AVFoundation/AVFoundation.h>

typedef struct
{
    double x,y;
} Cartesian2D;

@interface ImageRecognition: NSObject

@property Cartesian2D center;
@property UIImage* imgThresholdUI;
@property IplImage* imgIpl;
@property IplImage* imgGrayBGRA;
@property IplImage* maskIpl;

- (ImageRecognition*)imageRecognition;

//Higher-level vision functions
- (Cartesian2D)findColorCentroidIn:(CMSampleBufferRef)buffer usingThreshold:(NSArray*)ranges;
- (BOOL)locateQRFinderPatternIn:(UIImage*)buffer;
- (BOOL)checkFinderRatioFor:(int[5])stateCount;

//UIImage <--> IplImage functions
- (void)createIplImageFromCMSampleBuffer:(CMSampleBufferRef)buffer;
- (UIImage*)createUIImageFromIplImage:(IplImage *)image;
- (IplImage*)createIplImageFromUIImage:(UIImage*)image;

@end

@interface ThresholdRange: NSObject
{
    CvScalar min;
    CvScalar max;
}

- (ThresholdRange*)initMinTo:(CvScalar)min andMaxTo:(CvScalar)max;

- (CvScalar) getMin;
- (CvScalar) getMax;

@end