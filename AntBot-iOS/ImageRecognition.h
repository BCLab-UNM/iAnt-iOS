//
//  ImageRecognition.h
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import <AVFoundation/AVFoundation.h>
#import "Camera.h"
#import "CameraView.h"
#import "Conversions.h"

@interface ImageRecognition: NSObject <CameraPipeline> {
    Conversions *converter;
    IplImage *imgGray;
    IplImage *imgGrayBGRA;
    IplImage *maskIpl;
}

- (UIImage*)getImgThresholdUI;
- (BOOL)findColorCentroid:(CvRect&)centroid in:(CMSampleBufferRef)buffer usingThreshold:(int)threshold;

@property float nestDistance;

@end