//
//  MainController.mm
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "MainController.h"

//Constants
const int BACK_REZ_VERT = 352;
const int BACK_REZ_HOR = 288;
const int FRONT_REZ_VERT = 192;
const int FRONT_REZ_HOR = 144;
const int NEST_THRESHOLD = 240;

#pragma MainController extension

@interface MainController ()

//AVCaptureSession functions
- (void)setupAVCaptureAt:(AVCaptureDevicePosition)position;
- (void)teardownAVCapture;

@end

@implementation MainController

@synthesize infoBox;

#pragma mark - AVCapture methods

//Setup capture
- (void)setupAVCaptureAt:(AVCaptureDevicePosition)position {
	NSError *error = nil;
	
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
	CALayer *rootLayer = [previewView layer];
	[rootLayer setMasksToBounds:YES];
	[previewLayer setFrame:[rootLayer bounds]];
	[rootLayer addSublayer:previewLayer];
	[session startRunning];
    
bail:
	if (error) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Failed with error %d", (int)[error code]]
															message:[error localizedDescription]
														   delegate:nil 
												  cancelButtonTitle:@"Dismiss" 
												  otherButtonTitles:nil];
		[alertView show];
		[self teardownAVCapture];
	}
}

//Clean up capture setup
- (void)teardownAVCapture {
    [session stopRunning];
	if (videoDataOutputQueue)
		dispatch_release(videoDataOutputQueue);
	[previewLayer removeFromSuperlayer];
    [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:NO];
    [[self infoBox] setText:nil];
}

