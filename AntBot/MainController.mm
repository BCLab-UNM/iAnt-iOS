//
//  MainController.mm
//  AntBot
//
//  Created by Joshua Hecker on 12/23/11.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "MainController.h"

#pragma MainController extension

@interface MainController ()

//AVCaptureSession functions
- (void)setupAVCaptureAt:(AVCaptureDevicePosition)position;
- (void)teardownAVCapture;

//QR reader function
- (void)setupQRReader;
- (void)teardownQRReader;

@end

@implementation MainController

@synthesize skScanner;

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
}

//AVCapture callback, triggered when a new frame (i.e. image) arrives from video stream
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    //Wrap all instructions in autoreleasepool
    //This ensures release of objects from background thread
    @autoreleasepool {
        //Create storage variables
        unichar data[2] = {0};
        int numberOfCentroids;
        NSMutableArray *centroidList = [[NSMutableArray alloc] init];
        
        //If searching for tags
        if ([sensorState isEqualToString:@"TAG ON"]) {
            //Retrieve list of finder pattern centroids
            centroidList = [imgRecog locateQRFinderPatternsIn:sampleBuffer];
        }
        //If searching for nest
        else if ([sensorState isEqualToString:@"NEST ON"]) {
            //Retrieve nest centroid
            centroidList = [imgRecog findColorCentroidIn:sampleBuffer usingThreshold:HSV_THRESHOLD_RED];
        }
        
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
        
        //If centroids were found
        if ((numberOfCentroids = [centroidList count])) {
            CALayer *featureLayer = nil;
            //Load relevant images
            UIImage *square = [UIImage imageNamed:@"squarePNG"];
            UIImage *imgThreshold = [imgRecog getImgThresholdUI];
            
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
                    //Rotate layer by 90 degrees clockwise and vertically flip it
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
            Point2D *center = nil;
            Point2D *meanCenter = [[Point2D alloc] init];
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
                meanCenter = [[Point2D alloc] initXTo:([meanCenter getX] + [center getX])
                                               andYTo:([meanCenter getY] + [center getY])];
                
                CGRect rect;
                //If using front camera to search for nest
                if ([sensorState isEqualToString:@"NEST ON"]) {
                    //Create frame for square image
                    rect = CGRectMake([center getY]*([previewView frame].size.width/FRONT_REZ_HOR)-20,
                                      [center getX]*([previewView frame].size.height/FRONT_REZ_VERT)-20,
                                             40,40);
                }
                //If using back camera to search for tags
                if ([sensorState isEqualToString:@"TAG ON"]) {
                    //Create frame for square image
                    rect = CGRectMake((BACK_REZ_HOR-[center getX])*([previewView frame].size.width/BACK_REZ_HOR)-20,
                                      [center getY]*([previewView frame].size.height/BACK_REZ_VERT)-20,
                                      40,40);
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
                    rect = CGRectMake([center getY]*([previewView frame].size.width/FRONT_REZ_HOR)-20,
                                      [center getX]*([previewView frame].size.height/FRONT_REZ_VERT)-20,
                                      40,40);
                }
                //If using back camera to search for tags
                if ([sensorState isEqualToString:@"TAG ON"]) {
                    //Create frame for square image
                    rect = CGRectMake((BACK_REZ_HOR-[center getX])*([previewView frame].size.width/BACK_REZ_HOR)-20,
                                      [center getY]*([previewView frame].size.height/BACK_REZ_VERT)-20,
                                      40,40);
                }
                [featureLayer setFrame:rect];
                
                //Add new thresholded image to frame, replacing the previous found
                [featureLayer setContents:(id)[square CGImage]];
                
                //Update summation
                meanCenter = [[Point2D alloc] initXTo:([meanCenter getX] + [center getX])
                                               andYTo:([meanCenter getY] + [center getY])];
            }
            
            //Calulate mean centroid
            meanCenter = [[Point2D alloc] initXTo:([meanCenter getX]/numberOfCentroids)
                                           andYTo:([meanCenter getY]/numberOfCentroids)];
            
            //Compute number of pixels between true center and centroid
            int horizontalPixelDifference;
            
            if ([sensorState isEqualToString:@"NEST ON"]) {
                horizontalPixelDifference = FRONT_REZ_HOR/2 - [meanCenter getY];
                data[1] = MIN(3*abs(horizontalPixelDifference),127);
                
                if (horizontalPixelDifference > 5) {
                    data[0] = 'l';
                }
                else if (horizontalPixelDifference < -5) {
                    data[0] = 'r';
                }
                else {
                    data[0] = 's';
                    data[1] = 0;
                }
            }
            if ([sensorState isEqualToString:@"TAG ON"]) {
                horizontalPixelDifference = BACK_REZ_HOR/2 - [meanCenter getX];
                data[1] = MIN(3*abs(horizontalPixelDifference),127);
                
                if (horizontalPixelDifference > 5) {
                    data[0] = 'r';
                }
                else if (horizontalPixelDifference < -5) {
                    data[0] = 'l';
                }
                else {
                    int verticalPixelDifference = BACK_REZ_VERT/2 - [meanCenter getY];
                    data[1] = MIN(0.5*abs(verticalPixelDifference),127);
                    
                    if (verticalPixelDifference > 5) {
                        data[0] = 'f';
                    }
                    else if (verticalPixelDifference < -5) {
                        data[0] = 'b';
                    }
                    else {
                        data[0] = 's';
                        data[1] = 0;
                    }
                }
            }

            [cblMgr send:[NSString stringWithCharacters:data length:2]];
        }
        
        //If no centroids were found
        else {
            NSEnumerator *index = [[previewLayer sublayers] objectEnumerator];
            CALayer *featureLayer = nil;
            [index nextObject]; //drop first layer, start at layer two
            //Enumerate through sublayers
            while (featureLayer = [index nextObject]) {
                //Hide layer
                [featureLayer setHidden:YES];
            }
            
            //If searching for nest
            if ([sensorState isEqualToString:@"NEST ON"]) {
                //Construct and transmit maintenance message to continue search
                data[0] = 'l';
                data[1] = 0;
                [cblMgr send:[NSString stringWithCharacters:data length:2]];
            }
        }

        [CATransaction commit];
    }
}

