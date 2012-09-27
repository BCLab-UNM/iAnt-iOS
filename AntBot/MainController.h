//
//  MainController.h
//  AntBot
//
//  Created by Joshua Hecker on 12/23/11.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import <GLKit/GLKit.h>

#import "AbsoluteMotion.h"
//#import "AmbientLight.h"
#import "CableManager.h"
#import "Communication.h"
#import "ImageRecognition.h"
#import "RelativeMotion.h"
#import "ScannerKit.h"

const int BUFFER_LEN = 1024;
const int BACK_REZ_VERT = 352;
const int BACK_REZ_HOR = 288;
const int FRONT_REZ_VERT = 192;
const int FRONT_REZ_HOR = 144;
NSArray* HSV_THRESHOLD_RED = [[NSArray alloc] initWithObjects:
                            [[ThresholdRange alloc] initMinTo:cvScalar(0,150,40) andMaxTo:cvScalar(2,250,190)],
                            [[ThresholdRange alloc] initMinTo:cvScalar(170,150,40) andMaxTo:cvScalar(180,250,190)],
                            nil];

@interface MainController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate, RscMgrDelegate, SKScannerViewControllerDelegate> {
    AbsoluteMotion *absMotion;
    //AmbientLight *ambLight;
    CableManager *cblMgr;
    Communication *comm;
    ImageRecognition *imgRecog;
    RelativeMotion *relMotion;
    
    IBOutlet UITextView *infoBox;
    IBOutlet UIView *previewView;
    AVCaptureVideoDataOutput *videoDataOutput;
    AVCaptureVideoPreviewLayer *previewLayer;
    dispatch_queue_t videoDataOutputQueue;
    AVCaptureSession *session;
    
    NSTimer *timer;
    SKCode *code;
    NSString *sensorState;
}

@property SKScannerViewController* skScanner;

@end