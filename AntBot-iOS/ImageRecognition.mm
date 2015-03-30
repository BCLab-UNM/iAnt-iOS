//
//  ImageRecognition.mm
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "ImageRecognition.h"

const int FRONT_REZ_VERT = 192;
const int FRONT_REZ_HOR = 144;
const int NEST_THRESHOLD = 240;

#pragma mark - ImageRecognition interface

@implementation ImageRecognition

@synthesize delegate, view;
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
        
        return self;
    }
    
    return nil;
}

- (UIImage*)getImgThresholdUI {
    return [converter imgThresholdUI];
}

- (void)start {
    [self stop];
    [self setupAVCapture];
}

- (void)setupAVCapture {
    
    AVCaptureDevicePosition position = AVCaptureDevicePositionFront;
    
	session = [[AVCaptureSession alloc] init];
    [session setSessionPreset:AVCaptureSessionPresetLow];
	
    // Select a video device, make an input
    AVCaptureDeviceInput *deviceInput;
    for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
		if ([d position] == position) {
            deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:(AVCaptureDevice*)d error:nil];
            [[UIScreen mainScreen] setBrightness:0];
            NSError *message = nil;
            if ([d lockForConfiguration:&message]) {
                [d setWhiteBalanceMode:AVCaptureWhiteBalanceModeLocked];
                [d setExposureMode:AVCaptureExposureModeLocked];
            }
            else {
                NSLog(@"%@",[message localizedDescription]);
            }
        }
    }
	
	if ([session canAddInput:deviceInput]) {
		[session addInput:deviceInput];
    }
	
    // Make a video data output
	videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
	
    // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
	NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:
									   [NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
	[videoDataOutput setVideoSettings:rgbOutputSettings];
    
    // discard if the data output queue is blocked (as we process the still image)
	[videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    // create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured
    // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
    // see the header doc for setSampleBufferDelegate:queue: for more information
	videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
	[videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
	
    if ([session canAddOutput:videoDataOutput]) {
		[session addOutput:videoDataOutput];
    }
	[[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
	
	previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
	[previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
	[previewLayer setVideoGravity:AVLayerVideoGravityResize];
	CALayer *rootLayer = [view layer];
	[rootLayer setMasksToBounds:YES];
	[previewLayer setFrame:[rootLayer bounds]];
	[rootLayer addSublayer:previewLayer];
	[session startRunning];
}

- (void)stop {
    [session stopRunning];
	[previewLayer removeFromSuperlayer];
    [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:NO];
}

//AVCapture callback, triggered when a new frame (i.e. image) arrives from video stream
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    //Wrap all instructions in autoreleasepool
    //This ensures release of objects from background thread
    @autoreleasepool {
        //Create storage variables
        short int data[2] = {0,0};
        CvRect centroid;
        
        //Create block object that hides all layers
        void (^hideAllLayers)(void) = ^{
            NSEnumerator *index = [[previewLayer sublayers] objectEnumerator];
            CALayer *featureLayer = nil;
            //Enumerate through sublayers
            while (featureLayer = [index nextObject]) {
                //Hide layer
                if (![featureLayer isHidden]) {
                    [featureLayer setHidden:YES];
                }
            }
        };

        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
        
        //If centroid was found
        if ([self findColorCentroid:centroid in:sampleBuffer usingThreshold:NEST_THRESHOLD]) {
            //Ensure mocapHeading observer has been removed
            /*@try {
                [server removeObserver:self forKeyPath:@"mocapHeading"];
            }
            @catch (NSException *exception) {
                //do nothing, observer was already removed
            }*/
            
            CALayer *featureLayer = nil;
            //Load relevant images
            UIImage *square = [UIImage imageNamed:@"squarePNG"];
            UIImage *imgThreshold = [self getImgThresholdUI]; //thresholded
            
            //If at least two sublayers exist
            if ([[previewLayer sublayers] count] >= 2) {
                //Load the top layer (layer two, currently stores the thresholded image received in the last capture)
                featureLayer = [[previewLayer sublayers] objectAtIndex:1];
            }
            //If only one sublayer exists (true on first execution of method, only the root layer exists)
            else if ([[previewLayer sublayers] count] >= 1) {
                //Create a layer for the thresholded image and add to preview
                featureLayer = [[CALayer alloc] init];
                [previewLayer addSublayer:featureLayer];
                //Rotate layer by 90 degrees clockwise, then rotate it 180 degrees around the y-axis
                [featureLayer setTransform:CATransform3DScale(CATransform3DMakeRotation(M_PI_2, 0, 0, 1),1, -1, 1)];
                //Set the layer frame size
                CGRect rect = CGRectMake(0, 0,[view frame].size.width, [view frame].size.height);
                [featureLayer setFrame:rect];
            }
            //Otherwise, there must be zero sublayers, meaning our AVCapture session has been torn down, so we exit
            else {
                [CATransaction commit];
                return;
            }
            
            //Add new thresholded image to frame, replacing the previous found
            [featureLayer setContents:(id)[imgThreshold CGImage]];
            [featureLayer setHidden:NO];
            
            //Create or load sublayer (layer three) to store square image
            if ([[previewLayer sublayers] count] == 2) {
                featureLayer = [[CALayer alloc] init];
                [previewLayer addSublayer:featureLayer];
                [featureLayer setContents:(id)[square CGImage]];
            }
            else {
                featureLayer = [[previewLayer sublayers] objectAtIndex:2];
            }
            
            CGRect rect;
            //Create frame for square image
            rect = CGRectMake(centroid.y * ([view frame].size.width/FRONT_REZ_HOR),
                              centroid.x * ([view frame].size.height/FRONT_REZ_VERT),
                              centroid.height * ([view frame].size.width/FRONT_REZ_HOR),
                              centroid.width * ([view frame].size.height/FRONT_REZ_VERT));
            //Check for valid numbers before applying rectangle
            if ((rect.origin.x == rect.origin.x) && (rect.origin.y == rect.origin.y) &&
                (rect.size.height == rect.size.height) && (rect.size.width == rect.size.width)) {
                [featureLayer setFrame:rect];
                //Ensure layer is visible
                [featureLayer setHidden:NO];
            }
            
            //Number of pixels between observed and true center
            data[0] = FRONT_REZ_HOR / 2 - centroid.y;
            
            //Update estimate of distance from nest
            nestDistance = 1481 * pow(centroid.height * centroid.width, -0.5127) - 50;
            
            // Notify delegate, assuming session is currently running
            dispatch_async(dispatch_get_main_queue(), ^{
                if([session isRunning] && delegate && [delegate respondsToSelector:@selector(didReceiveAlignInfo:)]) {
                    [delegate didReceiveAlignInfo:[NSValue valueWithCGPoint:CGPointMake(FRONT_REZ_HOR / 2 - centroid.y, 0)]];
                }
            });
        }
        
        //If no centroids were found
        else {
            hideAllLayers();
            
            //Construct maintenance message
            data[0] = SHRT_MAX;
            
            // Notify delegate
            dispatch_async(dispatch_get_main_queue(), ^{
                if(delegate && [delegate respondsToSelector:@selector(didReceiveAlignInfo:)]) {
                    [delegate didReceiveAlignInfo:[NSValue valueWithCGPoint:CGPointMake(FRONT_REZ_HOR / 2, 0)]];
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