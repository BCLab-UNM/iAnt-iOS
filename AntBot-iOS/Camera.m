//
//  Camera.m
//  AntBot-iOS
//
//  Created by Bjorn Swenson on 7/15/14.
//
//

#import "Camera.h"

@implementation Camera

@synthesize pipeline;

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
        [session stopRunning];
    }
}

- (void)setup {
    session = [[AVCaptureSession alloc] init];
    [session setSessionPreset:[pipeline quality] ? [pipeline quality] : AVCaptureSessionPresetLow];
    
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
    
    // Create preview layer
    previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
	[previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
	[previewLayer setVideoGravity:AVLayerVideoGravityResize];
    
    // Serial GCD queue for processing frames
    dispatch_queue_t queue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
	[output setSampleBufferDelegate:self queue:queue];
}

@end