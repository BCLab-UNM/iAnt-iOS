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
const int NEST_THRESHOLD = 252;

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
            [[UIScreen mainScreen] setBrightness:1];
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
            UIImage *imgThreshold = [imgRecog getImgThresholdUI];
            //Check tag image for QR code
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
                [index nextObject]; //drop first layer, start at layer two
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
                CALayer *featureLayer = nil;
                //Load relevant images
                UIImage *square = [UIImage imageNamed:@"squarePNG"];
                UIImage *imgThreshold = [imgRecog getImgThresholdUI];
                
                //If we are searching for tags, and a tag has been found in the image
                if ([sensorState isEqualToString:@"TAG ON"] && [qrDecoder decodeImage:imgThreshold]) {
                    //Transmit stop messages to Arduino (two are required)
                    [cblMgr send:[NSString stringWithFormat:@"(%d,%d)",data[0],data[1]]];
                    [cblMgr send:[NSString stringWithFormat:@"(%d,%d)",data[0],data[1]]];

                    //Hide all layers
                    hideAllLayers();
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
                        [featureLayer setFrame:rect];
                        //Ensure layer is visible
                        [featureLayer setHidden:NO];
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
                        [featureLayer setFrame:rect];
                        
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
                        [cblMgr send:[NSString stringWithFormat:@"(%d,%d)",data[0],data[1]]];
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
                        [cblMgr send:[NSString stringWithFormat:@"(%d,%d)",data[0],data[1]]];
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
                    [cblMgr send:[NSString stringWithFormat:@"(%d,%d)",data[0],data[1]]];
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
        [comm send:[NSString stringWithFormat:@"%d\n",qrCode]];
        
        //Schedule a timer to trigger a buffer check every 100 ms
        timer = [NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(checkBufferForTagMessage:) userInfo:nil repeats:YES];
    }
}

//Called periodically to check the Communications rxBuffer for incoming tag message ("new" or "old") from the ABS
-(void)checkBufferForTagMessage:(id)object {
    //If message has been received from ABS
    if ([sensorState isEqualToString:@"TAG FOUND"] && [[comm rxBuffer] length] > 0) {
        //If message is "new", i.e. QR tag *has not* been found before
        if ([[comm rxBuffer] isEqualToString:@"new"]) {
            //Update display
            [[self infoBox] setText:[NSString stringWithFormat:@"TAG FOUND     %d (NEW)",qrCode]];
            //Alert Arduino to new tag
            [cblMgr send:@"yes"];
            //Transmit tag number
            [cblMgr send:[NSString stringWithFormat:@"%d",qrCode]];
        }
        
        //If message is "old", i.e. QR tag *has* been found before
        if ([[comm rxBuffer] isEqualToString:@"old"]) {
            //Update display
            [[self infoBox] setText:[NSString stringWithFormat:@"TAG FOUND     %d (OLD)",qrCode]];
            //Alert Arduino to old tag
            [cblMgr send:@"no"];
        }
        
        //Remove timer
        [timer invalidate];
        timer = nil;
        
        //Reset buffer
        [comm setRxBuffer:nil];
    }
}


#pragma mark - UIView callbacks

- (void)viewDidLoad {
    [super viewDidLoad];
    
    comm = [[Communication alloc] init];
    relMotion = [[RelativeMotion alloc] init];
    
    //Set up QR code reader
    qrDecoder = [[Decoder alloc] init];
    NSMutableSet *readers = [[NSMutableSet alloc ] init];
    QRCodeReader* qrcodeReader = [[QRCodeReader alloc] init];
    [readers addObject:qrcodeReader];
    [qrDecoder setReaders:readers];
    [qrDecoder setDelegate:self];

    cblMgr = [CableManager cableManager];
    [cblMgr setDelegate:self];
    
    [comm connectTo:@"192.168.33.1" onPort:2223];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"Stream opened" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveNotification:) name:@"Stream closed" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateInfoBox:) name:@"infoBox text" object:nil];
}

