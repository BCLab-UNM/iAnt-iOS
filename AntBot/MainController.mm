//
//  Controller.m
//  AntBot
//
//  Created by Joshua Hecker on 12/23/11.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "MainController.h"

#pragma MainController extension

@interface MainController ()

//AVCaptureSession functions
- (void)setupAVCapture;
- (void)teardownAVCapture;

//QR reader function
- (void)setupQRReader;
- (void)teardownQRReader;

@end

@implementation MainController

@synthesize skScanner;

#pragma mark - AVCapture methods

//Setup capture
- (void)setupAVCapture {
	NSError *error = nil;
	
	AVCaptureSession *session = [AVCaptureSession new];
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
	    [session setSessionPreset:AVCaptureSessionPreset640x480];
    }
	else {
	    [session setSessionPreset:AVCaptureSessionPresetPhoto];
    }
	
    // Select a video device, make an input
    AVCaptureDeviceInput *deviceInput;
    for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
		if ([d position] == AVCaptureDevicePositionBack) {
            deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:(AVCaptureDevice*)d error:nil];
        }
    }
	
	if ([session canAddInput:deviceInput]) {
		[session addInput:deviceInput];
    }
	
    // Make a video data output
	videoDataOutput = [AVCaptureVideoDataOutput new];
	
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
	if (videoDataOutputQueue)
		dispatch_release(videoDataOutputQueue);
	[previewLayer removeFromSuperlayer];
    [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:NO];
}

//AVCapture callback, triggered when a new frame arrives from video stream
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    int pixelDifference;
    unichar data [2];
    UIImage *img = [UIImage imageNamed:@"IMG_0233.jpg"];
    BOOL flag = [imgRecog locateQRFinderPatternIn:img];
    Cartesian2D center;// = [imgRecog findColorCentroidIn:sampleBuffer usingThreshold:HSV_THRESHOLD_RED];
    
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    
    //if (!std::isnan(center.x)) {
        CALayer *featureLayer = nil;
        UIImage *square = [UIImage imageNamed:@"squarePNG"];
        UIImage *imgThreshold = [imgRecog imgThresholdUI];
    
        
        if ([[previewLayer sublayers] count] > 1) {
            featureLayer = [[previewLayer sublayers] objectAtIndex:1];
            [featureLayer setContents:(id)[imgThreshold CGImage]];
            
            featureLayer = [[previewLayer sublayers] objectAtIndex:2];
            CGRect rect = CGRectMake((VIDEO_REZ_HOR-center.y)*([previewView frame].size.width/VIDEO_REZ_HOR)-20,
                                     center.x*([previewView frame].size.height/VIDEO_REZ_VERT)-20,
                                     40,40);
            [featureLayer setFrame:rect];
            
            [[[previewLayer sublayers] objectAtIndex:1] setHidden:NO];
            [[[previewLayer sublayers] objectAtIndex:2] setHidden:NO];
        }
        else {
            featureLayer = [CALayer new];
            [previewLayer addSublayer:featureLayer];
            [featureLayer setTransform:CATransform3DScale(CATransform3DMakeRotation(M_PI_2, 0.0f, 0.0f, 1.0f),
                                                           1, -1, 1)];
            CGRect rect = CGRectMake(0, 0,[previewView frame].size.width, [previewView frame].size.height);
            [featureLayer setFrame:rect];
            [featureLayer setContents:(id)[imgThreshold CGImage]];
            
            featureLayer = [CALayer new];
            [previewLayer addSublayer:featureLayer];
            rect = CGRectMake((VIDEO_REZ_HOR-center.y)*([previewView frame].size.width/VIDEO_REZ_HOR)-20,
                              center.x*([previewView frame].size.height/VIDEO_REZ_VERT)-20,
                              40,40);
            [featureLayer setFrame:rect];
            [featureLayer setContents:(id)[square CGImage]];
        }
        
        pixelDifference = VIDEO_REZ_HOR/2-center.y;
        data[1] = MIN(3*abs(pixelDifference),127);
        
        if (pixelDifference > 0) {
            data[0] = 'l';
        }
        else if (pixelDifference < 0) {
           data[0] = 'r'; 
        }
        else {
            data[0] = 's';
            data[1] = 0;
        }
    //}
    
