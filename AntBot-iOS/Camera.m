//
//  Camera.m
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 7/15/14.
//
//

#import "Camera.h"
#import "CameraView.h"

@implementation Camera

@synthesize pipeline, view;
@synthesize previewLayer, shapeLayer;

- (void)startPipeline:(id<CameraPipeline>)_pipeline {
    pipeline = _pipeline;
    [self stop];
    [self setup];
    [self start];
}

- (void)start {
    if(![session isRunning]) {
        [session startRunning];
    }
}

- (void)stop {
    if([session isRunning]) {
        [previewLayer removeFromSuperlayer];
        [shapeLayer removeFromSuperlayer];
        [session stopRunning];
    }
}

- (void)setup {
    session = [[AVCaptureSession alloc] init];
    [session setSessionPreset:[pipeline quality]];
    
    // Find right camera
    AVCaptureDevicePosition position = [pipeline devicePosition];
    NSArray* devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    BOOL(^block)(id, NSUInteger, BOOL*) = ^BOOL(id obj, NSUInteger idx, BOOL* stop){return [(AVCaptureDevice*)obj position] == position;};
    AVCaptureDevice* camera = [devices objectAtIndex:[devices indexOfObjectPassingTest:block]];
    
    // Configure it
    if([camera lockForConfiguration:nil]) {
        [camera setWhiteBalanceMode:AVCaptureWhiteBalanceModeLocked];
        if(position == AVCaptureDevicePositionFront) {
            [camera setExposureMode:AVCaptureExposureModeLocked];
        }
        [camera unlockForConfiguration];
    }
    
    // Add an AVCaptureInput to the session
    AVCaptureInput* cameraInput = [[AVCaptureDeviceInput alloc] initWithDevice:camera error:nil];
    if([session canAddInput:cameraInput]) {
        [session addInput:cameraInput];
    }
    
    // Create output
    output = [[AVCaptureVideoDataOutput alloc] init];
    [output setAlwaysDiscardsLateVideoFrames:YES];
    [[output connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
    NSNumber* format = [NSNumber numberWithInt:kCMPixelFormat_32BGRA];
	[output setVideoSettings:[NSDictionary dictionaryWithObject:format forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    if([session canAddOutput:output]) {
        [session addOutput:output];
    }
    
    // Create preview layer
    previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
	[previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
	[previewLayer setVideoGravity:AVLayerVideoGravityResize];
    [previewLayer setFrame:[[view layer] frame]];
    [[view layer] addSublayer:previewLayer];
    
    // Create empty shape layer; set up to display red frame
    shapeLayer = [[CAShapeLayer alloc] init];
    [shapeLayer setFrame:[[view layer] frame]];
    [shapeLayer setStrokeColor:[[UIColor redColor] CGColor]];
    [shapeLayer setFillColor:[[UIColor clearColor] CGColor]];
    [shapeLayer setLineWidth:2.0];
    [[view layer] addSublayer:shapeLayer];
    
    // Serial GCD queue for processing frames
    queue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
	[output setSampleBufferDelegate:self queue:queue];
}

- (void)captureOutput:(AVCaptureOutput*)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection*)connection {
    [pipeline didReceiveFrame:sampleBuffer fromCamera:self];
}

@end