#pragma mark - ScannerKit methods

//Setup QR
- (void)setupQRReader {
    if ([self presentedViewController] != skScanner) {       
        skScanner.delegate = self;
        skScanner.shouldLookForEAN13AndUPCACodes = NO;
        skScanner.shouldLookForEAN8Codes = NO;
        skScanner.shouldLookForUPCECodes = NO;
        skScanner.shouldLookForQRCodes = YES;
        [self presentViewController:(UIViewController *)skScanner animated:NO completion:NULL];
    }
}

//Clean up QR
- (void)teardownQRReader {
    [self dismissViewControllerAnimated:NO completion:NULL];
}

//ScannerKit callback, triggered when QR code is read
- (void)scannerViewController:(SKScannerViewController *)scanner didRecognizeCode:(SKCode *)qrCode {
    //Create copy of qrCode
    code = qrCode;
    
    //Transmit QR code to ABS
    [comm send:qrCode.rawContent];
    
    //Schedule a timer to trigger a buffer check every 100 ms
    timer = [NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(checkBufferForTagMessage:) userInfo:nil repeats:YES];
}

//Called periodically to check the Communications rxBuffer for incoming tag message ("new" or "old") from the ABS
-(void)checkBufferForTagMessage:(id)object {
    //If message has been received from ABS
    if ([[comm rxBuffer] length] > 0) {
        //If message is "new", i.e. QR tag had not been found before
        if ([[comm rxBuffer] isEqualToString:@"new"]) {
            //Alert Arduino to new tag
            [cblMgr send:@"yes"];
            [cblMgr send:code.rawContent];
        }
        
        //Remove timer
        [timer invalidate];
        timer = nil;
        
        //Reset buffer
        [comm setRxBuffer:nil];
    }
}

//ScannerKit callback, triggered when scanner generates an error
- (void) scannerViewController:(SKScannerViewController *)scanner didStopLookingForCodesWithError:(NSError *)error{
    [self teardownQRReader];
    [self setupQRReader];   
}

//Disable default UI for ScannerKit
- (BOOL) scannerViewControllerShouldShowDefaultUserInterface:(SKScannerViewController *)scanner {
    return NO;
}

#pragma mark - UIView callbacks

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //absMotion = [[AbsoluteMotion alloc] init];
    //ambLight = [[AmbientLight alloc] init];
    comm = [[Communication alloc] init];
    relMotion = [[RelativeMotion alloc] init];
    skScanner = [[SKScannerViewController alloc] init];

    cblMgr = [CableManager cableManager];
    [cblMgr setDelegate:self];
    
    [comm connectTo:@"192.168.33.1" onPort:2223];
}