//AVCapture callback, triggered when a new frame (i.e. image) arrives from video stream
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    //Wrap all instructions in autoreleasepool
    //This ensures release of objects from background thread
    @autoreleasepool {
        //If tag has been found, we are searching for neighbors
        if ([sensorState isEqualToString:@"TAG FOUND"]) {
            //Filter image
            [imgRecog locateQRFinderPatternsIn:sampleBuffer];
            
            //Load relevant images
            UIImage *img = [Conversions createUIImageFromCMSampleBuffer:sampleBuffer]; //original
            UIImage *img22 = [Conversions rotateUIImage:img customRadians:(M_PI_4/2.f)]; //rotated 22.5 degrees
            UIImage *img45 = [Conversions rotateUIImage:img customRadians:M_PI_4]; //rotated 45 degrees
            UIImage *img67 = [Conversions rotateUIImage:img customRadians:(M_PI_4 + M_PI_4/2.f)]; //rotated 67.5 degrees
            UIImage *imgThreshold = [imgRecog getImgThresholdUI]; //thresholded
            
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
            if ([sensorState isEqualToString:@"NEST ON"]) {
                //Retrieve nest centroid
                centroidList = [imgRecog findColorCentroidIn:sampleBuffer usingThreshold:NEST_THRESHOLD];
            }
            //If searching for tags
            else if ([sensorState isEqualToString:@"TAG ON"]) {
                //Retrieve list of finder pattern centroids
                centroidList = [imgRecog locateQRFinderPatternsIn:sampleBuffer];
            }
            
            [CATransaction begin];
            [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
            
            //If centroids were found
            if ((numberOfCentroids = [centroidList count])) {
                //Ensure mocapHeading observer has been removed
                @try {
                    [server removeObserver:self forKeyPath:@"mocapHeading"];
                }
                @catch (NSException *exception) {
                    //do nothing, observer was already removed
                }
                
                CALayer *featureLayer = nil;
                //Load relevant images
                UIImage *square = [UIImage imageNamed:@"squarePNG"];
                UIImage *img = [Conversions createUIImageFromCMSampleBuffer:sampleBuffer]; //original
                UIImage *img22 = [Conversions rotateUIImage:img customRadians:(M_PI_4/2.f)]; //rotated 22.5 degrees
                UIImage *img45 = [Conversions rotateUIImage:img customRadians:M_PI_4]; //rotated 45 degrees
                UIImage *img67 = [Conversions rotateUIImage:img customRadians:(M_PI_4 + M_PI_4/2.f)]; //rotated 67.5 degrees
                UIImage *imgThreshold = [imgRecog getImgThresholdUI]; //thresholded
                
                //If we are searching for tags, and a tag has been found in the image
                //Note that we exploit lazy evaluation here to avoid detecting the same QR tag multiple times
                if ([sensorState isEqualToString:@"TAG ON"] && ([qrDecoder decodeImage:img] ||
                                                                [qrDecoder decodeImage:img22] ||
                                                                [qrDecoder decodeImage:img45] ||
                                                                [qrDecoder decodeImage:img67] ||
                                                                [qrDecoder decodeImage:imgThreshold])) {
                    //Transmit stop messages to Arduino (two are required)
                    [cable send:[NSString stringWithFormat:@"(%d,%d)", data[0], data[1]]];
                    [cable send:[NSString stringWithFormat:@"(%d,%d)", data[0], data[1]]];

                    //Hide all layers
                    hideAllLayers();
                    
                    sensorState = @"TAG FOUND";
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
                        if ([sensorState isEqualToString:@"NEST ON"]) {
                            //Rotate layer by 90 degrees clockwise, then rotate it 180 degrees around the y-axis
                            [featureLayer setTransform:CATransform3DScale(CATransform3DMakeRotation(M_PI_2, 0, 0, 1),
                                                                          1, -1, 1)];
                        }
                        //If using back camera to search for tags
                        else if ([sensorState isEqualToString:@"TAG ON"]) {
                            //Rotate layer by 90 degrees clockwise
                            [featureLayer setTransform:CATransform3DScale(CATransform3DMakeRotation(M_PI_2, 0, 0, 1),
                                                                          1, 1, 1)];
                        }
                        //Set the layer frame size
                        CGRect rect = CGRectMake(0, 0,[previewView frame].size.width, [previewView frame].size.height);
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
                        if ([sensorState isEqualToString:@"NEST ON"]) {
                            //Create frame for square image
                            rect = CGRectMake(([center getX] - [center getHeight]/2) * ([previewView frame].size.width/FRONT_REZ_HOR),
                                              ([center getY] - [center getWidth]/2) * ([previewView frame].size.height/FRONT_REZ_VERT),
                                              [center getHeight]*([previewView frame].size.width/FRONT_REZ_HOR),
                                              [center getWidth]*([previewView frame].size.height/FRONT_REZ_VERT));
                        }
                        //If using back camera to search for tags
                        if ([sensorState isEqualToString:@"TAG ON"]) {
                            //Create frame for square image
                            rect = CGRectMake((BACK_REZ_HOR - [center getX] - [center getHeight]/2) * ([previewView frame].size.width/BACK_REZ_HOR),
                                              ([center getY] - [center getWidth]/2) * ([previewView frame].size.height/BACK_REZ_VERT),
                                              [center getHeight]*([previewView frame].size.width/BACK_REZ_HOR),
                                              [center getWidth]*([previewView frame].size.height/BACK_REZ_VERT));
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
                        if ([sensorState isEqualToString:@"NEST ON"]) {
                            //Create frame for square image
                            rect = CGRectMake(([center getX] - [center getHeight]/2) * ([previewView frame].size.width/FRONT_REZ_HOR),
                                              ([center getY] - [center getWidth]/2) * ([previewView frame].size.height/FRONT_REZ_VERT),
                                              [center getHeight]*([previewView frame].size.width/FRONT_REZ_HOR),
                                              [center getWidth]*([previewView frame].size.height/FRONT_REZ_VERT));
                        }
                        //If using back camera to search for tags
                        if ([sensorState isEqualToString:@"TAG ON"]) {
                            //Create frame for square image
                            rect = CGRectMake((BACK_REZ_HOR - [center getX] - [center getHeight]/2) * ([previewView frame].size.width/BACK_REZ_HOR),
                                              ([center getY] - [center getWidth]/2) * ([previewView frame].size.height/BACK_REZ_VERT),
                                              [center getHeight]*([previewView frame].size.width/BACK_REZ_HOR),
                                              [center getWidth]*([previewView frame].size.height/BACK_REZ_VERT));
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
                    
                    if ([sensorState isEqualToString:@"NEST ON"]) {
                        //Number of pixels between observed and true center
                        data[0] = FRONT_REZ_HOR/2 - [meanCenter getX];
                        
                        //Update estimate of distance from nest
                        nestDistance = 1481 * pow([meanCenter getArea],-0.5127) - 50;
                        
                        //Update display
                        short int *temp = data; //pointer to data array (because we can't directly refer to C arrays within blocks, see below)
                        dispatch_async (dispatch_get_main_queue(), ^{
                            [[self infoBox] setText:[NSString stringWithFormat:@"NEST   (%d,%d)",temp[0],temp[1]]];
                        });
                        
                        //Transmit data
                        [cable send:[NSString stringWithFormat:@"(%d,%d)", data[0], data[1]]];
                    }
                    else if ([sensorState isEqualToString:@"TAG ON"]) {
                        //Number of pixels between observed and true center
                        data[0] = -(BACK_REZ_HOR/2 - [meanCenter getX]);
                        data[1] = BACK_REZ_VERT/2 - [meanCenter getY];
                        
                        //Update display
                        short int *temp = data; //pointer to data array (because we can't directly refer to C arrays within blocks, see below)
                        dispatch_async (dispatch_get_main_queue(), ^{
                            [[self infoBox] setText:[NSString stringWithFormat:@"TAG     (%d,%d)",temp[0],temp[1]]];
                        });
                        
                        //Transmit data
                        [cable send:[NSString stringWithFormat:@"(%d,%d)", data[0], data[1]]];
                    }
                }
            }
            
            //If no centroids were found
            else {
                hideAllLayers();
                
                //If searching for nest
                if ([sensorState isEqualToString:@"NEST ON"]) {
                    //Construct maintenance message
                    data[0] = SHRT_MAX;
                    
                    //Update display
                    short int *temp = data; //pointer to data array (because we can't directly refer to C arrays within blocks, see below)
                    dispatch_async (dispatch_get_main_queue(), ^{
                        [[self infoBox] setText:[NSString stringWithFormat:@"NEST     (%d,%d)",temp[0],temp[1]]];
                    });
                    
                    //Transmit data
                    [cable send:[NSString stringWithFormat:@"(%d,%d)", data[0], data[1]]];
                }
            }

            [CATransaction commit];
        }
    }
}


#pragma mark - Decoder methods

- (void)decoder:(Decoder *)decoder didDecodeImage:(UIImage *)image usingSubset:(UIImage *)subset withResult:(TwoDDecoderResult *)result {
    //If new code is different from previously found code
    if ([[result text] intValue] != qrCode) {
        //Create copy of code
        qrCode = [[result text] intValue];
        
        //Transmit QR code to ABS
        [server send:[NSString stringWithFormat:@"%@,%d\n", [Utilities getMacAddress], qrCode]];
    }
}

#pragma mark - UIView callbacks

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // QR code reader
    qrDecoder = [[Decoder alloc] init];
    NSMutableSet *readers = [[NSMutableSet alloc] init];
    QRCodeReader* qrcodeReader = [[QRCodeReader alloc] init];
    [readers addObject:qrcodeReader];
    [qrDecoder setReaders:readers];
    [qrDecoder setDelegate:self];
    
    // Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"Stream opened" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"Stream closed" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateInfoBox:) name:@"infoBox text" object:nil];
    
    // Server connection
    server = [[RouterServer alloc] init];
    [server connectTo:@"192.168.1.10" onPort:2223];
    [server send:[NSString stringWithFormat:@"%@\n", [Utilities getMacAddress]]];
    [self initServerHandlers];
    
    // Serial cable connection
    cable = [[RouterCable alloc] init];
    [self initCableHandlers];
    
    // RelativeMotion
    relMotion = [[RelativeMotion alloc] init];
    [relMotion setCable:cable];
    
    // AbsoluteMotion
    absMotion = [[AbsoluteMotion alloc] init];
    [absMotion setCable:cable];
    
    // Mocap variables.
    mocapMonitor = false;
    mocapHeading = 0;
    mocapContext = 0;
}

- (void)viewDidUnload {
    [self setInfoBox:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (void)initServerHandlers {
    
    // Mocap Heading
    [server handle:@"heading" callback:^(NSArray* data) {
        mocapHeading = [data objectAtIndex:0];
        
        //Create storage variables
        short int cmd[2] = {0, 0};
        cmd[0] = 2 * (int)[Utilities angleFrom:(int)mocapContext to:[mocapHeading intValue]];
        
        //Transmit data to Arduino
        [cable send:[NSString stringWithFormat:@"(%d,%d)", cmd[0], cmd[1]]];
        
        //If angle is small enough, we transmit an additional command to Arduino to stop alignment
        if (abs(cmd[0]) < 2) {
            [cable send:[NSString stringWithFormat:@"(%d,%d)", cmd[0], cmd[1]]];
            mocapMonitor = false;
        }
    }];
    
    // Tag Status
    [server handle:@"tag" callback:^(NSArray* data) {
        NSString* tagStatus = [data objectAtIndex:0];
        
        [[self infoBox] setText:[NSString stringWithFormat:@"%@ TAG FOUND     %d", [tagStatus uppercaseString], qrCode]];
        
        if(mocapMonitor) {
            // If we receive tag information while the mocapHeading is being monitored,
            // then we need to remove the mocapHeading observer and send a stop message to the Arduino
            mocapMonitor = false;
            short int cmd[2] = {0, 0};
            [cable send:[NSString stringWithFormat:@"(%d,%d)", cmd[0], cmd[1]]];
            [cable send:[NSString stringWithFormat:@"(%d,%d)", cmd[0], cmd[1]]];
        }
        
        [cable send:tagStatus];
        if ([tagStatus isEqualToString:@"new"]) {
            [cable send:[NSString stringWithFormat:@"%d\n", qrCode]];
        }
    }];
    
    // Pheromone Location
    [server handle:@"pheromone" callback:^(NSArray* data) {
        NSString* pheromone = [data objectAtIndex:0];
        [cable send:@"pheromone"];
        [cable send:[NSString stringWithFormat:@"%@\n", pheromone]];
    }];
}

- (void)initCableHandlers {
    
    // Align
    [cable handle:@"align" callback:^(NSArray* data) {
        int heading = [[data objectAtIndex:0] intValue];
        mocapContext = heading;
        mocapMonitor = true;
        [cable send:@"align"];
    }];
    
    // Display
    [cable handle:@"display" callback:^(NSArray* data) {
        [[self infoBox] setText:[data objectAtIndex:0]];
    }];
    
    // Fence
    [cable handle:@"fence" callback:^(NSArray* data) {
        double radius = [[data objectAtIndex:0] doubleValue];
        [absMotion enableRegionMonitoring:@"virtual fence" withRadius:radius];
    }];
    
    // Gyro on
    [cable handle:@"gyro on" callback:^(NSArray* data) {
        NSString* label = @"GYRO ON";
        if(![sensorState isEqualToString:label]) {
            [relMotion start];
            [infoBox setText:label];
            sensorState = label;
        }
        [cable send:@"gyro on"];
    }];
    
    // Gyro off
    [cable handle:@"gyro off" callback:^(NSArray* data) {
        NSString* label = @"GYRO OFF";
        if(![sensorState isEqualToString:label]) {
            [relMotion stop];
            [infoBox setText:label];
            sensorState = @"GYRO OFF";
        }
    }];
    
    // Heading
    [cable handle:@"heading" callback:^(NSArray* data) {
        [cable send:mocapHeading];
    }];
    
    // Nest on
    [cable handle:@"nest on" callback:^(NSArray* data) {
        NSString* label = @"NEST ON";
        if(![sensorState isEqualToString:label]) {
            if(imgRecog) {
                [self teardownAVCapture];
                imgRecog = nil;
            }
            imgRecog = [[ImageRecognition alloc] initResolutionTo:FRONT_REZ_VERT by:FRONT_REZ_HOR];
            [self setupAVCaptureAt:AVCaptureDevicePositionFront];
            [infoBox setText:label];
            sensorState = label;
            nestDistance = -1;
        }
        [cable send:@"nest on"];
    }];
    
    // Nest off
    [cable handle:@"nest off" callback:^(NSArray* data) {
        NSString* label = @"NEST OFF";
        if(![sensorState isEqualToString:label]) {
            [self teardownAVCapture];
            imgRecog = nil;
            [infoBox setText:label];
            sensorState = label;
        }
        [cable send:@"nest off"];
        [cable send:[NSString stringWithFormat:@"%d\n", nestDistance]];
    }];
    
    // Parameters
    [cable handle:@"parameters" callback:^(NSArray* data) {
        if(evolvedParameters) {
            [cable send:@"parameters"];
            [cable send:evolvedParameters];
        }
    }];
    
    // Print
    [cable handle:@"print" callback:^(NSArray* data){
        NSString* message = [data objectAtIndex:0];
        [server send:[NSString stringWithFormat:@"%@,%@\n", [Utilities getMacAddress], message]];
    }];
    
    // Seed
    [cable handle:@"seed" callback:^(NSArray* data) {
        [cable send:@"seed"];
        [cable send:[NSString stringWithFormat:@"%d", arc4random()]];
    }];
    
    // Tag on
    [cable handle:@"tag on" callback:^(NSArray* data) {
        NSString* label = @"TAG ON";
        if(![sensorState isEqualToString:label] && ![sensorState isEqualToString:@"TAG FOUND"]) {
            if(!imgRecog) {
                [self teardownAVCapture];
                imgRecog = nil;
            }
            
            imgRecog = [[ImageRecognition alloc] initResolutionTo:BACK_REZ_VERT by:BACK_REZ_HOR];
            [self setupAVCaptureAt:AVCaptureDevicePositionBack];
        }
        [infoBox setText:label];
        sensorState = label;
        [cable send:@"tag on"];
        qrCode = -1;
    }];
    
    // Tag off
    [cable handle:@"tag off" callback:^(NSArray* data) {
        NSString* label = @"TAG OFF";
        if(![sensorState isEqualToString:label]) {
            [self teardownAVCapture];
            imgRecog = nil;
            [infoBox setText:label];
            sensorState = label;
        }
    }];
}


#pragma mark - Notification Center

- (void)receiveNotification:(NSNotification *) notification {
    if ([[notification name] isEqualToString:@"Stream opened"]) {
        [infoBox setBackgroundColor:[UIColor clearColor]];
        [infoBox setTextColor:[UIColor blackColor]];
    }
    else if ([[notification name] isEqualToString:@"Stream closed"]) {
        [infoBox setBackgroundColor:[UIColor redColor]];
        [infoBox setTextColor:[UIColor whiteColor]];
    }
}

- (void)updateInfoBox:(NSNotification*) notification {
    dispatch_async (dispatch_get_main_queue(), ^{
        [infoBox setText:[[notification userInfo] objectForKey:@"text"]];
    });
}

@end
