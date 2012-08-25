//
//  Controller.m
//  AntBot
//
//  Created by Joshua Hecker on 12/23/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"

#pragma ViewController extension

@interface ViewController ()

- (void)setupAVCapture;
- (void)teardownAVCapture;

@end

@implementation ViewController
@synthesize pressButton;
@synthesize toggleSwitch;
@synthesize timer;

- (void)setupAVCapture
{
	NSError *error = nil;
	
	AVCaptureSession *session = [AVCaptureSession new];
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
	    [session setSessionPreset:AVCaptureSessionPreset640x480];
	else
	    [session setSessionPreset:AVCaptureSessionPresetPhoto];
	
    // Select a video device, make an input
	AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
	
    isUsingFrontFacingCamera = NO;
	if ( [session canAddInput:deviceInput] )
		[session addInput:deviceInput];
	
    // Make a video data output
	videoDataOutput = [AVCaptureVideoDataOutput new];
	
    // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
	NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:
									   [NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
	[videoDataOutput setVideoSettings:rgbOutputSettings];
	[videoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked (as we process the still image)
    
    // create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured
    // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
    // see the header doc for setSampleBufferDelegate:queue: for more information
	videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
	[videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
	
    if ( [session canAddOutput:videoDataOutput] )
		[session addOutput:videoDataOutput];
	[[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:NO];
	
	effectiveScale = 1.0;
	previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
	[previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
	[previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
	CALayer *rootLayer = [previewView layer];
	[rootLayer setMasksToBounds:YES];
	[previewLayer setFrame:[rootLayer bounds]];
	[rootLayer addSublayer:previewLayer];
	[session startRunning];
    
bail:
	[session release];
	if (error) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Failed with error %d", (int)[error code]]
															message:[error localizedDescription]
														   delegate:nil 
												  cancelButtonTitle:@"Dismiss" 
												  otherButtonTitles:nil];
		[alertView show];
		[alertView release];
		[self teardownAVCapture];
	}
}

// clean up capture setup
- (void)teardownAVCapture
{
	[videoDataOutput release];
	if (videoDataOutputQueue)
		dispatch_release(videoDataOutputQueue);
	[previewLayer removeFromSuperlayer];
	[previewLayer release];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{	
    centroid c = [imgRecog findColorCentroidIn:sampleBuffer];
    if (c.x != -1)
    {
        printf("centroid: ");
        printf("(");
        printf("%f",c.x);
        printf(",");
        printf("%f",c.y);
        printf(")\n");
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - UIView outlets

- (IBAction)toggleLED:(id)sender {
    if (toggleSwitch.on) { // check the state of the button
        txBuffer[0] = (int) '1';
    } else {
        txBuffer[0] = (int) '0';
    }
    
    // Send 0 or 1 to the Arduino
	[rscMgr write:txBuffer Length:1];
}

- (IBAction)startRobot:(id)sender {
    if (pressButton)
    {
        [relMotion start];
        
        UInt8 forward[BUFFER_LEN] = "forwardxx\n";
        UInt8 stop[BUFFER_LEN] = "stop\n";

        do 
        {
            float rate = [relMotion rotationRate];
            if (rate < 0)
            {
                forward[7] = MIN(forward[7] + (rate * (180.0/M_PI)),255);
                forward[8] = 120;
            }
            else if (rate > 0)
            {
                forward[7] = 120;
                forward[8] = MIN(forward[8] + (rate * (180.0/M_PI)),255);
            }
            else
            {
                forward[7] = 120;
                forward[8] = 120;
            }
            memcpy(txBuffer,forward,BUFFER_LEN);
            [rscMgr write:txBuffer Length:10];
            
            [relMotion updateSpace];
        }
        while (sqrt(pow(relMotion.currentDist.x,2.0) + pow(relMotion.currentDist.y,2.0)+ pow(relMotion.currentDist.z,2.0)) < 1.0);

        memcpy(txBuffer,stop,BUFFER_LEN);
        [rscMgr write:txBuffer Length:5];
        
        [relMotion stop];
    }
}

// use front/back camera
- (IBAction)switchCameras:(id)sender
{
	if (isUsingFrontFacingCamera)
		[self setupPreviewLayer:(AVCaptureDevicePosition)AVCaptureDevicePositionBack];
	else
		[self setupPreviewLayer:(AVCaptureDevicePosition)AVCaptureDevicePositionFront];

	isUsingFrontFacingCamera = !isUsingFrontFacingCamera;
}

- (void)setupPreviewLayer:(AVCaptureDevicePosition)desiredPosition
{	
	for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
    {
		if ([d position] == desiredPosition)
        {
			[[previewLayer session] beginConfiguration];
			AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:d error:nil];
			for (AVCaptureInput *oldInput in [[previewLayer session] inputs])
            {
				[[previewLayer session] removeInput:oldInput];
			}
			[[previewLayer session] addInput:input];
			[[previewLayer session] commitConfiguration];
			break;
		}
	}
}


#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    absMotion = [[AbsoluteMotion alloc] init];
    comm = [[Communication alloc] init];
    imgRecog = [[ImageRecognition alloc] init];
    relMotion = [[RelativeMotion alloc] init];
    
    rscMgr = [[RscMgr alloc] init];
    [rscMgr setDelegate:self];
    
    [absMotion start];
    
    [comm connectTo:@"Sierpinski" onPort:2223];
    
    [self setupAVCapture];
    
    [self setupPreviewLayer:(AVCaptureDevicePosition)AVCaptureDevicePositionFront];
    [self setupPreviewLayer:(AVCaptureDevicePosition)AVCaptureDevicePositionBack];
}   

- (void)viewDidUnload
{
    [absMotion stop];
    [comm closeConnection];
    
    [self teardownAVCapture];
    [self setToggleSwitch:nil];
    [self setPressButton:nil];
    
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - RscMgrDelegate methods

- (void) cableConnected:(NSString *)protocol {
    [rscMgr setBaud:9600];
	[rscMgr open]; 
}

- (void) cableDisconnected {
    
}

- (void) portStatusChanged {
    
}

- (void) readBytesAvailable:(UInt32)numBytes {
}

- (BOOL) rscMessageReceived:(UInt8 *)msg TotalLength:(int)len {
    return FALSE;    
}

- (void) didReceivePortConfig {
}


- (void)dealloc {
    [super dealloc];
}

@end
