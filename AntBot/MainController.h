//
//  MainController.h
//  AntBot
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "AbsoluteMotion.h"
//#import "AmbientLight.h"
#import "CableManager.h"
#import "Communication.h"
#import "ImageRecognition.h"
#import "RelativeMotion.h"
#import <Decoder.h>
#import <QRCodeReader.h>
#import "TwoDDecoderResult.h"

@interface MainController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate, RscMgrDelegate, DecoderDelegate> {
    
    AbsoluteMotion *absMotion;
    //AmbientLight *ambLight;
    CableManager *cblMgr;
    Communication *comm;
    Decoder *qrDecoder;
    ImageRecognition *imgRecog;
    RelativeMotion *relMotion;
    
    IBOutlet UIView *previewView;
    AVCaptureVideoDataOutput *videoDataOutput;
    AVCaptureVideoPreviewLayer *previewLayer;
    dispatch_queue_t videoDataOutputQueue;
    AVCaptureSession *session;
    
    NSTimer *timer;
    NSString *sensorState;
    int qrCode;
}

@property IBOutlet UITextView *infoBox;

@end