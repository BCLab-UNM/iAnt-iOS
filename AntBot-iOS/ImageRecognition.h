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

@interface ImageRecognition: NSObject {
    Conversions *converter;
    IplImage *imgGray;
    IplImage *imgGrayBGRA;
    IplImage *maskIpl;
}

- (id)initResolutionTo:(int)vertical by:(int)horizontal;

- (UIImage*)getImgThresholdUI;

- (NSMutableArray*)findColorCentroidIn:(CMSampleBufferRef)buffer usingThreshold:(int)threshold;
- (NSMutableArray*)locateQRFinderPatternsIn:(CMSampleBufferRef)buffer;

@end