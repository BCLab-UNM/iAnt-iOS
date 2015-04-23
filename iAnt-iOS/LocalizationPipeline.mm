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

- (NSMutableArray*) findLightLandmarkIn:(CMSampleBufferRef)buffer usingThreshold:(int)threshold {
    //Create output array
    NSMutableArray* lightHeadings = [[NSMutableArray alloc] init];
    
    //Convert input buffer to OpenCV image container
    [converter createIplImageFromCMSampleBuffer:buffer];
    
    //Flip, transpose, flip
    cvFlip([converter imgIpl],[converter imgIpl],1);
    IplImage *t = cvCreateImage(cvSize([converter imgIpl]->height,[converter imgIpl]->width), IPL_DEPTH_8U, 4);
    cvTranspose([converter imgIpl],t);
    cvFlip(t,t,1);
    
    //Convert input image to grayscale
    cvCvtColor(t, imgGray, CV_BGRA2GRAY);
    
    cvReleaseImage(&t);
    //Apply Gaussian blur to smooth out inconsistencies
    cvSmooth(imgGray, imgGray, CV_GAUSSIAN, 9, 9, 9);
    
    //Find circles using circular Hough transform
    CvMemStorage* storage = cvCreateMemStorage(0);
    CvSeq* circles = cvHoughCircles(imgGray, storage, CV_HOUGH_GRADIENT, 1, 20, 100, 50, 160, 180);
    
    //Get first circle in output sequence (if available)
    CvPoint center = cvPoint(imgGray->width/2, imgGray->height/2);
    int radius;
    if (circles->total > 0) {
        float* p = (float*) cvGetSeqElem(circles, 0);
        center = cvPoint(p[0], p[1]);
        radius = p[2] - 53; //magic number used here to shrink to size of inner circle
    }
    else {
        NSLog(@"Hough circle transform did not find any circles in this image");
        return lightHeadings;
    }
    
    //Create mask using circle
    IplImage* mask = cvCreateImage(cvGetSize(imgGray), IPL_DEPTH_8U, 1);
    cvSet(mask, cvScalar(0));
    cvCircle(mask, center, radius, cvScalar(255), -1); //negative line thickness generates filled circle
    
    //Apply mask
    IplImage *temp = cvCreateImage(cvGetSize(imgGray), IPL_DEPTH_8U, 1);
    cvCopy(imgGray, temp);
    cvSet(imgGray, cvScalar(0));
    cvCopy(temp, imgGray, mask);
    
    //Threshold image
    IplImage* imgThreshold = cvCreateImage(cvGetSize(imgGray), IPL_DEPTH_8U, 1);
    cvThreshold(imgGray, imgThreshold, threshold, 255, CV_THRESH_BINARY);
    
    //convert thresholded image back to BGRA for display
    if (imgGrayBGRA != nil) {
        cvReleaseImage(&imgGrayBGRA);
    }
    imgGrayBGRA = cvCreateImage(cvGetSize(imgThreshold), IPL_DEPTH_8U, 4);
    cvCvtColor(imgThreshold, imgGrayBGRA, CV_GRAY2BGRA);
    
    //convert IplImage to UIImage and store
    [converter createUIImageFromIplImage:imgGrayBGRA];
    
    //Free memory
    cvReleaseImage(&temp);
    cvReleaseImage(&mask);
    
    //Find contours
    CvSeq *contour = nil;
    if (cvFindContours(imgThreshold, storage, &contour, sizeof(CvContour))) {
        double largestAreas [2] = {0,0};
        CvSeq largestContours[2];
        for (; contour != 0; contour = contour->h_next) {
            double contourArea = cvContourArea(contour);
            if (contourArea > largestAreas[0]) {
                largestAreas[1] = largestAreas[0];
                largestContours[1] = largestContours[0];
                largestAreas[0] = contourArea;
                largestContours[0] = *contour;
            }
            else if (contourArea > largestAreas[1]) {
                largestAreas[1] = contourArea;
                largestContours[1] = *contour;
            }
        }
        
        //Find centroids
        CvMoments* moments = (CvMoments*)malloc(sizeof(CvMoments));
        for (int i = 0; i < 2; i++) {
            cvMoments(&largestContours[i], moments);
            Polar lightVector = [Utilities cart2pol:Cartesian(moments->m10/moments->m00 - center.x, center.y - moments->m01/moments->m00)];
            float angle = [Utilities angleFrom:0.0 to:lightVector.theta];
            [lightHeadings addObject: [NSNumber numberWithFloat:angle]];
        }
        //Sort array
        [lightHeadings sortUsingSelector:@selector(compare:)];
        //Free memory
        free(moments);
    }
    
    //Free memory
    cvReleaseMemStorage(&storage);
    
    //Free memory
    cvReleaseImage(&imgThreshold);
    
    return lightHeadings;
}

@end