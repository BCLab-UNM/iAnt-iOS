#import "LocalizationPipeline.h"

const int FRONT_REZ_VERT = 192;
const int FRONT_REZ_HOR = 144;
const int NEST_THRESHOLD = 240;
#define QUALITY AVCaptureSessionPresetLow

#pragma mark - LocalizationPipeline interface

@implementation LocalizationPipeline

@synthesize devicePosition, quality, delegate;
@synthesize nestDistance;

- (id)init {
    if(self = [super init]) {
        converter = [Conversions new];
        
        [converter setImgIpl:cvCreateImage(cvSize(FRONT_REZ_VERT, FRONT_REZ_HOR), IPL_DEPTH_8U, 4)];
        [converter setImgData:[NSMutableData new]];
        imgGray = cvCreateImage(cvSize(FRONT_REZ_VERT, FRONT_REZ_HOR), IPL_DEPTH_8U, 1);
        imgGrayBGRA = cvCreateImage(cvSize(FRONT_REZ_VERT, FRONT_REZ_HOR), IPL_DEPTH_8U, 4);
        
        //Load mask
        UIImage *maskUI = [UIImage imageNamed:@"mask"];
        maskIpl = [converter createIplImageFromUIImage:maskUI];
        
        devicePosition = AVCaptureDevicePositionFront;
        quality = QUALITY;
        
        return self;
    }
    
    return nil;
}

- (UIImage*)getImgThresholdUI {
    return [converter imgThresholdUI];
}

//AVCapture callback, triggered when a new frame (i.e. image) arrives from video stream
-(void)didReceiveFrame:(CMSampleBufferRef)frame fromCamera:(Camera *)camera {
    //Wrap all instructions in autoreleasepool
    //This ensures release of objects from background thread
    @autoreleasepool {
        CvRect centroid;

        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
        
        //If centroid was found
        if ([self findColorCentroid:centroid in:frame usingThreshold:NEST_THRESHOLD]) {
            //Create rectangle to contain object
            CGRect rect = CGRectMake(centroid.y * ([[camera view] frame].size.width/FRONT_REZ_HOR),
                              centroid.x * ([[camera view] frame].size.height/FRONT_REZ_VERT),
                              centroid.height * ([[camera view] frame].size.width/FRONT_REZ_HOR),
                              centroid.width * ([[camera view] frame].size.height/FRONT_REZ_VERT));
            UIBezierPath* path = [UIBezierPath bezierPathWithRect:rect];
            [[camera shapeLayer] setPath:[path CGPath]];
            
            //Update estimate of distance from nest
            nestDistance = 1481 * pow(centroid.height * centroid.width, -0.5127) - 50;
            
            // Notify delegate, assuming session is currently running
            dispatch_async(dispatch_get_main_queue(), ^{
                if(delegate && [delegate respondsToSelector:@selector(pipeline:didProcessFrame:)]) {
                    [delegate pipeline:self didProcessFrame:[NSValue valueWithCGPoint:CGPointMake(FRONT_REZ_HOR / 2 - centroid.y, 0)]];
                }
            });
        }
        
        //If no centroids were found
        else {
            [[camera shapeLayer] setPath:nil];
            // Notify delegate
            dispatch_async(dispatch_get_main_queue(), ^{
                if(delegate && [delegate respondsToSelector:@selector(pipeline:didProcessFrame:)]) {
                    [delegate pipeline:self didProcessFrame:[NSValue valueWithCGPoint:CGPointMake(FRONT_REZ_HOR / 2, 0)]];
                }
            });
        }
        
        [CATransaction commit];
    }
}

#pragma mark - Higher-level vision functions

- (BOOL)findColorCentroid:(CvRect&)centroid in:(CMSampleBufferRef)buffer usingThreshold:(int)threshold {
    BOOL centroidExists = NO;
    
    //convert CMSampleBuffer to IplImage
    [converter createIplImageFromCMSampleBuffer:buffer];
    
    //Make copy of original image and wipe it (set all pixels to black)
    IplImage *temp = cvCreateImage(cvGetSize([converter imgIpl]), IPL_DEPTH_8U, 4);
    cvCopy([converter imgIpl], temp);
    cvSet([converter imgIpl], CV_RGB(0, 0, 0));
    
    //Apply mask to copy to generate final image
    cvCopy(temp, [converter imgIpl], maskIpl);
    cvReleaseImage(&temp);
    
    //converter to grayscale
    cvCvtColor([converter imgIpl], imgGray, CV_BGRA2GRAY);

    //Threshold image
    IplImage* imgThreshold = cvCreateImage(cvGetSize([converter imgIpl]), IPL_DEPTH_8U, 1);
    cvThreshold(imgGray, imgThreshold, threshold, 255, CV_THRESH_BINARY);
    
    //convert thresholded image back to BGRA for display (see captureOutput callback in MainController)
    cvCvtColor(imgThreshold, imgGrayBGRA, CV_GRAY2BGRA);
    [converter createUIImageFromIplImage:imgGrayBGRA];
     
    //Locate contours
    CvSeq *contour = 0;
    CvMemStorage *storage = cvCreateMemStorage(0);
    if (cvFindContours(imgThreshold, storage, &contour, sizeof(CvContour), CV_RETR_EXTERNAL, CV_CHAIN_APPROX_NONE)) {    
        //Find largest contour
        double largestArea = 0;
        CvSeq *largestContour = nil;
        for (; contour != 0; contour = contour->h_next) {
            double contourArea = cvContourArea(contour);
            if (contourArea > largestArea) {
                largestArea = contourArea;
                largestContour = contour;
            }
        }
        
        //If largest contour exists
        if (largestContour != nil) {
            //Calculate bounding box for largest contour
            centroid = cvBoundingRect(largestContour);
            centroidExists = YES;
        }
    }
    
    //Free memory
    cvReleaseMemStorage(&storage);
    
    //Free memory
    cvReleaseImage(&imgThreshold);
    
    return centroidExists;
}

@end