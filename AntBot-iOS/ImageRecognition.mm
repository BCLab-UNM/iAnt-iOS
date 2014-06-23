//
//  ImageRecognition.mm
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "ImageRecognition.h"

const int BACK_REZ_VERT = 352;
const int BACK_REZ_HOR = 288;
const int FRONT_REZ_VERT = 192;
const int FRONT_REZ_HOR = 144;
const int NEST_THRESHOLD = 240;

#pragma mark - ImageRecognition interface

@implementation ImageRecognition

@synthesize delegate, target, view;
@synthesize nestDistance;

- (id)init {
    if(self = [super init]) {
        converter = [Conversions new];
        
        //Load mask for forward-facing camera
        UIImage *maskUI = [UIImage imageNamed:@"mask"];
        maskIpl = [converter createIplImageFromUIImage:maskUI];
        
        qrDecoder = [[Decoder alloc] init];
        NSMutableSet *readers = [[NSMutableSet alloc] init];
        QRCodeReader* qrcodeReader = [[QRCodeReader alloc] init];
        [readers addObject:qrcodeReader];
        [qrDecoder setReaders:readers];
        [qrDecoder setDelegate:self];
        
        return self;
    }
    
    return nil;
}

- (void)setTarget:(ImageRecognitionTarget)_target {
    
    // Back camera
    if(_target == ImageRecognitionTargetNeighbors || _target == ImageRecognitionTargetTag) {
        [converter setImgIpl:cvCreateImage(cvSize(BACK_REZ_VERT, BACK_REZ_HOR), IPL_DEPTH_8U, 4)];
        [converter setImgData:[NSMutableData new]];
        imgGray = cvCreateImage(cvSize(BACK_REZ_VERT, BACK_REZ_HOR), IPL_DEPTH_8U, 1);
        imgGrayBGRA = cvCreateImage(cvSize(BACK_REZ_VERT, BACK_REZ_HOR), IPL_DEPTH_8U, 4);
    }
    
    // Front camera
    else {
        [converter setImgIpl:cvCreateImage(cvSize(FRONT_REZ_VERT, FRONT_REZ_HOR), IPL_DEPTH_8U, 4)];
        [converter setImgData:[NSMutableData new]];
        imgGray = cvCreateImage(cvSize(FRONT_REZ_VERT, FRONT_REZ_HOR), IPL_DEPTH_8U, 1);
        imgGrayBGRA = cvCreateImage(cvSize(FRONT_REZ_VERT, FRONT_REZ_HOR), IPL_DEPTH_8U, 4);
    }
    
    target = _target;
}

- (UIImage*)getImgThresholdUI {
    return [converter imgThresholdUI];
}

- (void)startWithTarget:(ImageRecognitionTarget)_target {
    [self stop];
    [self setTarget:_target];
    [self setupAVCapture];
}

