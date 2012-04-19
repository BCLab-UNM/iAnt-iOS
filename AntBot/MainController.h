//
//  Controller.h
//  AntBot
//
//  Created by Joshua Hecker on 12/23/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RscMgr.h"
#import "AbsoluteMotion.h"
#import "RelativeMotion.h"
#import "ImageRecognition.h"
#import "Communication.h"
#import <CoreLocation/CoreLocation.h>

#define BUFFER_LEN 1024

@interface ViewController : UIViewController 
    <AVCaptureVideoDataOutputSampleBufferDelegate, RscMgrDelegate>
{
    AbsoluteMotion *absMotion;
    Communication *comm;
    ImageRecognition *imgRecog;
    RelativeMotion *relMotion;
    RscMgr *rscMgr;
    
    UInt8 rxBuffer[BUFFER_LEN];
    UInt8 txBuffer[BUFFER_LEN];
    
    IBOutlet UIView *previewView;
    BOOL isUsingFrontFacingCamera;
    AVCaptureVideoDataOutput *videoDataOutput;
    AVCaptureVideoPreviewLayer *previewLayer;
    dispatch_queue_t videoDataOutputQueue;
    CGFloat effectiveScale;
}

@property (strong, nonatomic) IBOutlet UISwitch *toggleSwitch;
- (IBAction)toggleLED:(id)sender;
@property (strong, nonatomic) IBOutlet UIButton *pressButton;
- (IBAction)startRobot:(id)sender;
@property (assign) NSDate *timer;
- (IBAction)switchCameras:(id)sender;
- (void)setupPreviewLayer:(AVCaptureDevicePosition)desiredPosition;

@end