- (void)viewDidUnload {
    [self setInfoBox:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {    
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}


#pragma mark - Notification Center

- (void)receiveNotification:(NSNotification *) notification {
    if ([[notification name] isEqualToString:@"Stream opened"]) {
        [[self infoBox] setBackgroundColor:[UIColor clearColor]];
        [[self infoBox] setTextColor:[UIColor blackColor]];
    }
    else if ([[notification name] isEqualToString:@"Stream closed"]) {
        [[self infoBox] setBackgroundColor:[UIColor redColor]];
        [[self infoBox] setTextColor:[UIColor whiteColor]];
    }
}

- (void)updateInfoBox:(NSNotification*) notification {
    dispatch_async (dispatch_get_main_queue(), ^{
        [[self infoBox] setText:[[notification userInfo] objectForKey:@"text"]];
    });
}


#pragma mark - RscMgrDelegate methods

//RscMgr callback, triggered when serial data is available for reading
- (void)readBytesAvailable:(UInt32)numBytes {
    NSString *message = nil;
    
    //Read bytes into buffer
    [cblMgr receive:numBytes];
    
    while ((message = [cblMgr getMessage]) != nil) {
        
        //Check for null characters at beginning of string (artifact of serial communication from Arduino)
        if ([message length] > 0) {
            
            unichar character [1] = {0};
            int nullCount = 0;
            
            [message getCharacters:character range:NSMakeRange(0,1)];
            while (character[0] == 0) {
                nullCount++;
                [message getCharacters:character range:NSMakeRange(nullCount,1)];
            }
            
            //If there are additional characters after the null characters
            if ([message length] > nullCount) {
                //Simply remove the null character
                message = [message substringFromIndex:nullCount];
            }
            //Otherwise
            else {
                //Continue to next loop iteration
                continue;
            }
        }
        
        //Log command
        #ifdef DEBUG
        NSLog(@"%@",message);
        #endif
        
        //Check command against series of options
        if ([message hasPrefix:@"display"]) {
            int wordLength = 7;
            NSString* data = [message substringWithRange:NSMakeRange(wordLength, [message length] - wordLength)];
            [[self infoBox] setText:data];
        }
         
        else if ([message isEqualToString:@"fence"]) {
            int wordLength = 5;
            NSString* radius;
            
            radius = [message substringWithRange:NSMakeRange(wordLength, [message length] - wordLength)];
            
            [absMotion enableRegionMonitoring:@"virtual fence" withRadius:[radius doubleValue]];
        }
        
        else if ([message isEqualToString:@"gyro on"]) {
            if (![sensorState isEqualToString:@"GYRO ON"]) {
                [relMotion start];
                [[self infoBox] setText:@"GYRO ON"];
                sensorState = @"GYRO ON";
            }
            [cblMgr send:@"gyro on"];
        }
        
        else if ([message isEqualToString:@"gyro off"]) {
            if (![sensorState isEqualToString:@"GYRO OFF"]) {
                [relMotion stop];
                [[self infoBox] setText:@"GYRO OFF"];
                sensorState = @"GYRO OFF";
            }
        }
        
        else if ([message isEqualToString:@"heading"]) {
            int wordLength = 7;
            NSString* goalHeading = nil;
            
            goalHeading = [message substringWithRange:NSMakeRange(wordLength, [message length] - wordLength)];
            
            double angle = atan2(cos([absMotion currentHeading]), sin([absMotion currentHeading])) -
                           atan2(cos([goalHeading intValue]),sin([goalHeading intValue]));
            
            if (angle < 0)
                [cblMgr send:@"left"];
            else if (angle > 0)
                [cblMgr send:@"right"];
            else
                [cblMgr send:@"stop"];
        }
        
        else if ([message isEqualToString:@"nest on"]) {
            if (![sensorState isEqualToString:@"NEST ON"]) {
                if (imgRecog != nil) {
                    [self teardownAVCapture];
                    imgRecog = nil;
                }
                imgRecog = [[ImageRecognition alloc] initResolutionTo:FRONT_REZ_VERT by:FRONT_REZ_HOR];
                [self setupAVCaptureAt:AVCaptureDevicePositionFront];
                [[self infoBox] setText:@"NEST ON"];
                sensorState = @"NEST ON";
                nestDistance = -1;
            }
            [cblMgr send:@"nest on"];
        }
        
        else if ([message isEqualToString:@"nest off"]) {
            if (![sensorState isEqualToString:@"NEST OFF"]) {
                [self teardownAVCapture];
                imgRecog = nil;
                [[self infoBox] setText:@"NEST OFF"];
                sensorState = @"NEST OFF";
            }
            [cblMgr send:@"nest off"];
            [cblMgr send:[NSString stringWithFormat:@"%d\n",nestDistance]];
        }

        else if ([message isEqualToString:@"pheromone on"]) {
            //Schedule a timer to trigger a buffer check every 100 ms
            timer = [NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(checkBufferForPheromone:) userInfo:nil repeats:YES];
            [[self infoBox] setText:@"PHEROMONE ON"];
            sensorState = @"PHEROMONE ON";
        }
        
        else if ([message isEqualToString:@"pheromone off"]) {
            //If pheromone timer has not already been removed by the selector method
            if (timer != nil) {
                //Remove timer
                [timer invalidate];
                timer = nil;
            }
            [[self infoBox] setText:@"PHEROMONE OFF"];
            sensorState = @"PHEROMONE OFF";
        }
        
        else if ([message hasPrefix:@"print"]) {
            int wordLength = 5;
            NSString* data = [message substringWithRange:NSMakeRange(wordLength, [message length] - wordLength)];
            message = [NSString stringWithFormat:@"%@,%@\n",[comm getMacAddress],data];
            [comm send:message];
        }
        
        else if ([message isEqualToString:@"seed"]) {
            [cblMgr send:@"seed"];
            int seed = arc4random();
            [cblMgr send:[[NSNumber numberWithInt:seed] stringValue]];
        }
        
        else if ([message isEqualToString:@"tag on"]) {
            if (![sensorState isEqualToString:@"TAG ON"] && ![sensorState isEqualToString:@"TAG FOUND"]) {
                if (imgRecog != nil) {
                    [self teardownAVCapture];
                    imgRecog = nil;
                }
                imgRecog = [[ImageRecognition alloc] initResolutionTo:BACK_REZ_VERT by:BACK_REZ_HOR];
                [self setupAVCaptureAt:AVCaptureDevicePositionBack];
            }
            [[self infoBox] setText:@"TAG ON"];
            sensorState = @"TAG ON";
            [cblMgr send:@"tag on"];
            qrCode = -1;
            
            //If tag message timer has not already been removed by the selector method
            if (timer != nil) {
                //Remove timer
                [timer invalidate];
                timer = nil;
            }
        }
        
        else if ([message isEqualToString:@"tag off"]) {
            if (![sensorState isEqualToString:@"TAG OFF"]) {
                [self teardownAVCapture];
                imgRecog = nil;
                [[self infoBox] setText:@"TAG OFF"];
                sensorState = @"TAG OFF";
            }
        }
        
        else if ([message isEqualToString:@"tag found"]) {
            //Update display
            [[self infoBox] setText:@"TAG FOUND"];
            sensorState = @"TAG FOUND";
            //Reply with current tag number
            [cblMgr send:@"tag found"];
        }
        
        else {
            NSLog(@"Error - The command \"%@\" is not recognized",message);
        }
    }
}

//Called periodically to check the Communications rxBuffer for incoming virtual pheromone location from the ABS
- (void)checkBufferForPheromone:(id)object {
    //If message has been received by ABS
    if ([[comm rxBuffer] length] > 0) {
        //Transmit pheromone location to Arduino
        [cblMgr send:@"pheromone"];
        [cblMgr send:[comm rxBuffer]];
      
        //Remove timer
        [timer invalidate];
        timer = nil;
        
        //Reset buffer
        [comm setRxBuffer:nil];
    }
}

- (void)cableConnected:(NSString *)protocol {
    [cblMgr setBaud:9600];
	[cblMgr open];
}

- (void)cableDisconnected {
    exit(0);
}

- (void)portStatusChanged {}

@end
