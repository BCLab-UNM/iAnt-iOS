//
//  MainController.h
//  AntBot-iOS
//
//  Created by Joshua Hecker
//  Moses Lab, Department of Computer Science, University of New Mexico
//

#import "AbsoluteMotion.h"
//#import "AmbientLight.h"
#import "Conversions.h"
#import "ImageRecognition.h"
#import "RelativeMotion.h"
#import "Utilities.h"
#import <Decoder.h>
#import <QRCodeReader.h>
#import "TwoDDecoderResult.h"
#import <math.h>

#import "RouterServer.h"
#import "RouterCable.h"

@interface MainController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate, DecoderDelegate> {
    
    AbsoluteMotion *absMotion;
    //AmbientLight *ambLight;
    RouterServer *server;
    RouterCable *cable;
    Decoder *qrDecoder;
    ImageRecognition *imgRecog;
    RelativeMotion *relMotion;
    
    IBOutlet UIView *previewView;
    AVCaptureVideoDataOutput *videoDataOutput;
    AVCaptureVideoPreviewLayer *previewLayer;
    dispatch_queue_t videoDataOutputQueue;
    AVCaptureSession *session;
    
    NSString *sensorState;
    int qrCode;
    int nestDistance;
    
    int mocapContext;
    NSString* mocapHeading;
    bool mocapMonitor;
    
    NSString* evolvedParameters;
}

- (void)initServerHandlers;
- (void)initCableHandlers;

@property IBOutlet UITextView *infoBox;

@end