//    else {
//        if ([[previewLayer sublayers] count] > 1) {
//            [[[previewLayer sublayers] objectAtIndex:1] setHidden:YES];
//            [[[previewLayer sublayers] objectAtIndex:2] setHidden:YES];
//        }
//        
//        data[0] = 'l';
//        data[1] = 0;
//    }
    
    [CATransaction commit];

    //[cblMgr send:[NSString stringWithCharacters:data length:2]];
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
- (void) scannerViewController:(SKScannerViewController *)scanner didRecognizeCode:(SKCode *)qrCode {
    //Create copy of qrCode
    code = qrCode;
    
    //Transmit QR code to ABS
    [comm send:qrCode.rawContent];
    
    //Schedule a timer to trigger a buffer check every 100 ms
    timer = [NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(checkBufferForTagMessage:) userInfo:nil repeats:YES];
}

//Called periodically to check the Communications rxBuffer for incoming tag message ("new" or "old") from the ABS
-(void) checkBufferForTagMessage:(id)object {
    //If message has been received from ABS
    if ([[comm rxBuffer] length] > 0) {
        //If message is "new", i.e. QR tag had not been found before
        if ([[comm rxBuffer] isEqualToString:@"new"]) {
            //Alert Arduino to new tag
            [cblMgr send:@"yes"];
            [cblMgr send:code.rawContent];
        }
        
        //Restart QR reader
        [self teardownQRReader];
        [self setupQRReader];
        
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
    imgRecog = [[ImageRecognition alloc] init];
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
    [self setupAVCapture];
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
    NSString *message;
    
    //Read bytes into buffer
    [cblMgr receive:numBytes];
    
    while ((message = [cblMgr getMessage]) != nil) {
        
        //Log command
        NSLog(@"%@",message);
        
        //Check for null character, clear buffer and exit current iteration if found
        if ([message length] == 1) {
            unichar character [1];
            [message getCharacters:character range:NSMakeRange(0,1)];
            if (character[0] == 0) continue;
        }
        
        if ([message isEqualToString:@"fence"]) {
            int wordLength = 5;
            NSString* radius;
            
            radius = [message substringWithRange:NSMakeRange(wordLength, [message length] - wordLength)];
            
            [absMotion enableRegionMonitoring:@"virtual fence" withRadius:[radius doubleValue]];
        }
        
        else if ([message isEqualToString:@"gyro on"]) {
            if (![[infoBox text] isEqualToString:@"GYRO ON"]) {
                [relMotion start];
                [infoBox setText:@"GYRO ON"];
            }
        }
        
        else if ([message isEqualToString:@"gyro off"]) {
            if (![[infoBox text] isEqualToString:@"GYRO OFF"]) {
                [relMotion stop];
                [infoBox setText:@"GYRO OFF"];
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
            if (![[infoBox text] isEqualToString:@"NEST ON"]) {
                [self setupAVCapture];
                [infoBox setText:@"NEST ON"];
            }
        }
        
        else if ([message isEqualToString:@"nest off"]) {
            if (![[infoBox text] isEqualToString:@"NEST OFF"]) {
                [self teardownAVCapture];
                [infoBox setText:@"NEST OFF"];
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
        
        else if ([message isEqualToString:@"seed"]) {
            [cblMgr send:@"seed"];
            int seed = arc4random();
            [cblMgr send:[[NSNumber numberWithInt:seed] stringValue]];
        }
        
        else if ([message isEqualToString:@"tag on"]) {
            if (![[infoBox text] isEqualToString:@"TAG ON"]) {
                [self setupQRReader];
                [infoBox setText:@"TAG ON"];
            }
        }
        
        else if ([message isEqualToString:@"tag off"]) {
            if (![[infoBox text] isEqualToString:@"TAG OFF"]) {
                [self teardownQRReader];
                [infoBox setText:@"TAG OFF"];
            }
        }
        else {
            NSLog(@"Error - The command \"%@\" is not recognized",message);
        }
        
        message = [cblMgr getMessage];
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