- (void)viewDidUnload {
    infoBox = nil;
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    //[ambLight start];
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
        NSLog(@"%@",message);
        
        if ([message isEqualToString:@"fence"]) {
            int wordLength = 5;
            NSString* radius;
            
            radius = [message substringWithRange:NSMakeRange(wordLength, [message length] - wordLength)];
            
            [absMotion enableRegionMonitoring:@"virtual fence" withRadius:[radius doubleValue]];
        }
        
        else if ([message isEqualToString:@"gyro on"]) {
            if (![sensorState isEqualToString:@"GYRO ON"]) {
                [relMotion start];
                [infoBox setText:@"GYRO ON"];
                sensorState = @"GYRO ON";
            }
            [cblMgr send:@"gyro on"];
        }
        
        else if ([message isEqualToString:@"gyro off"]) {
            if (![sensorState isEqualToString:@"GYRO OFF"]) {
                [relMotion stop];
                [infoBox setText:@"GYRO OFF"];
                sensorState = @"GYRO OFF";
            }
        }
        
        else if ([message isEqualToString:@"heading"]) {
            int wordLength = 7;
            NSString* goalHeading;
            
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
                imgRecog = [[ImageRecognition alloc] initResolutionTo:FRONT_REZ_VERT by:FRONT_REZ_HOR];
                [self setupAVCaptureAt:AVCaptureDevicePositionFront];
                [infoBox setText:@"NEST ON"];
                sensorState = @"NEST ON";
            }
            [cblMgr send:@"nest on"];
        }
        
        else if ([message isEqualToString:@"nest off"]) {
            if (![sensorState isEqualToString:@"NEST OFF"]) {
                [self teardownAVCapture];
                [infoBox setText:@"NEST OFF"];
                sensorState = @"NEST OFF";
            }
        }
        
        else if ([message isEqualToString:@"pheromone on"]) {
            //Schedule a timer to trigger a buffer check every 100 ms
            timer = [NSTimer scheduledTimerWithTimeInterval:0.1f
                                                     target:self
                                                   selector:@selector(checkBufferForPheromone:)
                                                   userInfo:nil
                                                    repeats:YES];
        }
        
        else if ([message isEqualToString:@"pheromone off"]) {
            //If timer has not already been removed by the selector method
            if (timer != nil) {
                //Remove timer
                [timer invalidate];
                timer = nil;
            }
        }
        
        else if ([message hasPrefix:@"print"]) {
            int wordLength = 5;
            NSString* data = [message substringWithRange:NSMakeRange(wordLength, [message length] - wordLength)];
            message = [NSString stringWithFormat:@"%@,%@",[comm getMacAddress],data];
            [comm send:message];
        }
        
        else if ([message isEqualToString:@"read on"]) {
            if (![sensorState isEqualToString:@"READ ON"]) {
                [self setupQRReader];
                sensorState = @"READ ON";
            }
            [cblMgr send:@"read on"];
        }
        
        else if ([message isEqualToString:@"read off"]) {
            if (![sensorState isEqualToString:@"READ OFF"]) {
                [self teardownQRReader];
                sensorState = @"READ OFF";
            }
        }
        
        else if ([message isEqualToString:@"seed"]) {
            [cblMgr send:@"seed"];
            int seed = arc4random();
            [cblMgr send:[[NSNumber numberWithInt:seed] stringValue]];
        }
        
        else if ([message isEqualToString:@"tag on"]) {
            if (![sensorState isEqualToString:@"TAG ON"]) {
                imgRecog = [[ImageRecognition alloc] initResolutionTo:BACK_REZ_VERT by:BACK_REZ_HOR];
                [self setupAVCaptureAt:AVCaptureDevicePositionBack];
                [infoBox setText:@"TAG ON"];
                sensorState = @"TAG ON";
            }
            [cblMgr send:@"tag on"];
        }
        
        else if ([message isEqualToString:@"tag off"]) {
            if (![sensorState isEqualToString:@"TAG OFF"]) {
                [self teardownAVCapture];
                [infoBox setText:@"TAG OFF"];
                sensorState = @"TAG OFF";
            }
        }
        else {
            //NSLog(@"Error - The command \"%@\" is not recognized",message);
            for (int i=0; i<[message length]; i++) {
                unichar character [1];
                [message getCharacters:character range:NSMakeRange(i,1)];
                NSLog(@"%d",character[0]);
            }
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
