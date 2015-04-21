#import <AVFoundation/AVFoundation.h>
#import "Camera.h"
#import "CameraView.h"
#import "Conversions.h"

@interface LocalizationPipeline: NSObject <CameraPipeline> {
    Conversions *converter;
    IplImage *imgGray;
    IplImage *imgGrayBGRA;
    IplImage *maskIpl;
}

- (UIImage*)getImgThresholdUI;
- (BOOL)findColorCentroid:(CvRect&)centroid in:(CMSampleBufferRef)buffer usingThreshold:(int)threshold;

@property float nestDistance;

@end