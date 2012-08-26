//
//  ImageRecognition.h
//  AntBot
//
//  Created by Joshua Hecker on 3/27/12.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import <AVFoundation/AVFoundation.h>

@interface ImageRecognition: NSObject

@property UIImage* imgThresholdUI;
@property IplImage* imgIpl;
@property IplImage* imgGrayBGRA;
@property IplImage* maskIpl;

- (ImageRecognition*)imageRecognition;

//Higher-level vision functions
- (CvPoint)findColorCentroidIn:(CMSampleBufferRef)buffer usingThreshold:(NSArray*)ranges;
- (int)locateQRFinderPatternsIn:(UIImage*)buffer;
- (int)checkFinderRatioFor:(int[5])stateCount;

//UIImage <--> IplImage functions
- (void)createIplImageFromCMSampleBuffer:(CMSampleBufferRef)buffer;
- (UIImage*)createUIImageFromIplImage:(IplImage *)image;
- (IplImage*)createIplImageFromUIImage:(UIImage*)image;

@end

@interface LineSegment2D : NSObject {
    CvPoint start;
    CvPoint end;
}

- (LineSegment2D*)initStartTo:(CvPoint)start andEndTo:(CvPoint)end;

- (CvPoint)getStart;
- (CvPoint)getEnd;

@end

@interface FinderPattern : NSObject

@property NSMutableArray *segments;
@property BOOL modifiedFlag;

@end

@interface ThresholdRange: NSObject {
    CvScalar min;
    CvScalar max;
}

- (ThresholdRange*)initMinTo:(CvScalar)min andMaxTo:(CvScalar)max;

- (CvScalar)getMin;
- (CvScalar)getMax;

@end