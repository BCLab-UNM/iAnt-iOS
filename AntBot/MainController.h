//
//  MainController.h
//  AntBot
//
//  Created by Joshua Hecker on 12/23/11.
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "AbsoluteMotion.h"
//#import "AmbientLight.h"
#import "CableManager.h"
#import "Communication.h"
#import "ImageRecognition.h"
#import "RelativeMotion.h"
#import "ScannerKit.h"

@interface MainController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate, RscMgrDelegate, SKScannerViewControllerDelegate> {
    AbsoluteMotion *absMotion;
    //AmbientLight *ambLight;
    CableManager *cblMgr;
    Communication *comm;
    ImageRecognition *imgRecog;
    RelativeMotion *relMotion;
    
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
@property IBOutlet UITextView *infoBox;

@end