- (void)setupAVCapture {
    
    AVCaptureDevicePosition position;
    if(target == ImageRecognitionTargetNest) {
        position = AVCaptureDevicePositionFront;
    }
    else {
        position = AVCaptureDevicePositionBack;
    }
    
	session = [[AVCaptureSession alloc] init];
	if (position == AVCaptureDevicePositionBack) {
	    [session setSessionPreset:AVCaptureSessionPreset352x288];
    }
	else if (position == AVCaptureDevicePositionFront){
	    [session setSessionPreset:AVCaptureSessionPresetLow];
    }
	
    // Select a video device, make an input
    AVCaptureDeviceInput *deviceInput;
    for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
		if ([d position] == position) {
            deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:(AVCaptureDevice*)d error:nil];
            [[UIScreen mainScreen] setBrightness:0];
            NSError *message = nil;
            if ([d lockForConfiguration:&message]) {
                [d setWhiteBalanceMode:AVCaptureWhiteBalanceModeLocked];
                if (position == AVCaptureDevicePositionFront) {
                    [d setExposureMode:AVCaptureExposureModeLocked];
                }
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
	if (videoDataOutputQueue)
		dispatch_release(videoDataOutputQueue);
	[previewLayer removeFromSuperlayer];
    [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:NO];
}

//AVCapture callback, triggered when a new frame (i.e. image) arrives from video stream
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    //Wrap all instructions in autoreleasepool
    //This ensures release of objects from background thread
    @autoreleasepool {
        //If tag has been found, we are searching for neighbors
        if (target == ImageRecognitionTargetNeighbors) {
            //Filter image
            [self locateQRFinderPatternsIn:sampleBuffer];
            
            //Load relevant images
            UIImage *img = [Conversions createUIImageFromCMSampleBuffer:sampleBuffer]; //original
            UIImage *img22 = [Conversions rotateUIImage:img customRadians:(M_PI_4/2.f)]; //rotated 22.5 degrees
            UIImage *img45 = [Conversions rotateUIImage:img customRadians:M_PI_4]; //rotated 45 degrees
            UIImage *img67 = [Conversions rotateUIImage:img customRadians:(M_PI_4 + M_PI_4/2.f)]; //rotated 67.5 degrees
            UIImage *imgThreshold = [self getImgThresholdUI]; //thresholded
            
            //Check tag image for QR code
            //Note that we exploit lazy evaluation here to avoid detecting the same QR tag multiple times
            [qrDecoder decodeImage:img] ||
            [qrDecoder decodeImage:img22] ||
            [qrDecoder decodeImage:img45] ||
            [qrDecoder decodeImage:img67] ||
            [qrDecoder decodeImage:imgThreshold];
        }
        //Otherwise
        else {
            //Create storage variables
            short int data[2] = {0,0};
            int numberOfCentroids;
            NSMutableArray *centroidList = [[NSMutableArray alloc] init];
            
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
            
            //If searching for nest
            if (target == ImageRecognitionTargetNest) {
                //Retrieve nest centroid
                centroidList = [self findColorCentroidIn:sampleBuffer usingThreshold:NEST_THRESHOLD];
            }
            //If searching for tags
            else if (target == ImageRecognitionTargetTag) {
                //Retrieve list of finder pattern centroids
                centroidList = [self locateQRFinderPatternsIn:sampleBuffer];
            }
            
            [CATransaction begin];
            [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
            
            //If centroids were found
            if ((numberOfCentroids = [centroidList count])) {
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
                UIImage *img = [Conversions createUIImageFromCMSampleBuffer:sampleBuffer]; //original
                UIImage *img22 = [Conversions rotateUIImage:img customRadians:(M_PI_4/2.f)]; //rotated 22.5 degrees
                UIImage *img45 = [Conversions rotateUIImage:img customRadians:M_PI_4]; //rotated 45 degrees
                UIImage *img67 = [Conversions rotateUIImage:img customRadians:(M_PI_4 + M_PI_4/2.f)]; //rotated 67.5 degrees
                UIImage *imgThreshold = [self getImgThresholdUI]; //thresholded
                
                //If we are searching for tags, and a tag has been found in the image
                //Note that we exploit lazy evaluation here to avoid detecting the same QR tag multiple times
                if (target == ImageRecognitionTargetTag && ([qrDecoder decodeImage:img] ||
                                                                [qrDecoder decodeImage:img22] ||
                                                                [qrDecoder decodeImage:img45] ||
                                                                [qrDecoder decodeImage:img67] ||
                                                                [qrDecoder decodeImage:imgThreshold])) {
                    //Transmit stop messages to Arduino (two are required)
                    //[cable send:[NSString stringWithFormat:@"(%d,%d)", data[0], data[1]]];
                    //[cable send:[NSString stringWithFormat:@"(%d,%d)", data[0], data[1]]];
                    
                    //Hide all layers
                    hideAllLayers();
                    
                    target = ImageRecognitionTargetNeighbors;
                }
                //Otherwise
                else {
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
                        //If using front camera to search for nest
                        if (target == ImageRecognitionTargetNest) {
                            //Rotate layer by 90 degrees clockwise, then rotate it 180 degrees around the y-axis
                            [featureLayer setTransform:CATransform3DScale(CATransform3DMakeRotation(M_PI_2, 0, 0, 1),
                                                                          1, -1, 1)];
                        }
                        //If using back camera to search for tags
                        else if (target == ImageRecognitionTargetTag) {
                            //Rotate layer by 90 degrees clockwise
                            [featureLayer setTransform:CATransform3DScale(CATransform3DMakeRotation(M_PI_2, 0, 0, 1),
                                                                          1, 1, 1)];
                        }
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
                    
                    //Ensure thresholded image layer is visible
                    if ([[previewLayer sublayers] count] > 1) {
                        [[[previewLayer sublayers] objectAtIndex:1] setHidden:NO];
                    }
                    
                    //Enumerate through sublayers
                    NSEnumerator *index = [[previewLayer sublayers] objectEnumerator];
                    Rect2D *center = nil;
                    Rect2D *meanCenter = [[Rect2D alloc] init];
                    [index nextObject]; [index nextObject]; //advance enumerator two spots, start at layer three
                    while (featureLayer = [index nextObject]) {
                        //Copy center from list
                        center = [centroidList lastObject];
                        //If list is empty (all centroids have been added to layers)
                        if (!center) {
                            //Hide current layer
                            [featureLayer setHidden:YES];
                            //Skip to next iteration; don't break because we need to hide subsequent layers
                            continue;
                        }
                        //Remove from list
                        if ([centroidList count] > 0) {
                            [centroidList removeLastObject];
                        }
                        //Update summation
                        meanCenter = [[Rect2D alloc] initXTo:([meanCenter getX] + [center getX])
                                                         yTo:([meanCenter getY] + [center getY])
                                                     widthTo:[center getWidth]
                                                    heightTo:[center getHeight]
                                                      areaTo:[center getArea]];
                        
                        CGRect rect;
                        //If using front camera to search for nest
                        if (target == ImageRecognitionTargetNest) {
                            //Create frame for square image
                            rect = CGRectMake(([center getX] - [center getHeight]/2) * ([view frame].size.width/FRONT_REZ_HOR),
                                              ([center getY] - [center getWidth]/2) * ([view frame].size.height/FRONT_REZ_VERT),
                                              [center getHeight]*([view frame].size.width/FRONT_REZ_HOR),
                                              [center getWidth]*([view frame].size.height/FRONT_REZ_VERT));
                        }
                        //If using back camera to search for tags
                        if (target == ImageRecognitionTargetTag) {
                            //Create frame for square image
                            rect = CGRectMake((BACK_REZ_HOR - [center getX] - [center getHeight]/2) * ([view frame].size.width/BACK_REZ_HOR),
                                              ([center getY] - [center getWidth]/2) * ([view frame].size.height/BACK_REZ_VERT),
                                              [center getHeight]*([view frame].size.width/BACK_REZ_HOR),
                                              [center getWidth]*([view frame].size.height/BACK_REZ_VERT));
                        }
                        //Check for valid numbers before applying rectangle
                        if ((rect.origin.x == rect.origin.x) && (rect.origin.y == rect.origin.y) &&
                            (rect.size.height == rect.size.height) && (rect.size.width == rect.size.width)) {
                            [featureLayer setFrame:rect];
                            //Ensure layer is visible
                            [featureLayer setHidden:NO];
                        }
                    }
                    
                    //Enumerate through remaining centroids
                    index = [centroidList objectEnumerator];
                    while (center = [index nextObject]) {
                        //Create new layer and add to preview
                        featureLayer = [[CALayer alloc] init];
                        [previewLayer addSublayer:featureLayer];
                        
                        CGRect rect;
                        //If using front camera to search for nest
                        if (target == ImageRecognitionTargetNest) {
                            //Create frame for square image
                            rect = CGRectMake(([center getX] - [center getHeight]/2) * ([view frame].size.width/FRONT_REZ_HOR),
                                              ([center getY] - [center getWidth]/2) * ([view frame].size.height/FRONT_REZ_VERT),
                                              [center getHeight]*([view frame].size.width/FRONT_REZ_HOR),
                                              [center getWidth]*([view frame].size.height/FRONT_REZ_VERT));
                        }
                        //If using back camera to search for tags
                        if (target == ImageRecognitionTargetTag) {
                            //Create frame for square image
                            rect = CGRectMake((BACK_REZ_HOR - [center getX] - [center getHeight]/2) * ([view frame].size.width/BACK_REZ_HOR),
                                              ([center getY] - [center getWidth]/2) * ([view frame].size.height/BACK_REZ_VERT),
                                              [center getHeight]*([view frame].size.width/BACK_REZ_HOR),
                                              [center getWidth]*([view frame].size.height/BACK_REZ_VERT));
                        }
                        //Check for valid numbers before applying rectangle
                        if ((rect.origin.x == rect.origin.x) && (rect.origin.y == rect.origin.y) &&
                            (rect.size.height == rect.size.height) && (rect.size.width == rect.size.width)) {
                            [featureLayer setFrame:rect];
                        }
                        
                        //Add new thresholded image to frame, replacing the previous found
                        [featureLayer setContents:(id)[square CGImage]];
                        
                        //Update summation
                        meanCenter = [[Rect2D alloc] initXTo:([meanCenter getX] + [center getX])
                                                         yTo:([meanCenter getY] + [center getY])
                                                     widthTo:[center getWidth]
                                                    heightTo:[center getHeight]
                                                      areaTo:[center getArea]];
                    }
                    
                    //Calulate mean centroid
                    meanCenter = [[Rect2D alloc] initXTo:([meanCenter getX]/numberOfCentroids)
                                                     yTo:([meanCenter getY]/numberOfCentroids)
                                                 widthTo:[meanCenter getWidth]
                                                heightTo:[meanCenter getHeight]
                                                  areaTo:[meanCenter getArea]];
                    
                    if (target == ImageRecognitionTargetNest) {
                        //Number of pixels between observed and true center
                        data[0] = FRONT_REZ_HOR / 2 - [meanCenter getX];
                        
                        //Update estimate of distance from nest
                        nestDistance = 1481 * pow([meanCenter getArea], -0.5127) - 50;
                        
                        // Notify delegate
                        if(delegate && [delegate respondsToSelector:@selector(didReceiveAlignInfo:)]) {
                            [delegate didReceiveAlignInfo:[NSValue valueWithCGPoint:CGPointMake(data[0], data[1])]];
                        }
                    }
                    else if (target == ImageRecognitionTargetTag) {
                        //Number of pixels between observed and true center
                        data[0] = -(BACK_REZ_HOR/2 - [meanCenter getX]);
                        data[1] = BACK_REZ_VERT/2 - [meanCenter getY];
                        
                        // Notify delegate
                        if(delegate && [delegate respondsToSelector:@selector(didReceiveAlignInfo:)]) {
                            [delegate didReceiveAlignInfo:[NSValue valueWithCGPoint:CGPointMake(data[0], data[1])]];
                        }
                    }
                }
            }
            
            //If no centroids were found
            else {
                hideAllLayers();
                
                //If searching for nest
                if (target == ImageRecognitionTargetNest) {
                    //Construct maintenance message
                    data[0] = SHRT_MAX;
                    
                    // Notify delegate
                    if(delegate && [delegate respondsToSelector:@selector(didReceiveAlignInfo:)]) {
                        [delegate didReceiveAlignInfo:[NSValue valueWithCGPoint:CGPointMake(data[0], data[1])]];
                    }
                }
            }
            
            [CATransaction commit];
        }
    }
}

#pragma mark - Decoder methods

// TODO extract into dedicated QR code reader class?

- (void)decoder:(Decoder *)decoder didDecodeImage:(UIImage *)image usingSubset:(UIImage *)subset withResult:(TwoDDecoderResult *)result {
    //If new code is different from previously found code
    if([[result text] intValue] != qrCode) {
        
        //Create copy of code
        qrCode = [[result text] intValue];
        
        if(delegate && [delegate respondsToSelector:@selector(didReadQRCode:)]) {
            [delegate didReadQRCode:qrCode];
        }
    }
}

#pragma mark - Higher-level vision functions

- (NSMutableArray*)findColorCentroidIn:(CMSampleBufferRef)buffer usingThreshold:(int)threshold {
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
    if (imgGrayBGRA != nil) {
        cvReleaseImage(&imgGrayBGRA);
    }
    imgGrayBGRA = cvCreateImage(cvGetSize([converter imgIpl]), IPL_DEPTH_8U, 4);
    cvCvtColor(imgThreshold, imgGrayBGRA, CV_GRAY2BGRA);
    
    //convert IplImage to UIImage and store
    [converter createUIImageFromIplImage:imgGrayBGRA];
     
    //Locate contours
    NSMutableArray *centroidList = nil;
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
    
        Rect2D *c = nil;
        //If largest contour exists
        if (largestContour != nil) {
            //Calculate bounding box for largest contour
            CvRect boundingBox = cvBoundingRect(largestContour);
            
            //Create centroid structure
            c = [[Rect2D alloc] initXTo:boundingBox.y+(boundingBox.height/2) yTo:boundingBox.x+(boundingBox.width/2)
                                widthTo:boundingBox.width heightTo:boundingBox.height areaTo:largestArea];

            //And add it to the array for output
            centroidList = [[NSMutableArray alloc] initWithObjects:c, nil];
        }
    }
    
    //Free memory
    cvReleaseMemStorage(&storage);
    
    //Free memory
    cvReleaseImage(&imgThreshold);    
    
    return centroidList;
}

- (NSMutableArray*)locateQRFinderPatternsIn:(CMSampleBufferRef)buffer {
    //Wrap all instructions in autoreleasepool
    //This ensures release of objects from background thread
    @autoreleasepool {
        //convert CMSampleBuffer to IplImage
        [converter createIplImageFromCMSampleBuffer:buffer];
        
        //convert to grayscale
        cvCvtColor([converter imgIpl], imgGray, CV_BGRA2GRAY);
        
        //convert to bi-level (i.e. binary)
        cvThreshold(imgGray, imgGray, 128, 255, CV_THRESH_BINARY);
        //cvAdaptiveThreshold(imgGray, imgGray, 255, CV_ADAPTIVE_THRESH_MEAN_C, CV_THRESH_BINARY, 101);
        
        cvCvtColor(imgGray, imgGrayBGRA, CV_GRAY2BGRA);
        [converter createUIImageFromIplImage:imgGrayBGRA];
        
        //Create storage variables for finder pattern search
        int stateCount[5]; //counters for each of five regions in the finder pattern
        int currentState; //holds current state
        NSMutableArray *finderPatterns = [NSMutableArray new]; //array of discovered finder patterns
        NSMutableArray* centroidList = [NSMutableArray new]; //array of (x,y) pairs denoting pattern centers
        
        //Perform pixel-by-pixel nested loop search through image
        for (int row = 0; row < imgGray->height; row++) {
            //Erase storage
            currentState = 0;
            memset(stateCount, 0, sizeof(stateCount));
            
            for(int col = 0; col < imgGray->width; col++) {
                uchar *ptr = (uchar*)(imgGray->imageData + row*imgGray->widthStep + col);
                //If pixel is black
                if (ptr[0] == 0) {
                    //And current state is a white (i.e. odd)
                    if (currentState % 2) {
                        //Then the state should be changed (W->B transition)
                        currentState++;
                    }
                    //Regardless of state, we increase the state count
                    stateCount[currentState]++;
                }
                //Otherwise, pixel is white
                else {
                    //If state is white (i.e. odd)
                    if (currentState % 2) {
                        //Then increase the state count
                        stateCount[currentState]++;
                    }
                    //Otherwise, state is black (i.e. even)
                    else {
                        //If in final state (i.e. the "accept state" of an FSM)
                        if (currentState == 4) {
                            //Check the ratio for the discovered pixels. If the ratio is correct, proceed by searching for the proper location to store the segment
                            if (int finderSize = [FinderPattern checkFinderRatioFor:stateCount]) {
                                //Create line segment
                                Rect2D *end = [[Rect2D alloc] initXTo:row andYTo:col];
                                Rect2D *start = [[Rect2D alloc] initXTo:row andYTo:col - finderSize];
                                LineSegment2D *line = [[LineSegment2D alloc] initStartTo:start andEndTo:end];
                                
                                //Create block object for creating and storing a new pattern
                                void (^createPattern)(LineSegment2D*) = ^(LineSegment2D *line) {
                                    //If not, create new pattern array and store line segment
                                    FinderPattern *pattern = [FinderPattern new];
                                    if ([pattern segments] != nil) {
                                        [[pattern segments] addObject:line];
                                    }
                                    //Clear count of columns since last modification
                                    [pattern setColumnsSinceLastModified:0];
                                    //Initialize patterns array with new pattern
                                    if (finderPatterns != nil) {
                                        [finderPatterns addObject:pattern];
                                    }
                                };
                                
                                //Check to see if any patterns have been recorded
                                if ([finderPatterns count] > 0) {
                                    int counter = 0;
                                    //Enumerate through patterns
                                    for (; counter < [finderPatterns count]; counter++) {
                                        //Load pattern
                                        FinderPattern *pattern = [finderPatterns objectAtIndex:counter];
                                        //Retrieve newest segment (segment found on the last iteration of for loop)
                                        LineSegment2D *mostRecentSegment = [[pattern segments] lastObject];
                                        
                                        //If center of the new segment lies above the most recently found segment
                                        if (([[line getStart] getY] + finderSize/2) <
                                                [[mostRecentSegment getStart] getY]) {
                                            //Create a new pattern and store the new segment in it
                                            createPattern(line);
                                            //And exit the pattern search
                                            break;
                                        }
                                        //If center of new segment lies within previous segment
                                        else if (([[line getStart] getY] + finderSize/2) <
                                                 [[mostRecentSegment getEnd] getY]) {
                                            //Append new segment to current pattern
                                            if ([pattern segments] != nil) {
                                                [[pattern segments] addObject:line];
                                            }
                                            //Clear count of columns since last modification
                                            [pattern setColumnsSinceLastModified:0];
                                            //Quit pattern search
                                            break;
                                        }                                    
                                    }
                                    
                                    //If all patterns have been checked, the new segment must be below patterns
                                    if (counter == [finderPatterns count]) {
                                        //Create a new pattern and store the new segment in it
                                        createPattern(line);
                                    }
                                }
                                //If no patterns have been found
                                else {
                                    //Create a new pattern and store the new segment in it
                                    createPattern(line);
                                }
                            }
                            else {
                                currentState = 3;
                                stateCount[0] = stateCount[2];
                                stateCount[1] = stateCount[3];
                                stateCount[2] = stateCount[4];
                                stateCount[3] = 1;
                                stateCount[4] = 0;
                                continue;
                            }
                            currentState = 0;
                            memset(stateCount, 0, sizeof(stateCount));
                        }
                        //Otherwise, the end of the pattern has not been reached
                        else {
                            // So increment the state (B->W transition)
                            currentState++;
                            //And the state count
                            stateCount[currentState]++;
                        }
                    }
                }
            }
            
            //Scan all discovered finder patterns
            int segmentThreshold = 2;
            int modifiedThreshold = 2;
            
            for (int counter = 0; counter < [finderPatterns count]; counter++) {
                FinderPattern *pattern = nil;
                //Load pattern if available
                if ([finderPatterns count] > counter) {
                    pattern = [finderPatterns objectAtIndex:counter];
                }
                //Otherwise, exit loop
                else {
                    break;
                }
                //If pattern has not been modified after modifiedThreshold columns
                if ([pattern columnsSinceLastModified] > modifiedThreshold) {
                    //Remove pattern from array
                    int index = [finderPatterns indexOfObject:pattern];
                    if ([finderPatterns count] > index) {
                        [finderPatterns removeObjectAtIndex:index];
                    }
                    else {
                        break;
                    }
                    
                    //If the number of segments found for the pattern is above a defined threshold
                    if ([[pattern segments] count] > segmentThreshold) {
                        //Then calculate centroid for pattern and store
                        int xsum = 0;
                        int ysum = 0;
                        for (int i = 0; i < [[pattern segments] count]; i++) {
                            xsum += (([[[[pattern segments] objectAtIndex:i] getEnd] getX] -
                                      [[[[pattern segments] objectAtIndex:i] getStart] getX]) / 2) +
                            [[[[pattern segments] objectAtIndex:i] getStart] getX];
                            ysum += (([[[[pattern segments] objectAtIndex:i] getEnd] getY] -
                                      [[[[pattern segments] objectAtIndex:i] getStart] getY]) / 2) +
                                        [[[[pattern segments] objectAtIndex:i] getStart] getY];
                        }
                        Rect2D *c = [[Rect2D alloc] initXTo:xsum / [[pattern segments] count]
                                                     andYTo:ysum / [[pattern segments] count]];
                        
                        if (centroidList != nil) {
                            [centroidList addObject:c];
                        }
                    }
                }
                //If pattern was not modified in the last iteration of the loop
                else if ([pattern columnsSinceLastModified] >= 0) {
                    //Increment the counter
                    [pattern setColumnsSinceLastModified:([pattern columnsSinceLastModified] + 1)];
                }
                //Otherwise, it was modified in the last iteration, so we leave it alone
            }
        }

        return centroidList;
    }
}

@end